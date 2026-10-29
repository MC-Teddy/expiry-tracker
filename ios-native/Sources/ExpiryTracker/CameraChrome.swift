#if canImport(UIKit)
import UIKit

/// Camera controls sit above the preview; the frame is a visual guide, not an
/// OCR crop. Full-image recognition and camera ownership stay in the controller.
@MainActor
final class CameraChromeView: UIView {
    let status = CameraStatusLabel()
    let capture = CameraShutterButton(type: .custom)
    let torch = UIButton(type: .system)
    let close = UIButton(type: .system)
    let photos = UIButton(type: .system)
    let help = UIButton(type: .system)
    private let title = UILabel()
    private let heading = UILabel()
    private let dock = UIVisualEffectView(effect: nil)
    private let textScroll = UIScrollView()
    private let shade = CAShapeLayer()
    private let corners = CAShapeLayer()
    private let activity = UIActivityIndicatorView(style: .large)
    private var barcode = false
    private var product = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.addSublayer(shade)
        layer.addSublayer(corners)
        shade.fillRule = .evenOdd
        shade.fillColor = UIColor.black.withAlphaComponent(0.28).cgColor
        corners.fillColor = UIColor.clear.cgColor
        corners.strokeColor = UIColor.white.withAlphaComponent(0.95).cgColor
        corners.lineWidth = 3
        corners.lineCap = .round
        dock.layer.cornerRadius = 28
        dock.clipsToBounds = true
        addSubview(dock)
        [close, title, torch].forEach { addSubview($0) }
        [textScroll, photos, capture, help].forEach { dock.contentView.addSubview($0) }
        [heading, status].forEach { textScroll.addSubview($0) }
        capture.addSubview(activity)
        textScroll.showsVerticalScrollIndicator = true
        textScroll.alwaysBounceVertical = false
        heading.textColor = .white
        heading.numberOfLines = 0
        heading.textAlignment = .center
        status.textColor = UIColor.white.withAlphaComponent(0.8)
        status.numberOfLines = 0
        status.textAlignment = .center
        status.accessibilityTraits = .updatesFrequently
        status.textDidChange = { [weak self] in self?.setNeedsLayout() }
        title.textColor = .white
        title.textAlignment = .center
        title.numberOfLines = 0
        title.accessibilityTraits = .header
        updateFonts()
        updateMaterial()
        NotificationCenter.default.addObserver(self, selector: #selector(updateMaterial), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self, UITraitAccessibilityContrast.self]) { (view: CameraChromeView, _: UITraitCollection) in
            view.updateFonts()
            view.updateMaterial()
            view.setNeedsLayout()
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(purpose: String) {
        barcode = purpose == "barcode"
        product = purpose == "product"
        title.text = barcode ? "Scan barcode" : (product ? "Scan product" : "Scan expiry")
        heading.text = barcode ? "Find the barcode" : (product ? "Show the front label" : "Find the printed date")
        configureSymbol(close, symbol: "xmark", label: "Close camera")
        configureSymbol(torch, symbol: "bolt.slash.fill", label: "Turn torch on")
        configureSymbol(photos, symbol: "photo.on.rectangle", label: "Choose from Photos")
        configureSymbol(help, symbol: "questionmark", label: "Scanning tips")
        photos.configuration?.title = "Photos"
        photos.configuration?.imagePlacement = .top
        photos.configuration?.imagePadding = 5
        photos.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .caption2)
            return attributes
        }
        capture.accessibilityLabel = barcode ? "Read barcode from photo" : (product ? "Read product name from photo" : "Scan expiry date from photo")
        capture.accessibilityHint = "Takes a photo and reads it on this iPhone"
        close.accessibilityIdentifier = "cameraClose"
        capture.accessibilityIdentifier = "cameraShutter"
        photos.accessibilityIdentifier = "cameraPhotos"
        help.accessibilityIdentifier = "cameraTips"
        torch.accessibilityIdentifier = "cameraTorch"
        updateFonts()
    }

    func setTorch(_ enabled: Bool) {
        torch.configuration?.image = UIImage(systemName: enabled ? "bolt.fill" : "bolt.slash.fill")
        torch.configuration?.baseForegroundColor = enabled ? .systemYellow : .white
        torch.accessibilityLabel = enabled ? "Turn torch off" : "Turn torch on"
        torch.accessibilityValue = enabled ? "On" : "Off"
        torch.accessibilityTraits = enabled ? [.button, .selected] : .button
    }

    func setProcessing(_ processing: Bool) {
        if processing { activity.startAnimating() } else { activity.stopAnimating() }
    }

    private func configureSymbol(_ button: UIButton, symbol: String, label: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        button.accessibilityLabel = label
        if button === close || button === torch {
            button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            button.layer.cornerRadius = 24
        }
    }

    private func updateFonts() {
        title.font = .preferredFont(forTextStyle: .subheadline)
        heading.font = .preferredFont(forTextStyle: .headline)
        status.font = .preferredFont(forTextStyle: .subheadline)
        [title, heading, status].forEach { $0.adjustsFontForContentSizeCategory = true }
        title.isHidden = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        photos.configuration?.title = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? nil : "Photos"
    }

    @objc private func updateMaterial() {
        let opaque = UIAccessibility.isReduceTransparencyEnabled
        dock.effect = opaque ? nil : UIBlurEffect(style: .systemUltraThinMaterialDark)
        dock.backgroundColor = opaque ? .black : UIColor.black.withAlphaComponent(0.2)
        corners.lineWidth = traitCollection.accessibilityContrast == .high ? 4 : 3
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let safe = bounds.inset(by: safeAreaInsets)
        let landscape = safe.width > safe.height
        close.frame = CGRect(x: safe.minX + 16, y: safe.minY + 8, width: 48, height: 48)
        torch.frame = CGRect(x: safe.maxX - 64, y: safe.minY + 8, width: 48, height: 48)
        title.frame = CGRect(x: close.frame.maxX + 12, y: close.frame.minY, width: max(0, torch.frame.minX - close.frame.maxX - 24), height: 48)

        let panelWidth = landscape ? min(300, safe.width * 0.43) : min(500, safe.width - 32)
        let textWidth = panelWidth - 32
        let headingSize = heading.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let statusSize = status.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let textHeight = headingSize.height + statusSize.height + 8
        let desiredHeight = textHeight + 140
        let availableHeight = max(140, safe.height - 84)
        let panelHeight = landscape ? availableHeight : min(desiredHeight, max(180, safe.height * 0.48))
        dock.frame = CGRect(x: landscape ? safe.maxX - panelWidth - 12 : safe.midX - panelWidth / 2,
                            y: safe.maxY - panelHeight - 12, width: panelWidth, height: panelHeight)
        textScroll.frame = CGRect(x: 16, y: 20, width: textWidth, height: max(24, panelHeight - 136))
        heading.frame = CGRect(x: 0, y: 0, width: textWidth, height: headingSize.height)
        status.frame = CGRect(x: 0, y: heading.frame.maxY + 8, width: textWidth, height: statusSize.height)
        textScroll.contentSize = CGSize(width: textWidth, height: textHeight)
        let controlY = panelHeight - 98
        capture.frame = CGRect(x: panelWidth / 2 - 38, y: controlY, width: 76, height: 76)
        photos.frame = CGRect(x: 12, y: controlY + 8, width: 56, height: 60)
        help.frame = CGRect(x: panelWidth - 64, y: controlY + 14, width: 48, height: 48)
        activity.center = CGPoint(x: 38, y: 38)
        activity.color = .black

        let viewport = CGRect(x: safe.minX + 24, y: close.frame.maxY + 20,
                              width: max(0, (landscape ? dock.frame.minX - 24 : safe.maxX - 24) - safe.minX - 24),
                              height: max(0, (landscape ? safe.maxY - 20 : dock.frame.minY - 28) - close.frame.maxY - 20))
        let width = min(viewport.width, 350)
        let height = min(viewport.height, barcode ? 200 : (product ? 300 : 156))
        let frame = CGRect(x: viewport.midX - width / 2, y: viewport.midY - height / 2, width: width, height: height)
        let mask = UIBezierPath(rect: bounds)
        mask.append(UIBezierPath(roundedRect: frame, cornerRadius: 18))
        shade.frame = bounds
        shade.path = mask.cgPath
        let path = UIBezierPath()
        let length: CGFloat = min(28, height / 3)
        for (point, dx, dy) in [(CGPoint(x: frame.minX, y: frame.minY), CGFloat(1), CGFloat(1)),
                                (CGPoint(x: frame.maxX, y: frame.minY), CGFloat(-1), CGFloat(1)),
                                (CGPoint(x: frame.minX, y: frame.maxY), CGFloat(1), CGFloat(-1)),
                                (CGPoint(x: frame.maxX, y: frame.maxY), CGFloat(-1), CGFloat(-1))] {
            path.move(to: CGPoint(x: point.x, y: point.y + dy * length))
            path.addLine(to: CGPoint(x: point.x, y: point.y + dy * 10))
            path.addQuadCurve(to: CGPoint(x: point.x + dx * 10, y: point.y), controlPoint: point)
            path.addLine(to: CGPoint(x: point.x + dx * length, y: point.y))
        }
        corners.frame = bounds
        corners.path = path.cgPath
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

@MainActor
final class CameraStatusLabel: UILabel {
    var textDidChange: (() -> Void)?
    override var text: String? { didSet { textDidChange?() } }
}

@MainActor
final class CameraShutterButton: UIButton {
    private let disk = CALayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 4
        disk.backgroundColor = UIColor.white.cgColor
        layer.addSublayer(disk)
        accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var isEnabled: Bool { didSet { alpha = isEnabled ? 1 : 0.45 } }
    override var isHighlighted: Bool { didSet { disk.opacity = isHighlighted ? 0.65 : 1 } }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        disk.frame = bounds.insetBy(dx: 7, dy: 7)
        disk.cornerRadius = disk.bounds.width / 2
    }
}
#endif
