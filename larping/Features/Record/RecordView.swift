import MapKit
import SwiftUI

struct RecordView: View {
    @Environment(ActivitiesStore.self) private var activitiesStore
    @Environment(\.brandTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LocationTracker.self) private var tracker
    @State private var selectedSport: SportType = .run
    @State private var eventName = ""
    @FocusState private var isEditingEventName: Bool
    let initialSport: SportType
    let requestID: UUID?
    @State private var requests = RecordSportRequestState()
    @State private var didInitializeName = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showSavedConfirmation = false
    @State private var saveErrorMessage: String?
    @State private var savedDistance: Double = 0

    init(initialSport: SportType = .run, requestID: UUID? = nil) {
        self.initialSport = initialSport
        self.requestID = requestID
        _selectedSport = State(initialValue: initialSport)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    // History heatmap: every past route stacked at low opacity —
                    // overlapping segments blend brighter, giving a "heat" build-up
                    // without a real spatial-binning pass. Bounded to the 500 most
                    // recent (activities sorted newest-first); the full list still
                    // feeds Stats' all-time totals.
                    ForEach(activitiesStore.activities.prefix(500)) { pastActivity in
                        let points = activitiesStore.coordinates(for: pastActivity)
                        if points.count > 1 {
                            MapPolyline(coordinates: points)
                                .stroke(theme.route.opacity(0.12), lineWidth: 3)
                        }
                    }

                    if tracker.routeCoordinates.count > 1 {
                        MapPolyline(coordinates: tracker.routeCoordinates)
                            .stroke(theme.routeCasing, lineWidth: 9)
                        MapPolyline(coordinates: tracker.routeCoordinates)
                            .stroke(theme.route, lineWidth: 5)
                    }

                    if let tip = tracker.routeCoordinates.last, tracker.state != .idle {
                        Annotation("", coordinate: tip) {
                            Image(systemName: selectedSport.symbolName)
                                .font(.subheadline.bold())
                                .foregroundStyle(theme.routeCasing)
                                .padding(7)
                                .background(theme.route, in: Circle())
                                .overlay { Circle().stroke(theme.routeCasing, lineWidth: 2) }
                                .accessibilityLabel("Current recording position")
                                .symbolEffect(.bounce, options: .repeating, isActive: tracker.state == .recording)
                        }
                    } else {
                        UserAnnotation()
                    }
                }
                .ignoresSafeArea(edges: .top)
                .onChange(of: tracker.routeCoordinates.last?.latitude) {
                    guard tracker.state == .recording else { return }
                    cameraPosition = .userLocation(fallback: .automatic)
                }

