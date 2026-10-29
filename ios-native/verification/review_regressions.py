"""Source wiring checks supplement (not replace) Swift behavior/runtime tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent

class ReviewWiringTests(unittest.TestCase):
    def test_repository_validates_apple_headers(self):
        source = (ROOT / 'Sources/ExpiryCore/LocalRepository.swift').read_text()
        self.assertIn('#if canImport(ImageIO)', source)
        self.assertIn('PhotoPolicy.validatedSource(photo)', source)

    def test_every_photo_renderer_uses_bounded_thumbnail(self):
        sources = [(ROOT / 'Sources/ExpiryTracker' / name).read_text() for name in ['InventoryViews.swift', 'ItemEditor.swift']]
        for source in sources:
            self.assertNotIn('UIImage(data:', source)
            self.assertIn('PhotoThumbnail.image', source)

    def test_editor_gates_success_failure_and_busy_with_same_generation(self):
        source = (ROOT / 'Sources/ExpiryTracker/ItemEditor.swift').read_text()
        self.assertIn('let token = recognition.begin()', source)
        self.assertEqual(source.count('guard recognition.finish(token) else { return }'), 2)
        self.assertIn('recognition.invalidate(); captureState.removePhoto()', source)
        self.assertIn('var recognizing: Bool { recognition.isBusy }', source)
        self.assertNotIn('defer { recognizing = false }', source)

    def test_camera_never_dismisses_its_swiftui_owner(self):
        source = (ROOT / 'Sources/ExpiryTracker/CameraController.swift').read_text()
        finish = source.split('private func finish(')[1]
        self.assertNotIn('self?.dismiss(', source)
        self.assertNotIn('else { dismiss(', finish)
        self.assertNotRegex(source, r'(?<!\.)\bdismiss\(')
        self.assertIn('child.dismiss(animated:false, completion: deliver)', finish)
        self.assertIn('guard !finished else { return }', finish)
        self.assertIn('pickerDismissalCompletion = deliver', finish)

    def test_editor_stages_capture_until_cover_dismissed(self):
        source = (ROOT / 'Sources/ExpiryTracker/ItemEditor.swift').read_text()
        self.assertIn('onDismiss: cameraDidDismiss', source)
        cover = source.split('.fullScreenCover(')[1].split('.alert(')[0]
        self.assertNotIn('LabelRecognition.text', cover)
        self.assertIn('captureState.receive(result)', cover)
        self.assertIn('if let warning = captureState.warning', source)
        self.assertIn('captureState.completeRecognition', source)
        self.assertIn('.onDisappear { recognition.invalidate() }', source)
        self.assertIn('Button("OK") { captureState.errorMessage = nil }', source)
        self.assertIn('set: { _ in }', source, 'Only explicit OK clears the error alert')
        self.assertNotIn('dismiss()', cover)

    def test_camera_applies_policy_on_serial_queue_and_reactivates_on_subject_change(self):
        source = (ROOT / 'Sources/ExpiryTracker/CameraController.swift').read_text()
        for required in ['CameraLensPolicy.automaticCamera', 'CameraLensPolicy.initialVirtualZoom',
                         'CameraFocusPlan(capabilities:', 'focusWork.performIfCurrent',
                         'camera.activePrimaryConstituentDeviceSwitchingBehavior != .unsupported',
                         'camera.isFocusModeSupported(.autoFocus)', 'camera.focusMode = .continuousAutoFocus',
                         'camera.autoFocusRangeRestriction = .none', 'camera.exposureMode = .continuousAutoExposure',
                         'camera.isSubjectAreaChangeMonitoringEnabled = plan.monitorSubjectArea',
                         'AVCaptureDevice.subjectAreaDidChangeNotification', 'focusWork.suspend()', 'focusWork.finish()']:
            self.assertIn(required, source)
        self.assertNotIn('fallbackPrimaryConstituentDevices =', source)
        self.assertNotIn('camera.focusMode = .locked', source)
        self.assertNotIn('switchOverFactors.last', source)
        finish = source.split('private func finish(')[1]
        self.assertLess(finish.index('focusWork.finish()'), finish.index('pauseSession()'))

    def test_library_dismissal_precedes_processing(self):
        source = (ROOT / 'Sources/ExpiryTracker/CameraController.swift').read_text()
        picker = source.split('nonisolated func picker(')[1].split('private func pauseSession')[0]
        self.assertIn('picker.dismiss(animated:true) {', picker)
        self.assertLess(picker.index('picker.dismiss(animated:true) {'), picker.index('provider.loadFileRepresentation'))

if __name__ == '__main__':
    unittest.main()
