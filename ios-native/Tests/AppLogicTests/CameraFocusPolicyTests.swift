import XCTest
@testable import ExpiryTracker

final class CameraFocusPolicyTests: XCTestCase {
    func testAutoFocusFallbackAndUnrestrictedRange() {
        let fallback = CameraFocusPlan(capabilities: .init(continuousFocus: false, autoFocus: true, focusPoint: true, continuousExposure: false, exposurePoint: false, rangeRestriction: true))
        XCTAssertEqual(fallback.focusMode, .auto)
        XCTAssertEqual(fallback.focusPoint, CGPoint(x: 0.5, y: 0.5))
        XCTAssertTrue(fallback.resetFocusRange)
        XCTAssertTrue(fallback.monitorSubjectArea)
        let continuous = CameraFocusPlan(capabilities: .init(continuousFocus: true, autoFocus: true, focusPoint: true, continuousExposure: true, exposurePoint: true, rangeRestriction: true))
        XCTAssertEqual(continuous.focusMode, .continuous)
        let unsupported = CameraFocusPlan(capabilities: .init(continuousFocus: false, focusPoint: false, continuousExposure: false, exposurePoint: false, rangeRestriction: false))
        XCTAssertNil(unsupported.focusMode)
        XCTAssertFalse(unsupported.resetFocusRange)
    }

    func testNormalFramingUsesFirstSwitchOverFactorAndValidatesBounds() {
        XCTAssertEqual(CameraLensPolicy.initialVirtualZoom(switchOverFactors: [2, 6], minimum: 1, maximum: 10), 2)
        XCTAssertEqual(CameraLensPolicy.initialVirtualZoom(switchOverFactors: [2, 6], minimum: 3, maximum: 10), 3)
        XCTAssertEqual(CameraLensPolicy.initialVirtualZoom(switchOverFactors: [2, 6], minimum: 1, maximum: 1.5), 1.5)
        for factors: [Double] in [[], [.nan, 6], [.infinity], [0], [-2]] {
            XCTAssertNil(CameraLensPolicy.initialVirtualZoom(switchOverFactors: factors, minimum: 1, maximum: 10))
        }
        for bounds: (Double, Double) in [(0, 10), (3, 1), (.nan, 10), (1, .infinity)] {
            XCTAssertNil(CameraLensPolicy.initialVirtualZoom(switchOverFactors: [2], minimum: bounds.0, maximum: bounds.1))
        }
    }

    func testNormalFramingUsesWideConstituentThresholdNotAnArbitraryZoom() {
        XCTAssertEqual(CameraLensPolicy.wideFramingFactor(wideIndex: 1, switchOverFactors: [2, 5], minimum: 1, maximum: 10), 2)
        XCTAssertEqual(CameraLensPolicy.wideFramingFactor(wideIndex: 2, switchOverFactors: [1.5, 3], minimum: 1, maximum: 10), 3)
        XCTAssertEqual(CameraLensPolicy.wideFramingFactor(wideIndex: 1, switchOverFactors: [2], minimum: 1, maximum: 1.8), 1.8)
        XCTAssertNil(CameraLensPolicy.wideFramingFactor(wideIndex: 0, switchOverFactors: [], minimum: 1, maximum: 10))
        XCTAssertNil(CameraLensPolicy.wideFramingFactor(wideIndex: 1, switchOverFactors: [], minimum: 1, maximum: 10))
        XCTAssertNil(CameraLensPolicy.wideFramingFactor(wideIndex: 1, switchOverFactors: [.nan], minimum: 1, maximum: 10))
        XCTAssertNil(CameraLensPolicy.wideFramingFactor(wideIndex: 1, switchOverFactors: [2], minimum: 3, maximum: 1))
    }

