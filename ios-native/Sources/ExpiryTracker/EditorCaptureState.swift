import Foundation

enum CameraCapture { case photo(Data), barcode(String) }
enum LabelScanPurpose { case expiry, product }

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

/// Main-actor UI callers own presentation; camera results are staged until onDismiss.
/// This state owns scan-related draft fields, never the editor's navigation lifetime.
struct EditorCaptureState {
    var photo: Data?
    var barcode: String
    var errorMessage: String?
    private(set) var warning: String?
    private(set) var recognizedText = ""
    private(set) var suggestions: [String] = []
    private(set) var automaticallyFilledDate: String?
    private(set) var monthSuggestions: [DateSuggestions.MonthCandidate] = []
    private(set) var selectedMonthExpiry: String?
    private(set) var dateNeedsReview = false
    private(set) var productNames = ProductNameSuggestions.Reading()
    private(set) var photoPurpose = LabelScanPurpose.expiry
    private(set) var isPresented = false
    private var pending: Result<CameraCapture, Error>?
    private var pendingPurpose = LabelScanPurpose.expiry

    init(photo: Data? = nil, barcode: String) {
        self.photo = photo
        self.barcode = barcode
    }

    mutating func beginCamera(purpose: LabelScanPurpose = .expiry) { pending = nil; pendingPurpose = purpose; isPresented = true }

    mutating func removePhoto() {
        photo = nil
        warning = nil
        suggestions = []
        recognizedText = ""
        automaticallyFilledDate = nil
        monthSuggestions = []
        selectedMonthExpiry = nil
        dateNeedsReview = false
        productNames = ProductNameSuggestions.Reading()
    }

    mutating func clearAutofillFeedback() {
        automaticallyFilledDate = nil
        selectedMonthExpiry = nil
        dateNeedsReview = false
        if photoPurpose == .expiry { warning = nil }
    }

    mutating func chooseMonth(_ candidate: DateSuggestions.MonthCandidate) -> String? {
        guard monthSuggestions.contains(candidate) else { return nil }
        automaticallyFilledDate = nil
        selectedMonthExpiry = candidate.lastDay
        dateNeedsReview = false
        warning = nil
        return candidate.lastDay
    }

    /// Returns a date only when it is safe to fill the draft. Persistence still
    /// requires the editor's Save action.
    @discardableResult
    mutating func completeRecognition(_ result: Result<String, Error>, allowAutomaticFill: Bool = true,
                                     productLines: [ProductTextLine]? = nil, dateLines: [ProductTextLine]? = nil) -> String? {
        automaticallyFilledDate = nil
        productNames = ProductNameSuggestions.Reading()
        suggestions = []
        warning = nil
        monthSuggestions = []
        selectedMonthExpiry = nil
        dateNeedsReview = false
        switch result {
        case .success(let text):
            recognizedText = text
            productNames = productLines.map { ProductNameSuggestions.reading(lines: $0) } ?? ProductNameSuggestions.reading(text: text)
            let reading = (dateLines ?? productLines).map { DateSuggestions.reading(lines: $0) } ?? DateSuggestions.reading(in: text)
            suggestions = reading.candidates
            monthSuggestions = reading.months
            dateNeedsReview = !reading.months.isEmpty || reading.candidates.count > 1 || reading.requiresReview
            automaticallyFilledDate = allowAutomaticFill ? reading.automaticDate : nil
            if photoPurpose == .product {
                warning = productNames.candidates.isEmpty ? "No product name found. Try the front label in good light, or enter a name below." : nil
            } else if !monthSuggestions.isEmpty {
                warning = "Only a month and year are printed. Choose the last day of that month below, or enter a date."
            } else if suggestions.isEmpty {
                warning = "No complete expiry date found. Try a clearer photo or enter the date above. Include the expiry wording and the full date."
            } else if automaticallyFilledDate == nil {
                warning = "Check the label and choose the expiry date below, or enter it above."
            }
        case .failure(let error):
            recognizedText = ""
            errorMessage = "Photo attached, but the label could not be read. Enter the item details manually. \(error.localizedDescription)"
        }
        return automaticallyFilledDate
    }

    mutating func receive(_ result: Result<CameraCapture, Error>) {
        guard isPresented else { return }
        pending = result
        isPresented = false
    }

    /// Returns a new photo only after the camera cover has actually closed.
    mutating func cameraDidDismiss() -> Data? {
        isPresented = false
        guard let result = pending else { return nil }
        pending = nil
        switch result {
        case .success(.photo(let data)):
            removePhoto()
            photo = data
            photoPurpose = pendingPurpose
            return data
        case .success(.barcode(let code)): barcode = code
        case .failure(CameraFailure.cancelled): break
        case .failure(let error): errorMessage = error.localizedDescription
        }
        return nil
    }
}
