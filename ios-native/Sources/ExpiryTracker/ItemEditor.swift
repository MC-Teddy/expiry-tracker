#if canImport(SwiftUI)
import SwiftUI
import Vision
import CoreImage
import ExpiryCore

struct NativeCamera: UIViewControllerRepresentable {
    let purpose: String
    let completion: (Result<CameraCapture, Error>) -> Void
    func makeUIViewController(context: Context) -> CameraController { CameraController(purpose: purpose, completion: completion) }
    func updateUIViewController(_ controller: CameraController, context: Context) {}
    static func dismantleUIViewController(_ controller: CameraController, coordinator: ()) { controller.cancel() }
}

private enum LabelRecognition {
    struct Reading: Sendable {
        let text: String
        let allowsAutomaticFill: Bool
        let productLines: [ProductTextLine]
        let dateLines: [ProductTextLine]
    }
    static func text(in data: Data) async throws -> Reading {
        try await Task.detached(priority: .userInitiated) {
            func recognize(_ handler: VNImageRequestHandler) throws -> [ProductTextLine] {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.automaticallyDetectsLanguage = true
                request.minimumTextHeight = 0.005
                try handler.perform([request])
                return (request.results ?? []).compactMap { observation -> ProductTextLine? in
                guard let text = observation.topCandidates(1).first else { return nil }
                let rect = observation.boundingBox
                return ProductTextLine(text: text.string, confidence: Double(text.confidence),
                                       x: Double(rect.minX), y: Double(rect.minY), width: Double(rect.width), height: Double(rect.height))
                }
            }
            let productLines = try recognize(VNImageRequestHandler(data: data, options: [:]))
            var dateLines = productLines
            // One bounded contrast retry for faint/dot-matrix printing. Keep
            // both passes so conflicting readings stay reviewable.
            if !DateSuggestions.reading(lines: dateLines).hasDates, let source = CIImage(data: data) {
                try Task.checkCancellation()
                let enhanced = source.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.5, kCIInputBrightnessKey: 0.04])
                let context = CIContext(options: [.cacheIntermediates: false])
                if let image = context.createCGImage(enhanced, from: source.extent),
                   let retry = try? recognize(VNImageRequestHandler(cgImage: image, options: [:])) { dateLines += retry }
            }
            return Reading(text: dateLines.map(\.text).joined(separator: "\n"),
                           allowsAutomaticFill: !dateLines.isEmpty, productLines: productLines, dateLines: dateLines)
        }.value
    }
}

struct ItemEditor: View {
    @EnvironmentObject private var model: TrackerModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: ExpiryItem?
    let startWithScan: Bool
    @State private var didStartScan = false
    @State private var moreDetails = false
    @State private var showNameSuggestions = true
    @State private var productName: ProductNameDraft
    private var name: String { productName.value }
    @State private var category: String
    @State private var quantity: Int
    @State private var date: Date
    @State private var manualDateRevision = 0
    @State private var notes: String
    @State private var captureState: EditorCaptureState
    @State private var cameraPurpose = "expiry"
    @State private var recognition = RecognitionGeneration()
    private var recognizing: Bool { recognition.isBusy }
    @State private var discard = false
    @State private var photoDelete = false
    @State private var dirty = false

