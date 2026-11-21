import CoreLocation
import HealthKit
import SwiftUI

/// Imports a workout recorded on Apple Watch / iPhone into Larping's local
/// store (route + heart rate where available). SwiftData stays authoritative;
/// Health is only a source here. Mirrors `ImportGPXView`'s shape —
/// independent picker with a summary and a single Import action.
struct ImportHealthKitView: View {
    @Environment(\.brandTheme) private var theme
    @Environment(ActivitiesStore.self) private var activitiesStore
    @Environment(\.dismiss) private var dismiss

    @State private var workouts: [HKWorkout] = []
    @State private var selected: HKWorkout?
    @State private var sportType: SportType = .run
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var status: HKAuthorizationStatus = .notDetermined

    /// Health only reports write access. Once the permission sheet has been shown we just try to read:
    /// an empty list is what a denied read looks like.
    private var isAuthorized: Bool { status != .notDetermined }

    var body: some View {
        NavigationStack {
            Group {
                if !HealthKitService.isAvailable {
                    ContentUnavailableView(
                        "HealthKit unavailable",
                        systemImage: "heart.slash",
                        description: Text("This device doesn't support HealthKit.")
                    )
                } else if !isAuthorized {
                    authPrompt
                } else if workouts.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No Health workouts found",
                        systemImage: "figure.run",
                        description: Text("Workouts you record on Apple Watch or iPhone with the Workout app will appear here.")
                    )
                } else {
                    List {
                        Section("Recent Health workouts") {
                            if isLoading {
                                HStack { Spacer(); ProgressView(); Spacer() }
                            }
                            ForEach(workouts, id: \.uuid) { workout in
                                row(workout)
                            }
                        }

                        if let selected {
                            Section("Import as") {
                                Picker("Sport", selection: $sportType) {
                                    ForEach(SportType.allCases) { sport in
                                        SportLabel(sport.label, symbol: sport.symbolName).tag(sport)
                                    }
                                }
                            }
                            Section("Summary") {
                                LabeledContent("Date", value: Formatters.displayDate(date: selected.startDate))
                                LabeledContent("Duration", value: Formatters.duration(seconds: Int(selected.duration)))
                                LabeledContent(
                                    "Distance",
                                    value: Formatters.distance(meters: selected.totalDistance?.doubleValue(for: .meter()))
                                )
                            }
                        }

                        if let errorMessage {
                            Section { Text(errorMessage).foregroundStyle(.red) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle("Import from Health")
            .toolbar {
                if isAuthorized {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await importWorkout() }
                        } label: {
                            if isImporting { ProgressView() } else { Text("Import") }
                        }
                        .disabled(selected == nil || isImporting)
                    }
                }
            }
            .onAppear { refresh() }
        }
    }

    private var authPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(status == .sharingDenied
                 ? "Health access is off"
                 : "Import workouts from Health")
                .font(.headline)
            Text(status == .sharingDenied
                 ? "Enable it in Settings → Health → Data Access & Devices, then come back."
                 : "MURY reads your Health workouts, routes, and heart rate so you can import them here. You stay in control — nothing is uploaded anywhere.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                if status == .sharingDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    Task {
                        isLoading = true
                        await HealthKitService.requestAuthorization()
                        refresh()
                    }
                }
            } label: {
                if isLoading { ProgressView() } else {
                    Text(status == .sharingDenied ? "Open Settings" : "Allow HealthKit access")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }

    private func row(_ workout: HKWorkout) -> some View {
        Button {
            selected = workout
            sportType = SportType(workout: workout)
        } label: {
            HStack(spacing: 12) {
                SportSymbol(SportType(workout: workout).symbolName, size: 24)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SportType(workout: workout).label)
                        .font(.headline)
                    Text(Formatters.displayDate(date: workout.startDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Formatters.duration(seconds: Int(workout.duration)))
                        .font(.subheadline.monospacedDigit())
                    Text(Formatters.distance(meters: workout.totalDistance?.doubleValue(for: .meter())))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if selected?.uuid == workout.uuid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func refresh() {
        guard HealthKitService.isAvailable else { return }
        isLoading = true
        errorMessage = nil
        status = HealthKitService.shareStatus ?? .notDetermined
        guard status != .notDetermined else {
            isLoading = false
            return
        }
        Task {
            defer { isLoading = false }
            do {
                workouts = try await HealthKitService.fetchRecentWorkouts()
                if workouts.isEmpty {
                    selected = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importWorkout() async {
        guard let selected else { return }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }
        do {
            try await HealthSync.importOne(selected, sport: sportType, store: activitiesStore)
            dismiss()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
