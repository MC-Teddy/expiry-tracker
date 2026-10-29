#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
import ExpiryCore

private struct SharedFile: Identifiable { let id = UUID(); let url: URL }
private struct NativeShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @EnvironmentObject private var model: TrackerModel
    @State private var critical = 3
    @State private var soon = 14
    @State private var importing = false
    @State private var pendingImport: TrackerSnapshot?
    @State private var confirmImport = false
    @State private var shared: SharedFile?
    @State private var errorMessage: String?
    @State private var saved = false
    @State private var restoredCount: Int?
    @State private var loaded = false
    @State private var email = ""
    @State private var password = ""
    @State private var signingIn = false
    @State private var authError: String?
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "—") (\(info["CFBundleVersion"] as? String ?? "—"))"
    }
    private var thresholdsChanged: Bool {
        critical != model.snapshot.settings.criticalDays || soon != model.snapshot.settings.soonDays
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.isSignedIn {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "person.crop.circle.badge.checkmark").font(.title).foregroundStyle(Color.trackerAccent)
                                .frame(width: 48, height: 48).background(Color.trackerAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.accountEmail ?? "Signed in").font(.headline).textSelection(.enabled)
                                Text(model.syncing ? "Syncing…" : "Signed in").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 8)
                        LabeledContent("Last sync", value: model.lastSyncedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not yet")
                        if model.pendingChanges > 0 {
                            LabeledContent("Waiting to sync", value: "\(model.pendingChanges)")
                        }
                        if let syncMessage = model.syncMessage {
                            Text(syncMessage).font(.footnote).foregroundStyle(.red)
                        }
                        Button { Task { await model.syncNow() } } label: {
                            Label(model.syncing ? "Syncing…" : "Sync now", systemImage: "arrow.triangle.2.circlepath").frame(minHeight: 44)
                        }.disabled(model.syncing || !model.ready)
                        Button("Sign out", role: .destructive) { model.signOut() }.frame(minHeight: 44)
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "iphone").font(.title).foregroundStyle(Color.trackerAccent)
                                .frame(width: 48, height: 48).background(Color.trackerAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("On this iPhone").font(.headline)
                                Text("Sign in to share items and photos with the website.").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 8)
                        TextField("Email", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password).textContentType(.password)
                        if let authError {
                            Text(authError).font(.footnote).foregroundStyle(.red)
                        }
                        Button {
                            signingIn = true
                            authError = nil
                            Task {
                                let failure = await model.signIn(email: email, password: password)
                                signingIn = false
                                authError = failure
                                if failure == nil { password = "" }
                            }
                        } label: {
                            if signingIn { ProgressView().frame(minHeight: 44) }
                            else { Text("Sign in").frame(minHeight: 44) }
                        }.disabled(signingIn || !model.ready)
                    }
                } header: { Text("Account") } footer: {
                    Text(model.isSignedIn
                         ? "This account uses the same items and photos as the website. Edits made offline are sent when you're back online. If both sides changed the same detail, the newest change is kept. Warning days stay on this iPhone. Recognition runs on this iPhone with Apple Vision."
                         : "Without an account, items stay on this iPhone. Sign in with the same email and password as the website. Items already here are kept and uploaded. Recognition runs on this iPhone with Apple Vision.")
                }
                Section {
                    Stepper(value: $critical, in: 0...3650) {
                        LabeledContent { Text("\(critical) days").monospacedDigit() } label: { Label("Use first", systemImage: "clock.badge.exclamationmark") }
                    }
                        .onChange(of: critical) { _, value in soon = max(soon, value); saved = false }
                    Stepper(value: $soon, in: critical...3650) {
                        LabeledContent { Text("\(soon) days").monospacedDigit() } label: { Label("Expiring soon", systemImage: "calendar") }
                    }.onChange(of: soon) { _, _ in saved = false }
                    Button {
                        if model.settings(TrackerSettings(soonDays: soon, criticalDays: critical)) { saved = true }
                        else { takeModelError() }
                    } label: {
                        Label(saved ? "Warning days saved" : "Save warning days", systemImage: saved ? "checkmark.circle" : "checkmark")
                            .frame(minHeight: 44)
                    }.disabled(!model.ready || !thresholdsChanged)
                } header: { Text("Expiry warnings") } footer: {
                    Text("Use first: today through \(critical) days. Expiring soon: after that through \(soon) days. Earlier dates are expired; later dates are fresh.")
                }
                Section {
                    Button { export(csv: false) } label: { settingsRow("Export backup", subtitle: "Items, photos, and settings", symbol: "arrow.up.doc", color: .blue) }
                    Button { importing = true } label: { settingsRow("Restore backup…", subtitle: "Replace inventory from a backup", symbol: "arrow.down.doc", color: .orange) }
                    Button { export(csv: true) } label: { settingsRow("Export spreadsheet", subtitle: "Item details as a CSV file", symbol: "tablecells", color: .green) }
                    if let count = restoredCount { Label("Restored \(count) items", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(.green) }
                } header: { Text("Your data") } footer: {
                    Text("Export a backup before deleting the app or changing phones. Restoring replaces your inventory after confirmation. A spreadsheet export excludes photos and settings and cannot be restored.")
                }.disabled(!model.ready)
                Section {
                    LabeledContent("Version", value: version)
                    LabeledContent("Recognition", value: "On-device · Free")
                } header: { Text("Expiry Tracker") }
            }
            .formStyle(.grouped).listSectionSpacing(20)
            .navigationTitle("Settings")
            .onAppear {
                guard !loaded else { return }
                critical = model.snapshot.settings.criticalDays; soon = model.snapshot.settings.soonDays; loaded = true
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    pendingImport = try model.validatedBackup(url)
                    confirmImport = true
                } catch {
                    pendingImport = nil
                    errorMessage = "Backup was not restored. Your current inventory is unchanged. \(ErrorExplanation.message(error))"
                }
            }
            .confirmationDialog("Replace all local data?", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("Replace inventory and settings", role: .destructive) {
                    guard let next = pendingImport else { return }
                    if model.replace(next) {
                        critical = next.settings.criticalDays; soon = next.settings.soonDays; saved = true; restoredCount = next.items.count
                    } else { takeModelError() }
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("This validated backup contains \(pendingImport?.items.count ?? 0) items. It will replace all current items, photos, and warning settings on this iPhone. If you are signed in, your account is updated to match it. This cannot be undone. Export a JSON backup first if you need to keep the current inventory.")
            }
            .sheet(item: $shared) { file in NativeShareSheet(url: file.url) }
            .alert("Unable to complete action", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
    private func settingsRow(_ title: String, subtitle: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            SettingsSymbol(name: symbol, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(minHeight: 52).accessibilityElement(children: .combine)
    }
    private func takeModelError() { errorMessage = model.errorMessage; model.errorMessage = nil }
    private func export(csv: Bool) {
        do { shared = SharedFile(url: try model.export(csv: csv)) }
        catch { errorMessage = "The export could not be prepared. \(ErrorExplanation.message(error))" }
    }
}
#endif