    init(item: ExpiryItem?, startWithScan: Bool = false) {
        self.item = item
        self.startWithScan = startWithScan
        _moreDetails = State(initialValue: !(item?.notes ?? "").isEmpty || !(item?.barcode ?? "").isEmpty)
        _productName = State(initialValue: ProductNameDraft(item?.name ?? ""))
        _category = State(initialValue: item?.category ?? "Food")
        _quantity = State(initialValue: item?.quantity ?? 1)
        _date = State(initialValue: item.flatMap { DayCodec.date($0.expiry) } ?? Date())
        _notes = State(initialValue: item?.notes ?? "")
        _captureState = State(initialValue: EditorCaptureState(photo: item?.photo, barcode: item?.barcode ?? ""))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: Binding(get: { name }, set: { productName.edit($0) }), prompt: Text("e.g. Fresh milk")).textInputAutocapitalization(.words)
                        .accessibilityLabel("Item name")
                    if productName.isFromPhoto {
                        Label("Name from photo", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(.green)
                    }
                    Button {
                        recognition.invalidate(); cameraPurpose = "product"; captureState.beginCamera(purpose: .product)
                    } label: {
                        Label("Scan product name", systemImage: "text.viewfinder").frame(minHeight: 44)
                    }.disabled(recognizing)
                    if captureState.photoPurpose == .product { scanFeedback }
                    if !captureState.productNames.candidates.isEmpty {
                        DisclosureGroup("Suggested names from photo", isExpanded: $showNameSuggestions) {
                            ForEach(captureState.productNames.candidates, id: \.self) { candidate in
                                Button {
                                    productName.choose(candidate); dirty = true
                                } label: {
                                    HStack {
                                        Text(candidate).multilineTextAlignment(.leading)
                                        Spacer()
                                        if name == candidate { Image(systemName: "checkmark.circle.fill") }
                                    }.frame(minHeight: 44)
                                }.accessibilityAddTraits(name == candidate ? .isSelected : [])
                            }
                        }
                    }
                    LabeledContent("Category") {
                        TextField("Category", text: $category).textInputAutocapitalization(.words).multilineTextAlignment(.trailing)
                    }
                    Stepper(value: $quantity, in: 1...999_999) {
                        LabeledContent("Quantity", value: "\(quantity)").monospacedDigit()
                    }
                } header: { Text("Item") } footer: {
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Enter a name or scan the product label to save this item.")
                    } else if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Enter a category to save this item.")
                    }
                }
                Section {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Expires")
                            expiryPicker.labelsHidden()
                        }
                    } else { expiryPicker }
                    Button { beginExpiryScan() } label: {
                        Label("Scan expiry date", systemImage: "viewfinder")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }.disabled(recognizing)
                        .accessibilityHint("Take a photo or choose a label from Photos to fill this date.")
                    if captureState.photoPurpose == .expiry { scanFeedback }
                    if captureState.automaticallyFilledDate == DayCodec.string(date) {
                        Label("Filled from photo", systemImage: "checkmark.circle.fill")
                            .font(.subheadline).foregroundStyle(.green)
                            .accessibilityIdentifier("expiryAutofillFeedback")
                    }
                    ForEach(captureState.monthSuggestions) { candidate in
                        Button {
                            if let iso = captureState.chooseMonth(candidate), let value = DayCodec.date(iso) {
                                date = value; manualDateRevision += 1; dirty = true
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(monthTitle(candidate))
                                    Text("Use \(DayCodec.date(candidate.lastDay)?.formatted(date: .long, time: .omitted) ?? candidate.lastDay) · last day of month")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if captureState.selectedMonthExpiry == candidate.lastDay { Image(systemName: "checkmark.circle.fill") }
                            }.frame(minHeight: 44)
                        }
                    }
                    if captureState.selectedMonthExpiry != nil {
                        Label("Month/year label. You chose the month's last day.", systemImage: "calendar")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !captureState.suggestions.isEmpty && captureState.automaticallyFilledDate == nil {
                        ForEach(captureState.suggestions, id: \.self) { candidate in
                            Button {
                                if let value = DayCodec.date(candidate) {
                                    date = value; manualDateRevision += 1; captureState.clearAutofillFeedback(); dirty = true
                                }
                            } label: {
                                HStack {
                                    Text(DayCodec.date(candidate)?.formatted(date: .long, time: .omitted) ?? candidate)
                                    Spacer()
                                    if DayCodec.string(date) == candidate { Image(systemName: "checkmark.circle.fill") }
                                }.frame(minHeight: 44)
                            }
                            .accessibilityAddTraits(DayCodec.string(date) == candidate ? .isSelected : [])
                        }
                        Text("Choose the date shown on the label.").font(.caption).foregroundStyle(.secondary)
                    }
                } header: { Text("Expiry date") } footer: {
                    Text(captureState.dateNeedsReview ? "Confirm a suggested date or enter it manually to enable Save." : "Scan a label or enter the date manually. Check it before saving.")
                }
                if captureState.photo != nil {
                    Section(captureState.photoPurpose == .product ? "Product photo" : "Label photo") {
                    if let data = captureState.photo, let image = PhotoThumbnail.image(data) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Attached item photo")
                    }
                    if !captureState.recognizedText.isEmpty {
                        DisclosureGroup("Text from label") { Text(captureState.recognizedText).font(.subheadline).textSelection(.enabled) }
                    }
                    Button("Remove photo", role: .destructive) { photoDelete = true }
                    }
                }
                Section {
                    DisclosureGroup("More details", isExpanded: $moreDetails) {
                        TextField("Barcode", text: $captureState.barcode).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button { recognition.invalidate(); cameraPurpose = "barcode"; captureState.beginCamera() } label: {
                            Label("Scan barcode", systemImage: "barcode.viewfinder").frame(minHeight: 44)
                        }
                        TextField("Add a note", text: $notes, axis: .vertical).lineLimit(3...8).accessibilityLabel("Notes")
                    }
                } footer: { Label("Free recognition. Always on this iPhone.", systemImage: "lock.shield").font(.caption) }
            }
            .formStyle(.grouped).listSectionSpacing(20).scrollDismissesKeyboard(.interactively)
            .navigationTitle(item == nil ? "New item" : "Edit item").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discard = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold().disabled(recognizing || captureState.dateNeedsReview || !model.ready || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .task {
                guard startWithScan, !didStartScan else { return }
                didStartScan = true
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                beginExpiryScan()
            }
            .onChange(of: name) { _, _ in dirty = true }
            .onChange(of: category) { _, _ in dirty = true }
            .onChange(of: quantity) { _, _ in dirty = true }
            .onChange(of: date) { _, _ in dirty = true }
            .onChange(of: notes) { _, _ in dirty = true }
            .onChange(of: captureState.barcode) { _, _ in dirty = true }
            .onDisappear { recognition.invalidate() }
            .interactiveDismissDisabled(dirty || recognizing)
            .fullScreenCover(isPresented: Binding(get: { captureState.isPresented }, set: { if !$0 { captureState.receive(.failure(CameraFailure.cancelled)) } }), onDismiss: cameraDidDismiss) {
                NativeCamera(purpose: cameraPurpose) { result in
                    captureState.receive(result)
                }.ignoresSafeArea()
            }
            .alert("Check this item", isPresented: Binding(get: { captureState.errorMessage != nil }, set: { _ in })) {
                Button("OK") { captureState.errorMessage = nil }
            } message: { Text(captureState.errorMessage ?? "") }
            .confirmationDialog("Discard unsaved changes?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Remove the attached photo?", isPresented: $photoDelete, titleVisibility: .visible) {
                Button("Remove photo", role: .destructive) { recognition.invalidate(); captureState.removePhoto(); dirty = true }
            }
        }
    }
    private var expiryPicker: some View {
        DatePicker("Expires", selection: Binding(get: { date }, set: { value in
            date = value
            manualDateRevision += 1
            captureState.clearAutofillFeedback()
        }), displayedComponents: .date)
            .environment(\.calendar, DayCodec.calendar)
            .environment(\.timeZone, TimeZone.current)
            .accessibilityLabel("Expiry date")
    }
    @ViewBuilder private var scanFeedback: some View {
        if recognizing { ProgressView("Reading the label…").padding(.vertical, 4) }
        if let warning = captureState.warning {
            Label(warning, systemImage: "exclamationmark.triangle")
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func monthTitle(_ candidate: DateSuggestions.MonthCandidate) -> String {
        guard let date = DayCodec.date(candidate.lastDay) else { return candidate.yearMonth }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = DayCodec.calendar
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }
    private func beginExpiryScan() {
        recognition.invalidate()
        cameraPurpose = "expiry"
        captureState.beginCamera()
    }
    private func cameraDidDismiss() {
        let oldPhoto = captureState.photo
        let oldBarcode = captureState.barcode
        let newPhoto = captureState.cameraDidDismiss()
        if captureState.photo != oldPhoto || captureState.barcode != oldBarcode { dirty = true }
        guard let data = newPhoto else { return }
        dirty = true
        let dateRevision = manualDateRevision
        let nameRevision = productName.revision
        let token = recognition.begin()
        Task { @MainActor in
            do {
                let reading = try await LabelRecognition.text(in: data)
                guard recognition.finish(token) else { return }
                if let candidate = captureState.completeRecognition(.success(reading.text),
                    allowAutomaticFill: reading.allowsAutomaticFill && dateRevision == manualDateRevision,
                    productLines: reading.productLines, dateLines: reading.dateLines),
                   let value = DayCodec.date(candidate) {
                    date = value
                    dirty = true
                    UIAccessibility.post(notification: .announcement, argument: "Expiry date filled: \(value.formatted(date: .long, time: .omitted))")
                }
                if dateRevision != manualDateRevision { captureState.clearAutofillFeedback() }
                if productName.fill(from: captureState.productNames, startedAt: nameRevision) {
                    dirty = true
                    UIAccessibility.post(notification: .announcement, argument: "Product name filled: \(name)")
                }
            } catch {
                guard recognition.finish(token) else { return }
                captureState.completeRecognition(.failure(error))
            }
        }
    }
    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanCategory.isEmpty else { captureState.errorMessage = "Enter a name and category before saving."; return }
        let updated = ExpiryItem(id: item?.id ?? UUID(), name: cleanName, category: cleanCategory, quantity: quantity, expiry: DayCodec.string(date), notes: notes, barcode: captureState.barcode.isEmpty ? nil : captureState.barcode, photo: captureState.photo, createdAt: item?.createdAt ?? Date())
        if model.upsert(updated) { dismiss() }
        else { captureState.errorMessage = model.errorMessage; model.errorMessage = nil }
    }
}
#endif