    func testCameraSelectionPrefersAutofocusVirtualTripleThenDualWideThenWide() {
        let wide = CameraLensCandidate(id: "wide", kind: .wide, continuousFocus: true, automaticSwitching: false)
        let dual = CameraLensCandidate(id: "dual", kind: .dualWide, continuousFocus: true, automaticSwitching: true)
        let triple = CameraLensCandidate(id: "triple", kind: .triple, continuousFocus: true, automaticSwitching: true)
        XCTAssertEqual(CameraLensPolicy.automaticCamera(in: [wide, dual, triple])?.id, "triple")
        XCTAssertEqual(CameraLensPolicy.automaticCamera(in: [wide, dual])?.id, "dual")
        XCTAssertEqual(CameraLensPolicy.automaticCamera(in: [wide])?.id, "wide")
        XCTAssertNil(CameraLensPolicy.automaticCamera(in: []))
        let unsupported = CameraLensCandidate(id: "no-af", kind: .triple, continuousFocus: false, automaticSwitching: true)
        let noSwitching = CameraLensCandidate(id: "no-switch", kind: .dualWide, continuousFocus: true, automaticSwitching: false)
        XCTAssertEqual(CameraLensPolicy.automaticCamera(in: [unsupported, noSwitching, wide])?.id, "wide")
        let ultra = CameraLensCandidate(id: "ultra", kind: .ultraWide, continuousFocus: true, automaticSwitching: false)
        XCTAssertNil(CameraLensPolicy.automaticCamera(in: [ultra]), "Do not change default framing to ultra-wide")
        XCTAssertEqual(CameraLensPolicy.closeUpCamera(in: [ultra, wide])?.id, "ultra")
        let fixedUltra = CameraLensCandidate(id: "fixed", kind: .ultraWide, continuousFocus: false, automaticSwitching: false)
        XCTAssertNil(CameraLensPolicy.closeUpCamera(in: [fixedUltra, wide]), "No close-up option on fixed-focus ultra-wide")
    }

    func testUnsupportedCapabilitiesAreNeverRequested() {
        let plan = CameraFocusPlan(capabilities: .init(continuousFocus: false, focusPoint: false, continuousExposure: false, exposurePoint: false, rangeRestriction: false))
        XCTAssertFalse(plan.continuousFocus)
        XCTAssertNil(plan.focusPoint)
        XCTAssertFalse(plan.continuousExposure)
        XCTAssertNil(plan.exposurePoint)
        XCTAssertFalse(plan.resetFocusRange)
        XCTAssertFalse(plan.monitorSubjectArea)
        let exposureOnly = CameraFocusPlan(capabilities: .init(continuousFocus: false, focusPoint: true, continuousExposure: true, exposurePoint: true, rangeRestriction: true))
        XCTAssertNil(exposureOnly.focusPoint)
        XCTAssertFalse(exposureOnly.resetFocusRange, "A focus range setting is not requested without an autofocus mode")
        XCTAssertEqual(exposureOnly.exposurePoint, CGPoint(x: 0.5, y: 0.5))
        XCTAssertTrue(exposureOnly.monitorSubjectArea)
    }

    func testConvertedPointIsClampedAndNonfiniteComponentsRecenter() {
        let all = CameraFocusCapabilities(continuousFocus: true, focusPoint: true, continuousExposure: true, exposurePoint: true, rangeRestriction: true)
        let clamped = CameraFocusPlan(capabilities: all, point: CGPoint(x: -3, y: 4))
        XCTAssertEqual(clamped.focusPoint, CGPoint(x: 0, y: 1))
        XCTAssertEqual(clamped.exposurePoint, clamped.focusPoint)
        let invalid = CameraFocusPlan(capabilities: all, point: CGPoint(x: CGFloat.nan, y: CGFloat.infinity))
        XCTAssertEqual(invalid.focusPoint, CGPoint(x: 0.5, y: 0.5))
    }

    func testAutomaticFocusPlanUsesSupportedCapabilitiesAtCenter() {
        let plan = CameraFocusPlan(capabilities: .init(continuousFocus: true, focusPoint: true, continuousExposure: true, exposurePoint: true, rangeRestriction: true))
        XCTAssertTrue(plan.continuousFocus)
        XCTAssertEqual(plan.focusPoint, .init(x: 0.5, y: 0.5))
        XCTAssertTrue(plan.continuousExposure)
        XCTAssertEqual(plan.exposurePoint, .init(x: 0.5, y: 0.5))
        XCTAssertTrue(plan.resetFocusRange)
        XCTAssertTrue(plan.monitorSubjectArea)
    }
}
