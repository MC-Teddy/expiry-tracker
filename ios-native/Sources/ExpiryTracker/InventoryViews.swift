#if canImport(SwiftUI)
import SwiftUI
import Combine
import ExpiryCore

struct TrackerHome: View {
    var body: some View {
        TabView {
            InventoryView().tabItem { Label("Inventory", systemImage: "square.stack.3d.up") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

private struct EditorRequest: Identifiable { let id = UUID(); var scan = false }

struct InventoryView: View {
    @EnvironmentObject private var model: TrackerModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var search = ""
    @State private var filter: ExpiryStatus?
    @State private var editor: EditorRequest?
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let statuses: [ExpiryStatus] = [.expired, .critical, .soon, .fresh]
    private var items: [ExpiryItem] {
        model.snapshot.items.filter { item in
            (filter == nil || item.status(settings: model.snapshot.settings, now: now, calendar: DayCodec.calendar) == filter) &&
            (search.isEmpty || [item.name, item.category, item.notes, item.barcode ?? ""].contains { $0.localizedCaseInsensitiveContains(search) })
        }.sorted { $0.expiry == $1.expiry ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.expiry < $1.expiry }
    }
    private func count(_ status: ExpiryStatus) -> Int {
        model.snapshot.items.filter { $0.status(settings: model.snapshot.settings, now: now, calendar: DayCodec.calendar) == status }.count
    }
    var body: some View {
        NavigationStack {
            List {
                if model.ready {
                    Section { ScanAction { editor = EditorRequest(scan: true) } }.listSectionSeparator(.hidden)
                    if !model.snapshot.items.isEmpty {
                        Section {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                                ForEach(statuses, id: \.rawValue) { status in overview(status) }
                            }
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                Section {
                    inventoryContent
                } header: {
                    HStack {
                        Text(filter?.title ?? "Your items")
                        Text("\(items.count)").foregroundStyle(.secondary).monospacedDigit()
                        Spacer()
                        if filter != nil {
                            Button("Clear") { filter = nil }.textCase(nil).frame(minHeight: 44).accessibilityLabel("Show all items")
                        }
                    }.textCase(nil).font(.subheadline.weight(.semibold))
                } footer: {
                    if model.ready && !items.isEmpty { Text("Soonest expiry first · Stored on this iPhone") }
                }
            }
            .listStyle(.insetGrouped).listSectionSpacing(20)
            .navigationTitle("Inventory")
            .searchable(text: $search, prompt: "Search your items")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = EditorRequest() } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add item").disabled(!model.ready)
                }
            }
            .sheet(item: $editor) { request in ItemEditor(item: nil, startWithScan: request.scan) }
            .onReceive(timer) { now = $0 }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date() } }
        }
    }

    private func overview(_ status: ExpiryStatus) -> some View {
        Button { filter = filter == status ? nil : status } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: status.symbol).font(.body.weight(.semibold)).foregroundStyle(status.color)
                    Spacer(minLength: 8)
                    Text("\(count(status))").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.primary).monospacedDigit()
                }
                Text(status.title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.trackerSurface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(filter == status ? Color.trackerAccent : .clear, lineWidth: 2))
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityLabel("\(status.title), \(count(status)) items")
            .accessibilityHint(filter == status ? "Double tap to show all items" : "Double tap to show these items")
            .accessibilityAddTraits(filter == status ? .isSelected : [])
    }

    @ViewBuilder private var inventoryContent: some View {
        if !model.ready {
            ContentUnavailableView {
                Label("Unable to open inventory", systemImage: "externaldrive.badge.exclamationmark")
            } description: { Text("Your saved inventory has not been overwritten. Try opening storage again.") }
            actions: { Button("Try again") { model.load() }.buttonStyle(.borderedProminent) }
        } else if items.isEmpty {
            ContentUnavailableView {
                Label(model.snapshot.items.isEmpty ? "A little less waste." : "No items found", systemImage: model.snapshot.items.isEmpty ? "leaf" : "magnifyingglass")
            } description: {
                Text(model.snapshot.items.isEmpty ? "Keep expiry dates in one place. Scan a label or add your first item." : "Try another search or clear the selected status.")
            } actions: {
                if model.snapshot.items.isEmpty {
                    Button("Add an item") { editor = EditorRequest() }.buttonStyle(.borderedProminent)
                } else {
                    Button("Show all items") { filter = nil; search = "" }.buttonStyle(.bordered)
                }
            }.padding(.vertical, 12)
        } else {
            ForEach(items) { item in
                NavigationLink { ItemDetail(itemID: item.id) } label: { ItemRow(item: item, now: now) }
            }
        }
    }
}

