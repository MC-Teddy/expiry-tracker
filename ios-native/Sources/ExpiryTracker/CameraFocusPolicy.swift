import Foundation

struct CameraFocusCapabilities {
    let continuousFocus: Bool
    var autoFocus: Bool = false
    let focusPoint: Bool
    let continuousExposure: Bool
    let exposurePoint: Bool
    let rangeRestriction: Bool
}

/// Shared by initial setup, subject-area changes, and optional tap targeting.
struct CameraFocusPlan {
    enum FocusMode { case continuous, auto }
    let focusMode: FocusMode?
    var continuousFocus: Bool { focusMode == .continuous }
    let focusPoint: CGPoint?
    let continuousExposure: Bool
    let exposurePoint: CGPoint?
    let monitorSubjectArea: Bool
    let resetFocusRange: Bool

    init(capabilities: CameraFocusCapabilities, point: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        let normalized = CGPoint(x: point.x.isFinite ? min(1, max(0, point.x)) : 0.5,
                                 y: point.y.isFinite ? min(1, max(0, point.y)) : 0.5)
        focusMode = capabilities.continuousFocus ? .continuous : (capabilities.autoFocus ? .auto : nil)
        focusPoint = focusMode != nil && capabilities.focusPoint ? normalized : nil
        continuousExposure = capabilities.continuousExposure
        exposurePoint = capabilities.continuousExposure && capabilities.exposurePoint ? normalized : nil
        resetFocusRange = focusMode != nil && capabilities.rangeRestriction
        monitorSubjectArea = focusMode != nil || capabilities.continuousExposure
    }
}
