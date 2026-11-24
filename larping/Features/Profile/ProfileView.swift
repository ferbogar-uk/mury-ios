import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ActivitiesStore.self) private var activitiesStore
    @Environment(\.brandTheme) private var theme
    @AppStorage("displayName") private var displayName = "MURY User"
    @AppStorage("bio") private var bio = "Chasing routes, one recording at a time."
    @AppStorage("lastBackupDate") private var lastBackupDate = ""
    @State private var showEdit = false
    @State private var exportDocument: BackupFile?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImportURL: URL?
    @State private var confirmImport = false
    @State private var backupMessage: String?
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var userProfile = ProfileStorage.load()
    @State private var showBody = false

    private var entries: [StatsEntry] {
        activitiesStore.activities.map {
            StatsEntry(
                startedAt: $0.startedAt, sport: $0.sportType,
                distanceMeters: $0.distanceMeters, durationSeconds: $0.durationSeconds,
                maxHeartRateBpm: $0.maxHeartRateBpm, source: $0.source
            )
        }
    }

    var body: some View {
        let summary = StatsSummary(entries: entries, now: Date(), calendar: Calendar.current)
        let backup = ProfileSummary.backupState(
            lastBackup: ISO8601DateFormatter.parse(lastBackupDate), now: Date(), calendar: Calendar.current)
        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    totals(summary)
                    bodyCard
                    dataCard(backup)
                    NavigationLink {
                        SettingsView()
                    } label: {
                        ProfileRowLabel(icon: "gearshape", title: "Settings", subtitle: nil, trailing: .chevron)
                    }
                    .buttonStyle(PressableStyle())
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityIdentifier("profile-settings")

                    NavigationLink {
                        MapTestView()
                    } label: {
                        ProfileRowLabel(icon: "map", title: "Map test", subtitle: "Apple and Mapbox side by side", trailing: .chevron)
                    }
                    .buttonStyle(PressableStyle())
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityIdentifier("profile-map-test")

                    Text("MURY v\(appVersion) (\(appBuild))")
                        .font(MuryTypography.font(.caption2, size: 11, weight: .regular))
                        .foregroundStyle(theme.muted)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(theme.canvas)
            .toolbarBackground(theme.navigation, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { userProfile = ProfileStorage.load() }
            .sheet(isPresented: $showEdit) {
                EditProfileView(displayName: displayName, bio: bio) { name, newBio in
                    displayName = name
                    bio = newBio
                }
            }
            .sheet(isPresented: $showBody, onDismiss: { userProfile = ProfileStorage.load() }) {
                EditBodyView()
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: backupFilename
            ) { result in
                switch result {
                case .success:
                    backupMessage = nil
                    markBackupMade()
                case .failure(let error):
                    backupMessage = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    pendingImportURL = url
                    confirmImport = true
                case .failure:
                    break
                }
            }
            .confirmationDialog("Import backup?", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("Import") { performImport() }
                Button("Cancel", role: .cancel) { pendingImportURL = nil }
            } message: {
                Text("Only new activities will be added. Nothing existing is overwritten or deleted.")
            }
            .alert(isPresented: Binding(
                get: { backupMessage != nil },
                set: { if !$0 { backupMessage = nil } }
            )) {
                Alert(
                    title: Text(backupMessage?.contains("imported") == true ? "Import" : "Backup"),
                    message: Text(backupMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 14) {
            Text(ProfileSummary.initials(from: displayName))
                .font(MuryTypography.font(.title2, size: 22, weight: .semibold))
                .foregroundStyle(theme.canvas)
                .frame(width: 64, height: 64)
                .background(theme.ink, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(MuryTypography.font(.title2, size: 22, weight: .bold))
                    .foregroundStyle(theme.ink)
                if !bio.isEmpty {
                    Text(bio)
                        .font(MuryTypography.font(.footnote, size: 13))
                        .foregroundStyle(theme.muted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit") { showEdit = true }
                .font(MuryTypography.font(.subheadline, size: 14, weight: .semibold))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(theme.surface, in: Capsule())
                .overlay(Capsule().stroke(theme.border.opacity(0.5), lineWidth: 1))
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Edit profile")
        }
        .padding(.top, 4)
    }

    private func totals(_ summary: StatsSummary) -> some View {
        HStack(spacing: 0) {
            ProfileTotal(value: "\(summary.allTimeCount)", label: "Activities")
            Divider().frame(height: 36)
            ProfileTotal(value: ProfileSummary.totalDistance(meters: summary.allTimeDistance), label: "Distance")
            Divider().frame(height: 36)
            ProfileTotal(value: ProfileSummary.totalTime(seconds: summary.allTimeDuration), label: "Time")
        }
        .padding(.vertical, 14)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile-totals")
    }

    @ViewBuilder
    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProfileSectionTitle("Body")
            Button { showBody = true } label: {
                HStack {
                    if userProfile.heightCm == nil && userProfile.weightKg == nil && userProfile.age(now: Date()) == nil {
                        Text("Add your details")
                            .font(MuryTypography.font(.body, size: 16))
                            .foregroundStyle(theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ProfileFigure(label: "Height", value: userProfile.heightCm.map { "\(Int($0.value.rounded())) cm" } ?? "–")
                        ProfileFigure(label: "Weight", value: userProfile.weightKg.map { Self.kg($0.value) } ?? "–")
                        ProfileFigure(label: "Age", value: userProfile.age(now: Date()).map(String.init) ?? "–")
                    }
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(theme.muted).accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 64)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("profile-body")
        }
    }

    private static func kg(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value)) kg" : String(format: "%.1f kg", value)
    }

    private func dataCard(_ backup: ProfileSummary.BackupState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProfileSectionTitle("Your data")
            VStack(spacing: 0) {
                if HealthKitService.isAvailable {
                    Button {
                        Task {
                            isSyncing = true
                            await HealthKitService.requestAuthorization()
                            let result = await HealthSync.run(store: activitiesStore)
                            syncMessage = result.imported == 0
                                ? "Nothing new to import (\(result.skipped) already in MURY)."
                                : "Imported \(result.imported), skipped \(result.skipped)."
                            isSyncing = false
                        }
                    } label: {
                        ProfileRowLabel(
                            icon: "heart", title: "Sync Health now",
                            subtitle: syncMessage ?? "Reads the last 90 days and adds new workouts",
                            trailing: isSyncing ? .progress : .icon("arrow.triangle.2.circlepath"))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(isSyncing)
                    .accessibilityIdentifier("profile-sync-health")
                    Divider().padding(.leading, 52)
                }
                Button { exportBackup() } label: {
                    ProfileRowLabel(icon: "square.and.arrow.up", title: "Export all activities",
                                    subtitle: nil, trailing: .chevron, status: backupStatus(backup))
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("profile-export")
                Divider().padding(.leading, 52)
                Button { showImporter = true } label: {
                    ProfileRowLabel(icon: "square.and.arrow.down", title: "Import backup", subtitle: nil, trailing: .chevron)
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("profile-import")
            }
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 20))
            Text("Backups are a JSON file. Save it to iCloud Drive or Files to keep your data across devices and reinstalls.")
                .font(MuryTypography.font(.caption, size: 12))
                .foregroundStyle(theme.muted)
                .padding(.horizontal, 6)
        }
    }

    private func backupStatus(_ state: ProfileSummary.BackupState) -> ProfileRowLabel.Status {
        switch state {
        case .never: return .warning("No backup yet")
        case .stale(let date): return .warning("Last backup \(Formatters.displayDate(date: date)), time for a new one")
        case .recent(let date): return .info("Last backup \(Formatters.displayDate(date: date))")
        }
    }

    private var backupFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "larping-backup-\(formatter.string(from: Date()))"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func exportBackup() {
        backupMessage = nil
        do {
            exportDocument = try BackupService.backupFile(from: modelContext)
            showExporter = true
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func markBackupMade() {
        lastBackupDate = ISO8601DateFormatter().string(from: Date())
    }

    private func performImport() {
        defer { pendingImportURL = nil }
        guard let pendingImportURL else { return }
        guard pendingImportURL.startAccessingSecurityScopedResource() else {
            backupMessage = "Couldn't access the selected file."
            return
        }
        defer { pendingImportURL.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: pendingImportURL)
            let (imported, skipped) = try BackupService.restore(from: data, into: modelContext)
            activitiesStore.refresh()
            markBackupMade()
            backupMessage = skipped > 0
                ? "Imported \(imported) activities. Skipped \(skipped) already present."
                : imported == 1 ? "Imported 1 activity." : "Imported \(imported) activities."
        } catch {
            backupMessage = error.localizedDescription
        }
    }
}

private struct EditProfileView: View {
    let displayName: String
    let bio: String
    let onSaved: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var bioText: String

    init(displayName: String, bio: String, onSaved: @escaping (String, String) -> Void) {
        self.displayName = displayName
        self.bio = bio
        self.onSaved = onSaved
        _name = State(initialValue: displayName)
        _bioText = State(initialValue: bio)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display name", text: $name)
                    TextField("Bio", text: $bioText, axis: .vertical)
                }
            }
            .navigationTitle("Edit profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSaved(name, bioText)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Pieces

private struct ProfileSectionTitle: View {
    @Environment(\.brandTheme) private var theme
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(MuryTypography.font(.caption, size: 12, weight: .semibold))
            .foregroundStyle(theme.muted)
            .padding(.horizontal, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ProfileTotal: View {
    @Environment(\.brandTheme) private var theme
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(MuryTypography.font(.title3, size: 20, weight: .bold))
                .foregroundStyle(theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(MuryTypography.font(.caption, size: 12))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileFigure: View {
    @Environment(\.brandTheme) private var theme
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(MuryTypography.font(.caption, size: 12))
                .foregroundStyle(theme.muted)
            Text(value)
                .font(MuryTypography.font(.body, size: 16, weight: .semibold))
                .foregroundStyle(theme.ink)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One tappable row: accent icon, title, optional subtitle or status line, trailing chevron, icon or spinner.
private struct ProfileRowLabel: View {
    enum Trailing { case chevron, progress, icon(String) }
    enum Status { case info(String), warning(String) }

    @Environment(\.brandTheme) private var theme
    let icon: String
    let title: String
    let subtitle: String?
    let trailing: Trailing
    var status: Status?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(theme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MuryTypography.font(.body, size: 16))
                    .foregroundStyle(theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(MuryTypography.font(.caption, size: 12))
                        .foregroundStyle(theme.muted)
                        .multilineTextAlignment(.leading)
                }
                if let status {
                    switch status {
                    case .info(let text):
                        Text(text).font(MuryTypography.font(.caption, size: 12)).foregroundStyle(theme.muted)
                    case .warning(let text):
                        Text(text).font(MuryTypography.font(.caption, size: 12, weight: .semibold)).foregroundStyle(theme.accent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            switch trailing {
            case .chevron: Image(systemName: "chevron.right").font(.footnote).foregroundStyle(theme.muted).accessibilityHidden(true)
            case .progress: ProgressView()
            case .icon(let name): Image(systemName: name).font(.footnote).foregroundStyle(theme.muted).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// Height, weight, birth date and sex in the same form as first launch; Save writes the stored profile.
private struct EditBodyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandTheme) private var theme
    @State private var profile = ProfileStorage.load()

    var body: some View {
        NavigationStack {
            ScrollView {
                ProfileFormView(profile: $profile)
                    .padding(16)
            }
            .background(theme.canvas)
            .navigationTitle("Body")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ProfileStorage.save(profile)
                        dismiss()
                    }
                    .accessibilityIdentifier("profile-body-save")
                }
            }
        }
    }
}