struct ItemRow: View {
    @EnvironmentObject private var model: TrackerModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: ExpiryItem
    var now = Date()
    var body: some View {
        let status = item.status(settings: model.snapshot.settings, now: now, calendar: DayCodec.calendar)
        HStack(alignment: .top, spacing: 14) {
            ItemArtwork(item: item)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name).font(.headline).foregroundStyle(.primary)
                Text("\(item.category) · Qty \(item.quantity)").font(.subheadline).foregroundStyle(.secondary)
                if typeSize.isAccessibilitySize {
                    StatusLabel(status: status)
                    expiryText
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack { StatusLabel(status: status); Spacer(minLength: 8); expiryText }
                        VStack(alignment: .leading, spacing: 4) { StatusLabel(status: status); expiryText }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }
    private var expiryText: some View {
        Text(DayCodec.date(item.expiry)?.formatted(date: .abbreviated, time: .omitted) ?? item.expiry)
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

struct ItemDetail: View {
    @EnvironmentObject private var model: TrackerModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let itemID: UUID
    @State private var editing = false
    @State private var deleting = false
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var body: some View {
        Group {
            if let item = model.snapshot.items.first(where: { $0.id == itemID }) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 18) {
                            if let data = item.photo, let image = PhotoThumbnail.image(data) {
                                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityLabel("Photo of \(item.name)")
                            }
                            Text(item.name).font(.title.bold()).textSelection(.enabled)
                            Text(item.category).font(.subheadline).foregroundStyle(.secondary)
                            Divider()
                            expirySummary(item)
                        }.padding(.vertical, 8)
                    }
                    Section("Details") {
                        LabeledContent("Quantity", value: "\(item.quantity)")
                        if let barcode = item.barcode {
                            LabeledContent("Barcode") { Text(barcode).textSelection(.enabled).font(.body.monospaced()).multilineTextAlignment(.trailing) }
                        }
                    }
                    if !item.notes.isEmpty { Section("Notes") { Text(item.notes).textSelection(.enabled) } }
                    Section { Button("Delete item", role: .destructive) { deleting = true }.frame(minHeight: 44) }
                }.listStyle(.insetGrouped).listSectionSpacing(20)
                    .navigationTitle("Item details").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
                    .sheet(isPresented: $editing) { ItemEditor(item: item) }
                    .confirmationDialog("Delete \(item.name)?", isPresented: $deleting, titleVisibility: .visible) {
                        Button("Delete item", role: .destructive) { if model.delete(item) { dismiss() } }
                    } message: { Text("The item and its photo will be removed from this iPhone.") }
            } else { ContentUnavailableView("Item no longer exists", systemImage: "shippingbox") }
        }.onReceive(timer) { now = $0 }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = Date() } }
    }
    private func expirySummary(_ item: ExpiryItem) -> some View {
        let status = item.status(settings: model.snapshot.settings, now: now, calendar: DayCodec.calendar)
        let days = item.daysRemaining(now: now, calendar: DayCodec.calendar)
        let remaining = days < 0 ? "Expired \(abs(days)) \(days == -1 ? "day" : "days") ago" : (days == 0 ? "Expires today" : "\(days) \(days == 1 ? "day" : "days") remaining")
        return VStack(alignment: .leading, spacing: 8) {
            StatusLabel(status: status)
            Text(DayCodec.date(item.expiry)?.formatted(date: .long, time: .omitted) ?? item.expiry).font(.title3.weight(.semibold))
            Text(remaining).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
#endif
