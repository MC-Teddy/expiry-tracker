import Foundation

struct CameraLensCandidate {
    enum Kind { case triple, dualWide, wide, ultraWide }
    let id: String
    let kind: Kind
    let continuousFocus: Bool
    let automaticSwitching: Bool
}

enum CameraLensPolicy {
    /// First virtual threshold restores normal wide framing, never telephoto.
    static func initialVirtualZoom(switchOverFactors: [Double], minimum: Double, maximum: Double) -> Double? {
        wideFramingFactor(wideIndex: 1, switchOverFactors: switchOverFactors, minimum: minimum, maximum: maximum)
    }

    /// The threshold just before the wide constituent restores standard framing
    /// on virtual devices whose native factor 1 starts at ultra-wide. No UI zoom.
    static func wideFramingFactor(wideIndex: Int, switchOverFactors: [Double], minimum: Double, maximum: Double) -> Double? {
        guard wideIndex > 0, wideIndex <= switchOverFactors.count,
              minimum.isFinite, maximum.isFinite, minimum > 0, maximum >= minimum else { return nil }
        let factor = switchOverFactors[wideIndex - 1]
        guard factor.isFinite, factor > 0 else { return nil }
        return min(maximum, max(minimum, factor))
    }

    /// Keep normal wide framing while allowing the system to use a closer-focus
    /// constituent. A physical wide camera remains the compatibility fallback.
    static func automaticCamera(in candidates: [CameraLensCandidate]) -> CameraLensCandidate? {
        for kind: CameraLensCandidate.Kind in [.triple, .dualWide] {
            if let camera = candidates.first(where: { $0.kind == kind && $0.continuousFocus && $0.automaticSwitching }) { return camera }
        }
        return candidates.first { $0.kind == .wide }
    }

    /// Fixed-focus ultra-wide cameras must not be advertised as a close-up option.
    static func closeUpCamera(in candidates: [CameraLensCandidate]) -> CameraLensCandidate? {
        candidates.first { $0.kind == .ultraWide && $0.continuousFocus }
    }
}
