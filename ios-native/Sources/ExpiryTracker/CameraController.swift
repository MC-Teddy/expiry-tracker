#if canImport(UIKit)
import UIKit
@preconcurrency import AVFoundation
import PhotosUI
import UniformTypeIdentifiers
import ImageIO
import Vision

/// Camera hardware operations are serialized off the UI thread. The main actor
/// owns presentation and completion. Cancellation queues teardown after setup,
/// so a pending authorization/setup cannot leave capture running invisibly.
@MainActor
final class CameraController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate, PHPickerViewControllerDelegate {
    private let purpose: String
    private let result: OneShot<Result<CameraCapture,Error>>
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label:"expiry.native-camera")
    private let focusWork = CameraFocusWork()
    private var device: AVCaptureDevice?
    private var preview: AVCaptureVideoPreviewLayer!
    private var finished = false
    private var capturing = false
    private var selectingPhoto = false
    private var dismissingPicker = false
    private var pickerDismissalCompletion: (() -> Void)?
    private var ready = false
    private var observing = false
    private var torch = false
    private let chrome = CameraChromeView()
    private var status: UILabel { chrome.status }
    private var capture: UIButton { chrome.capture }
    private var torchButton: UIButton { chrome.torch }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init(purpose: String, completion: @escaping (Result<CameraCapture,Error>) -> Void) {
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

        chrome.frame = view.bounds
        chrome.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        chrome.configure(purpose: purpose)
        view.addSubview(chrome)
        chrome.close.addTarget(self, action:#selector(closeCamera), for:.touchUpInside)
        torchButton.addTarget(self, action:#selector(toggleTorch), for:.touchUpInside)
        torchButton.isEnabled = false
        chrome.photos.addTarget(self, action:#selector(openPhotos), for:.touchUpInside)
        chrome.help.addTarget(self, action:#selector(showTips), for:.touchUpInside)
        status.text = framingHint
        capture.isEnabled = false
        capture.addTarget(self, action:#selector(takePhoto), for:.touchUpInside)
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

    @objc private func showTips() {
        guard !finished, !capturing, !selectingPhoto, presentedViewController == nil else { return }
        let tips = UIAlertController(title: "A clearer scan", message: purpose == "barcode"
            ? "Keep the entire barcode in the frame. Use even light and hold steady. You can also choose a photo."
            : (purpose == "product" ? "Show the front of the package with the product name and brand. Use even light and avoid reflections. If the print looks blurry, move back a little. Name suggestions come from visible text and can be edited. Recognition stays on this iPhone."
               : "Include the full date and wording such as EXP or Best before. Use even light. If the print looks blurry, move back a little and let the camera focus. Dates are read privately on this iPhone."), preferredStyle: .alert)
        tips.addAction(UIAlertAction(title: "Got it", style: .default))
        present(tips, animated: true)
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

    private var framingHint: String {
        purpose == "barcode" ? "Keep the whole barcode in the frame." : (purpose == "product" ? "Include the product name and brand." : "Include EXP or Best before.")
    }

    /// Called only on sessionQueue. Keep default fallback constituents intact so
    /// AVFoundation can switch based on focus distance and available light.
    nonisolated private static func rearCamera() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera], mediaType: .video, position: .back).devices
        let candidates = devices.map { camera in
            CameraLensCandidate(id: camera.uniqueID,
                kind: camera.deviceType == .builtInTripleCamera ? .triple : (camera.deviceType == .builtInDualWideCamera ? .dualWide : .wide),
                continuousFocus: camera.isFocusModeSupported(.continuousAutoFocus),
                automaticSwitching: camera.isVirtualDevice && camera.activePrimaryConstituentDeviceSwitchingBehavior != .unsupported)
        }
        guard let selected = CameraLensPolicy.automaticCamera(in: candidates) else { return nil }
        return devices.first { $0.uniqueID == selected.id }
    }

    /// Lock acquisition may wait. Recheck ownership after acquiring it, before
    /// any property writes; cancellation/capture invalidates work immediately.
    nonisolated private static func configureFocus(_ camera: AVCaptureDevice, focusWork: CameraFocusWork, token: UUID, initial: Bool = false) throws {
        try camera.lockForConfiguration()
        defer { camera.unlockForConfiguration() }
        focusWork.performIfCurrent(token) {
            if initial, camera.isVirtualDevice {
                if camera.activePrimaryConstituentDeviceSwitchingBehavior != .unsupported {
                    camera.setPrimaryConstituentDeviceSwitchingBehavior(.auto, restrictedSwitchingBehaviorConditions: [])
                }
                if let factor = CameraLensPolicy.initialVirtualZoom(
                    switchOverFactors: camera.virtualDeviceSwitchOverVideoZoomFactors.map { $0.doubleValue },
                    minimum: Double(camera.minAvailableVideoZoomFactor), maximum: Double(camera.maxAvailableVideoZoomFactor)) {
                    camera.videoZoomFactor = CGFloat(factor)
                }
            }
            let plan = CameraFocusPlan(capabilities: .init(
                continuousFocus: camera.isFocusModeSupported(.continuousAutoFocus),
                autoFocus: camera.isFocusModeSupported(.autoFocus),
                focusPoint: camera.isFocusPointOfInterestSupported,
                continuousExposure: camera.isExposureModeSupported(.continuousAutoExposure),
                exposurePoint: camera.isExposurePointOfInterestSupported,
                rangeRestriction: camera.isAutoFocusRangeRestrictionSupported))
            if let point = plan.focusPoint { camera.focusPointOfInterest = point }
            if plan.resetFocusRange { camera.autoFocusRangeRestriction = .none }
            switch plan.focusMode {
            case .continuous: camera.focusMode = .continuousAutoFocus
            case .auto: camera.focusMode = .autoFocus
            case nil: break
            }
            if let point = plan.exposurePoint { camera.exposurePointOfInterest = point }
            if plan.continuousExposure { camera.exposureMode = .continuousAutoExposure }
            camera.isSubjectAreaChangeMonitoringEnabled = plan.monitorSubjectArea
        }
    }

    @objc nonisolated private func subjectAreaChanged() {
        Task { @MainActor [weak self] in self?.recenterFocus() }
    }

    private func recenterFocus() {
        guard ready, !finished, !capturing, !selectingPhoto,
              let camera = device, let token = focusWork.currentToken() else { return }
        let focusWork = focusWork
        sessionQueue.async {
            try? Self.configureFocus(camera, focusWork: focusWork, token: token)
        }
    }

    /// May run after delayed setup or after Photos cancellation. Publish camera
    /// readiness only once this ownership generation has actually started.
    private func startPreview() {
        guard ready, !finished, !capturing, !selectingPhoto,
              let camera = device, let token = focusWork.currentToken() else { return }
        let session = session, focusWork = focusWork
        sessionQueue.async { [weak self] in
            do {
                try Self.configureFocus(camera, focusWork: focusWork, token: token, initial: true)
                guard focusWork.currentToken() == token else { return }
                session.startRunning()
                Task { @MainActor in
                    guard let self, !self.finished, !self.capturing, !self.selectingPhoto,
                          focusWork.currentToken() == token else { return }
                    self.capture.isEnabled = true
                    self.chrome.setProcessing(false)
                    self.view.setNeedsLayout()
                }
            } catch {
                Task { @MainActor in
                    guard let self, !self.finished, focusWork.currentToken() == token else { return }
                    self.status.text = CameraFailure.unavailable.localizedDescription
                }
            }
        }
    }

    private func setupCamera() {
        let session = session, photoOutput = photoOutput, metadataOutput = metadataOutput
        let focusWork = focusWork
        guard focusWork.canPrepareSession else { return }
        let scan = purpose == "barcode"
        sessionQueue.async { [weak self] in
            do {
                guard focusWork.canPrepareSession else { return }
                guard let camera = Self.rearCamera() else { throw CameraFailure.unavailable }
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
                Task { @MainActor in
                    guard let self, !self.finished else { return }
                    self.device = camera
                    NotificationCenter.default.addObserver(self, selector:#selector(self.subjectAreaChanged), name:AVCaptureDevice.subjectAreaDidChangeNotification, object:camera)
                    self.ready = true
                    self.torchButton.isEnabled = camera.hasTorch
                    if scan { metadataOutput.setMetadataObjectsDelegate(self, queue:.main) }
                    self.startPreview()
                    self.view.setNeedsLayout()
                }
            } catch {
                Task { @MainActor in
                    guard let self, !self.finished else { return }
                    self.status.text = CameraFailure.unavailable.localizedDescription
                }
            }
        }
    }

    @objc private func takePhoto() {
        guard ready, capture.isEnabled, !capturing, !finished, !selectingPhoto else { return }
        capturing = true
        chrome.setProcessing(true)
        focusWork.suspend()
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
            let result = Result<CameraCapture,Error> {
                let jpeg = try Self.uprightJPEG(data)
                if scan {
                    let request = VNDetectBarcodesRequest()
                    request.symbologies = [.ean8,.ean13,.upce,.code128,.qr]
                    try VNImageRequestHandler(data:jpeg,options:[:]).perform([request])
                    guard let value = request.results?.compactMap({ $0.payloadStringValue }).first, !value.isEmpty, value.utf8.count <= 2048 else { throw CameraFailure.noBarcode }
                    return .barcode(value)
                }
                return .photo(jpeg)
            }
            Task { @MainActor in self?.finish(result) }
        }
    }

    nonisolated static func uprightJPEG(_ data: Data) throws -> Data {
        try autoreleasepool {
            guard data.count <= 20 * 1024 * 1024,
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
            self.finish(.success(.barcode(value)))
        }
    }

    @objc private func toggleTorch() {
        guard let device, device.hasTorch, !finished, !capturing, !selectingPhoto,
              let token = focusWork.currentToken() else { return }
        torch.toggle()
        let enabled = torch
        let focusWork = focusWork
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                focusWork.performIfCurrent(token) {
                    if enabled { try? device.setTorchModeOn(level:min(0.6,AVCaptureDevice.maxAvailableTorchLevel)) } else { device.torchMode = .off }
                }
            } catch {}
        }
        chrome.setTorch(torch)
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
            dismissingPicker = true
            picker.dismiss(animated:true) { [self] in
                dismissingPicker = false
                let delivery = pickerDismissalCompletion
                pickerDismissalCompletion = nil
                delivery?()
                guard !self.finished else { return }
                guard let provider = results.first?.itemProvider else {
                    self.selectingPhoto = false
                    self.focusWork.resume()
                    self.status.text = self.framingHint
                    self.startPreview()
                    return
                }
                self.capturing = true
                self.chrome.setProcessing(true)
                self.status.text = "Processing photo…"
                // File representation avoids loading an unbounded library image into RAM.
                provider.loadFileRepresentation(forTypeIdentifier:UTType.image.identifier) { [weak self] url,error in
                    guard error == nil, let url,
                          let size = try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize,
                          size <= 20 * 1024 * 1024,
                          let data = try? Data(contentsOf:url, options:.mappedIfSafe) else {
                        Task { @MainActor in self?.finish(.failure(CameraFailure.capture)) }
                        return
                    }
                    self?.processImage(data)
                }
            }
        }
    }

    private func pauseSession() {
        focusWork.suspend()
        capture.isEnabled = false
        let session = session, device = device
        torch = false
        chrome.setTorch(false)
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

    private func finish(_ value: Result<CameraCapture,Error>) {
        guard !finished else { return }
        finished = true
        focusWork.finish()
        if observing { NotificationCenter.default.removeObserver(self); observing = false }
        metadataOutput.setMetadataObjectsDelegate(nil, queue:nil)
        pauseSession()
        let session = session
        sessionQueue.async {
            let camera = (session.inputs.first as? AVCaptureDeviceInput)?.device
            if let camera {
                do {
                    try camera.lockForConfiguration()
                    camera.isSubjectAreaChangeMonitoringEnabled = false
                    camera.unlockForConfiguration()
                } catch {}
            }
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            session.commitConfiguration()
        }
        // SwiftUI alone dismisses this controller's cover. UIKit may close only
        // our Photos child, and delivery waits until that transition completes.
        let deliver = { [self] in result.finish(value) }
        if dismissingPicker {
            pickerDismissalCompletion = deliver
        } else if let child = presentedViewController {
            child.dismiss(animated:false, completion: deliver)
        } else {
            deliver()
        }
    }
}
#endif