                controls
                    .padding()
                    .background(colorScheme == .dark ? AnyShapeStyle(Color.black.opacity(0.75)) : AnyShapeStyle(.thinMaterial))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.navigation, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        cameraPosition = .userLocation(fallback: .automatic)
                    } label: {
                        Image(systemName: "location.fill")
                    }
                }
            }
            .task { tracker.requestPermission() }
            .onChange(of: tracker.elapsedSeconds) { sendMirror() }
            .onChange(of: tracker.state) { sendMirror() }
            .onChange(of: tracker.distanceMeters) { sendMirror() }
            .onChange(of: selectedSport) {
                eventName = suggestedEventName(for: selectedSport)
            }
            .onAppear {
                if !didInitializeName {
                    eventName = suggestedEventName(for: selectedSport)
                    didInitializeName = true
                }
                consumeSportRequest()
            }
            .onChange(of: initialSport) { consumeSportRequest() }
            .onChange(of: requestID) { consumeSportRequest() }
            .alert("Activity saved", isPresented: $showSavedConfirmation) {
                Button("Done", role: .cancel) {}
            } message: {
                Text("\(Formatters.distance(meters: savedDistance)) recorded. \nYou can view or delete it from the Activities tab.")
            }
            .alert("Couldn't save activity", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            if tracker.state == .idle {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(SportType.allCases) { sport in
                                Button {
                                    selectedSport = sport
                                } label: {
                                    Label(sport.label, systemImage: sport.symbolName)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedSport.symbolName)
                                Text(selectedSport.label)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityIdentifier("record-sport")

                        TextField("Event name", text: $eventName)
                        .focused($isEditingEventName)
                        .submitLabel(.done)
                        .onSubmit { isEditingEventName = false }
                        .accessibilityIdentifier("record-event-name")
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                    }

                    if eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Event name is required to start.")
                            .font(MuryTypography.font(.caption, size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Label(selectedSport.label, systemImage: selectedSport.symbolName)
                        .font(.headline)
                        .foregroundStyle(tracker.state == .paused ? AnyShapeStyle(.secondary) : AnyShapeStyle(theme.tint))
                        .symbolEffect(.bounce, options: .repeating, isActive: tracker.state == .recording)
                    if tracker.state == .paused {
                        Text("PAUSED")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.error, in: Capsule())
                    }
                    Spacer()
                    Text(eventName.isEmpty ? "MURY \(selectedSport.label)" : eventName)
                        .font(MuryTypography.font(.headline, size: 17, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            HStack(spacing: 32) {
                StatColumn(title: "Time", value: Formatters.duration(seconds: tracker.elapsedSeconds))
                StatColumn(title: "Distance", value: Formatters.distance(meters: tracker.distanceMeters))
                StatColumn(
                    title: selectedSport.usesPaceMetric ? "Pace" : "Speed",
                    value: selectedSport.usesPaceMetric
                        ? Formatters.paceFromSpeed(metersPerSecond: tracker.currentSpeedMps)
                        : Formatters.speed(metersPerSecond: tracker.currentSpeedMps)
                )
            }

            if tracker.state == .recording, tracker.isGPSDegraded {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("GPS signal weak — recording may be less accurate")
                }
                .font(.caption)
                .foregroundStyle(.warning)
            }

            switch tracker.state {
            case .idle:
                Button {
                    startRecording()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(theme.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.large)
                .disabled(
                    tracker.authorizationStatus == .denied || tracker.authorizationStatus == .restricted
                        || eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

            case .recording:
                HStack(spacing: 16) {
                    Button {
                        tracker.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        finishRecording()
                    } label: {
                        Label("Finish", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

            case .paused:
                HStack(spacing: 16) {
                    Button {
                        tracker.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        finishRecording()
                    } label: {
                        Label("Finish", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            if tracker.authorizationStatus == .denied || tracker.authorizationStatus == .restricted {
                Text("Location access is off. Enable it in Settings to record a route.")
                    .font(MuryTypography.font(.footnote, size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if tracker.authorizationStatus == .notDetermined {
                Text("Allow location access to see your route on the map.")
                    .font(MuryTypography.font(.footnote, size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    private func consumeSportRequest() {
        if let sport = requests.consume(sport: initialSport, requestID: requestID, isIdle: tracker.state == .idle) {
            selectedSport = sport
        }
    }

    private func startRecording() {
        tracker.start()
        cameraPosition = .userLocation(fallback: .automatic)
    }

    private func finishRecording() {
        let recording = tracker.stop()
        savedDistance = recording.distanceMeters
        let title = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let activity = try activitiesStore.create(
                sportType: selectedSport,
                startedAt: recording.startedAt,
                endedAt: recording.endedAt,
                durationSeconds: recording.durationSeconds > 0 ? recording.durationSeconds : nil,
                distanceMeters: Int(recording.distanceMeters),
                elevationGainMeters: recording.elevationGainMeters > 0 ? Int(recording.elevationGainMeters) : nil,
                averageSpeedMps: averageSpeedMps(recording),
                maxSpeedMps: recording.maxSpeedMps > 0 ? recording.maxSpeedMps : nil,
                source: "mobile",
                eventName: title.isEmpty ? suggestedEventName(for: selectedSport) : title,
                trackPointsPayloads: recording.trackPoints
            )
            showSavedConfirmation = true
            eventName = suggestedEventName(for: selectedSport)
            Task { await HealthKitService.saveWorkout(from: activity) }
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    /// Tells the watch what the recorder is doing. Never affects the recording.
    private func sendMirror() {
        let state: MirrorSnapshot.State
        switch tracker.state {
        case .idle: state = .idle
        case .recording: state = .recording
        case .paused: state = .paused
        }
        WatchMirror.shared.send(MirrorSnapshot(
            state: state,
            elapsedSeconds: tracker.elapsedSeconds,
            distanceMeters: tracker.distanceMeters,
            speedMetersPerSecond: tracker.currentSpeedMps,
            sportLabel: selectedSport.label,
            usesPace: selectedSport.usesPaceMetric
        ))
    }

    private func suggestedEventName(for sport: SportType) -> String {
        EventNamer.nextName(base: "MURY \(sport.label)", existing: activitiesStore.activities.compactMap(\.eventName))
    }

    private func averageSpeedMps(_ recording: LocationTracker.Recording) -> Double? {
        let duration = recording.activeDurationSeconds
        guard duration > 0.5 else { return nil }
        return recording.distanceMeters / duration
    }
}

private struct StatColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(MuryTypography.font(.title3, size: 20, weight: .bold).monospacedDigit())
            Text(title.uppercased()).font(MuryTypography.font(.caption2, size: 11, weight: .regular)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Consume active/paused requests too, so they cannot change sport after Finish.
struct RecordSportRequestState {
    private var consumedSport: SportType?
    private var consumedRequestID: UUID?

    mutating func consume(sport: SportType, requestID: UUID?, isIdle: Bool) -> SportType? {
        guard consumedSport != sport || consumedRequestID != requestID else { return nil }
        consumedSport = sport
        consumedRequestID = requestID
        return isIdle ? sport : nil
    }
}
