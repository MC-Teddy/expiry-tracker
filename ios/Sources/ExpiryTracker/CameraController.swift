#if canImport(UIKit)
import UIKit
@preconcurrency import AVFoundation
import PhotosUI
import UniformTypeIdentifiers
import ImageIO
import Vision
import NativePolicy

enum CameraFailure: LocalizedError {
    case cancelled, denied, unavailable, capture, noBarcode
    var errorDescription: String? {
        switch self {
        case .cancelled: return "Camera cancelled"
        case .denied: return "Camera access is disabled. Enable it in iPhone Settings, or choose a photo."
        case .unavailable: return "The iPhone camera is unavailable. Choose a photo instead."
        case .capture: return "Unable to capture this photo. Please retry."
        case .noBarcode: return "No supported barcode found. Please frame the barcode and retry."
        }
    }
}

/// Camera hardware operations are serialized off the UI thread. The main actor
/// owns presentation and completion. Cancellation queues teardown after setup,
/// so a pending authorization/setup cannot leave capture running invisibly.
@MainActor
final class CameraController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate, PHPickerViewControllerDelegate {
    private let purpose: String
    private let result: OneShot<Result<[String:String],Error>>
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label:"expiry.native-camera")
    private var device: AVCaptureDevice?
    private var preview: AVCaptureVideoPreviewLayer!
    private var finished = false
    private var capturing = false
    private var selectingPhoto = false
    private var ready = false
    private var observing = false
    private var torch = false
    private let status = UILabel()
    private let capture = UIButton(type:.system)
    private let torchButton = UIButton(type:.system)

    init(purpose: String, completion: @escaping (Result<[String:String],Error>) -> Void) {
        self.purpose = purpose
        self.result = OneShot(completion)
        super.init(nibName:nil, bundle:nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        preview = AVCaptureVideoPreviewLayer(session:session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        let close = button("Close", action:#selector(closeCamera))
        torchButton.setTitle("Torch off", for:.normal)
        torchButton.addTarget(self, action:#selector(toggleTorch), for:.touchUpInside)
        torchButton.isEnabled = false
        torchButton.tintColor = .white
        torchButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        torchButton.layer.cornerRadius = 8
        let library = button("Photos", action:#selector(openPhotos))
        let top = UIStackView(arrangedSubviews:[close, UIView(), torchButton, library])
        top.spacing = 16
        top.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)
        status.text = purpose == "barcode" ? "Point at a product barcode" : "Frame the expiry date, then take a photo"
        status.textColor = .white
        status.font = .preferredFont(forTextStyle:.headline)
        status.textAlignment = .center
        status.numberOfLines = 0
        status.translatesAutoresizingMaskIntoConstraints = false
        status.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.addSubview(status)
        capture.setTitle("Take Photo", for:.normal)
        capture.titleLabel?.font = .preferredFont(forTextStyle:.headline)
        capture.backgroundColor = .white
        capture.tintColor = .black
        capture.layer.cornerRadius = 28
        capture.isEnabled = false
        capture.translatesAutoresizingMaskIntoConstraints = false
        capture.addTarget(self, action:#selector(takePhoto), for:.touchUpInside)
        view.addSubview(capture)
        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor, constant:20),
            top.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor, constant:-20),
            top.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor, constant:12),
            top.heightAnchor.constraint(greaterThanOrEqualToConstant:44),
            status.leadingAnchor.constraint(equalTo:view.leadingAnchor, constant:20),
            status.trailingAnchor.constraint(equalTo:view.trailingAnchor, constant:-20),
            status.bottomAnchor.constraint(equalTo:capture.topAnchor, constant:-24),
            capture.widthAnchor.constraint(equalToConstant:180),
            capture.heightAnchor.constraint(equalToConstant:56),
            capture.centerXAnchor.constraint(equalTo:view.centerXAnchor),
            capture.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor, constant:-24)
        ])
        NotificationCenter.default.addObserver(self, selector:#selector(backgrounded), name:UIApplication.didEnterBackgroundNotification, object:nil)
        NotificationCenter.default.addObserver(self, selector:#selector(interrupted), name:AVCaptureSession.wasInterruptedNotification, object:session)
        NotificationCenter.default.addObserver(self, selector:#selector(interrupted), name:AVCaptureSession.runtimeErrorNotification, object:session)
        observing = true
        switch AVCaptureDevice.authorizationStatus(for:.video) {
        case .authorized: setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for:.video) { [weak self] allowed in
                Task { @MainActor in
                    guard let self, !self.finished else { return }
                    if allowed { self.setupCamera() } else { self.status.text = CameraFailure.denied.localizedDescription }
                }
            }
        default: status.text = CameraFailure.denied.localizedDescription
        }
    }

    private func button(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type:.system)
        button.setTitle(title, for:.normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 8
        button.addTarget(self, action:action, for:.touchUpInside)
        return button
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview.frame = view.bounds
        if let connection = preview.connection, connection.isVideoRotationAngleSupported(rotation) { connection.videoRotationAngle = rotation }
    }

    private var rotation: CGFloat {
        switch view.window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: return 0
        case .landscapeRight: return 180
        case .portraitUpsideDown: return 270
        default: return 90
        }
    }

    private func setupCamera() {
        let session = session, photoOutput = photoOutput, metadataOutput = metadataOutput
        let scan = purpose == "barcode"
        sessionQueue.async { [weak self] in
            do {
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for:.video, position:.back) else { throw CameraFailure.unavailable }
                let input = try AVCaptureDeviceInput(device:camera)
                session.beginConfiguration()
                session.sessionPreset = .photo
                guard session.canAddInput(input), session.canAddOutput(photoOutput) else { session.commitConfiguration(); throw CameraFailure.unavailable }
                session.addInput(input)
                session.addOutput(photoOutput)
                if let size = camera.activeFormat.supportedMaxPhotoDimensions.filter({ Int($0.width) * Int($0.height) <= 12_500_000 }).max(by:{ Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }) { photoOutput.maxPhotoDimensions = size }
                if scan, session.canAddOutput(metadataOutput) {
                    session.addOutput(metadataOutput)
                    let wanted: [AVMetadataObject.ObjectType] = [.ean8,.ean13,.upce,.code128,.qr]
                    metadataOutput.metadataObjectTypes = wanted.filter { metadataOutput.availableMetadataObjectTypes.contains($0) }
                }
                session.commitConfiguration()
                session.startRunning()
                Task { @MainActor in
                    guard let self, !self.finished else { return }
                    self.device = camera
                    self.ready = true
                    self.capture.isEnabled = true
                    self.torchButton.isEnabled = camera.hasTorch
                    if scan { metadataOutput.setMetadataObjectsDelegate(self, queue:.main) }
                    self.view.setNeedsLayout()
                }
            } catch {
                Task { @MainActor in self?.status.text = CameraFailure.unavailable.localizedDescription }
            }
        }
    }

    @objc private func takePhoto() {
        guard ready, !capturing, !finished else { return }
        capturing = true
        capture.isEnabled = false
        status.text = "Processing photo…"
        let settings = AVCapturePhotoSettings(format:[AVVideoCodecKey:AVVideoCodecType.jpeg])
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        if let connection = photoOutput.connection(with:.video), connection.isVideoRotationAngleSupported(rotation) { connection.videoRotationAngle = rotation }
        photoOutput.capturePhoto(with:settings, delegate:self)
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            Task { @MainActor in self.finish(.failure(CameraFailure.capture)) }
            return
        }
        processImage(data)
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil { Task { @MainActor in self.finish(.failure(CameraFailure.capture)) } }
    }

    nonisolated private func processImage(_ data: Data) {
        let scan = purpose == "barcode"
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            let result = Result<[String:String],Error> {
                let jpeg = try Self.uprightJPEG(data)
                if scan {
                    let request = VNDetectBarcodesRequest()
                    request.symbologies = [.ean8,.ean13,.upce,.code128,.qr]
                    try VNImageRequestHandler(data:jpeg,options:[:]).perform([request])
                    guard let value = request.results?.compactMap({ $0.payloadStringValue }).first, !value.isEmpty, value.utf8.count <= 2048 else { throw CameraFailure.noBarcode }
                    return ["barcode":value]
                }
                return ["image":"data:image/jpeg;base64," + jpeg.base64EncodedString()]
            }
            Task { @MainActor in self?.finish(result) }
        }
    }

    nonisolated static func uprightJPEG(_ data: Data) throws -> Data {
        try autoreleasepool {
            guard data.count <= NativePolicy.limit,
                  let source = CGImageSourceCreateWithData(data as CFData,nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                  let w = properties[kCGImagePropertyPixelWidth] as? Int,
                  let h = properties[kCGImagePropertyPixelHeight] as? Int,
                  w > 0, h > 0, w <= 30000, h <= 30000, w * h <= 60_000_000,
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:2048] as CFDictionary) else { throw CameraFailure.capture }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString,1,nil) else { throw CameraFailure.capture }
            CGImageDestinationAddImage(destination, thumbnail,[kCGImageDestinationLossyCompressionQuality:0.85] as CFDictionary)
            guard CGImageDestinationFinalize(destination), output.length <= 5 * 1024 * 1024 else { throw CameraFailure.capture }
            return output as Data
        }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let value = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first, !value.isEmpty, value.utf8.count <= 2048 else { return }
        Task { @MainActor in
            guard !self.capturing, !self.selectingPhoto else { return }
            self.finish(.success(["barcode":value]))
        }
    }

    @objc private func toggleTorch() {
        guard let device, device.hasTorch, !finished else { return }
        torch.toggle()
        let enabled = torch
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if enabled { try device.setTorchModeOn(level:min(0.6,AVCaptureDevice.maxAvailableTorchLevel)) } else { device.torchMode = .off }
            } catch {}
        }
        torchButton.setTitle(torch ? "Torch on" : "Torch off", for:.normal)
    }

    @objc private func openPhotos() {
        guard !finished, !capturing, presentedViewController == nil else { return }
        selectingPhoto = true
        pauseSession()
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration:configuration)
        picker.delegate = self
        present(picker, animated:true)
    }

    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor [self] in
            picker.dismiss(animated:true)
            guard !self.finished else { return }
            guard let provider = results.first?.itemProvider else {
                self.selectingPhoto = false
                if self.ready { let session = self.session; self.sessionQueue.async { session.startRunning() } }
                return
            }
            self.capturing = true
            self.status.text = "Processing photo…"
            // File representation avoids loading an unbounded library image into RAM.
            provider.loadFileRepresentation(forTypeIdentifier:UTType.image.identifier) { [weak self] url,error in
                guard error == nil, let url,
                      let size = try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize,
                      size <= NativePolicy.limit,
                      let data = try? Data(contentsOf:url, options:.mappedIfSafe) else {
                    Task { @MainActor in self?.finish(.failure(CameraFailure.capture)) }
                    return
                }
                self?.processImage(data)
            }
        }
    }

    private func pauseSession() {
        let session = session, device = device
        torch = false
        torchButton.setTitle("Torch off", for:.normal)
        sessionQueue.async {
            if let device, device.hasTorch {
                do { try device.lockForConfiguration(); device.torchMode = .off; device.unlockForConfiguration() } catch {}
            }
            if session.isRunning { session.stopRunning() }
        }
    }

    func cancel() { finish(.failure(CameraFailure.cancelled)) }
    @objc private func closeCamera() { cancel() }
    @objc private func backgrounded() { cancel() }
    @objc private func interrupted() { finish(.failure(CameraFailure.unavailable)) }

    private func finish(_ value: Result<[String:String],Error>) {
        guard !finished else { return }
        finished = true
        if observing { NotificationCenter.default.removeObserver(self); observing = false }
        metadataOutput.setMetadataObjectsDelegate(nil, queue:nil)
        pauseSession()
        let session = session
        sessionQueue.async {
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            session.commitConfiguration()
        }
        result.finish(value)
        if presentedViewController != nil {
            presentedViewController?.dismiss(animated:false) { [weak self] in self?.dismiss(animated:true) }
        } else { dismiss(animated:true) }
    }
}
#endif
