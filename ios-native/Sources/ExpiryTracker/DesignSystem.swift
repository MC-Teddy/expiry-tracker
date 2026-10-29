#if canImport(SwiftUI)
import SwiftUI
import ExpiryCore

extension Color {
    static let trackerAccent = Color(uiColor: .systemBlue)
    static let trackerBackground = Color(uiColor: .systemGroupedBackground)
    static let trackerSurface = Color(uiColor: .secondarySystemGroupedBackground)
}

extension ExpiryStatus {
    var title: String {
        switch self { case .expired: return "Expired"; case .critical: return "Use first"; case .soon: return "Expiring soon"; case .fresh: return "Fresh" }
    }
    var color: Color {
        switch self { case .expired: return .red; case .critical: return .orange; case .soon: return .blue; case .fresh: return .green }
    }
    var symbol: String {
        switch self { case .expired: return "exclamationmark.circle.fill"; case .critical: return "clock.badge.exclamationmark.fill"; case .soon: return "calendar"; case .fresh: return "checkmark.circle.fill" }
    }
}

struct SettingsSymbol: View {
    let name: String
    var color: Color = .trackerAccent
    var body: some View {
        Image(systemName: name).font(.system(.body, weight: .semibold))
            .foregroundStyle(.white).frame(width: 30, height: 30)
            .background(color, in: RoundedRectangle(cornerRadius: 7)).accessibilityHidden(true)
    }
}

struct ScanAction: View {
    var title = "Scan expiry date"
    var subtitle = "Fill the date from a label."
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "viewfinder").font(.system(.title2, weight: .medium))
                    .frame(width: 48, height: 48)
                    .background(Color.trackerAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }.padding(.vertical, 6).frame(minHeight: 60).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(Color.trackerAccent).accessibilityElement(children: .combine)
    }
}

struct StatusLabel: View {
    let status: ExpiryStatus
    var body: some View {
        Label(status.title, systemImage: status.symbol).font(.caption.weight(.semibold)).foregroundStyle(status.color)
    }
}

struct ItemArtwork: View {
    let item: ExpiryItem
    var size: CGFloat = 56
    var body: some View {
        Group {
            if let data = item.photo, let image = PhotoThumbnail.image(data, maximumPixelSize: 160) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "shippingbox").font(.title2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
    }
}
#endif
