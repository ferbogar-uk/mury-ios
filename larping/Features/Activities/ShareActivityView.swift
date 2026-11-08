import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private enum ShareTemplate: Int, CaseIterable, Identifiable {
    case classic, mapCard, video, column, compact, route, ticket, edge, receipt

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .mapCard: return "Map"
        case .video: return "Video"
        case .column: return "Statistics"
        case .compact: return "Chips"
        case .route: return "Route + stats"
        case .ticket: return "Ticket"
        case .edge: return "Edge"
        case .receipt: return "Receipt"
        }
    }

    var overlayLayout: ShareImageComposer.OverlayLayout? {
        switch self {
        case .column: return .column
        case .compact: return .compact
        case .route: return .route
        case .ticket: return .ticket
        case .edge: return .edge
        case .receipt: return .receipt
        default: return nil
        }
    }
    var id: Int { rawValue }
}

/// Exports the selected image template or an on-demand route video.
struct ShareActivityView: View {
    let activity: CDActivity
    let coordinates: [CLLocationCoordinate2D]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.brandTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var overlayImages: [ShareImageComposer.OverlayLayout: UIImage] = [:]
    @State private var selectedMetrics = Set(ShareImageComposer.OverlayMetric.allCases)
    @State private var copiedPNG = false
    @State private var photo: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var composedImage: UIImage?
    @State private var mapCardImage: UIImage?
    @State private var template: ShareTemplate = .classic
    @State private var videoURL: URL?
    @State private var isGeneratingVideo = false
    @State private var videoTask: Task<Void, Never>?
    @State private var exportDocument: ShareExportDocument?
    @State private var showExporter = false
    @State private var exportFilename = "MURY-activity"
    @State private var exportError: String?
    @State private var exportSucceeded = false

    private var renderKey: String { theme.rawValue + (colorScheme == .dark ? "-dark" : "-light") }
    private var imageComposer: ShareImageComposer { ShareImageComposer(style: theme.shareStyle(for: colorScheme)) }
    @State private var videoDuration: ShareVideoComposer.ClipDuration = .thirty
    @State private var videoProgress = 0.0
    @State private var generationID = UUID()
    @State private var sharedVideo: VideoShareFile?
    @State private var showFlyover = false
    private let replaySegments: [[CLLocationCoordinate2D]]

    init(activity: CDActivity, coordinates: [CLLocationCoordinate2D]) {
        self.activity = activity
        self.coordinates = coordinates
        let timeline = ReplayTimeline(points: activity.trackPoints.map {
            ReplayPoint(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude,
                        altitudeMeters: $0.altitudeMeters, speedMps: $0.speedMps)
        }, startedAt: activity.startedAt, endedAt: activity.endedAt)
        replaySegments = timeline.segments.map { segment in
            segment.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
    }

    @State private var videoError: String?
    @State private var fullPreview: UIImage?

    /// The user-typed event title wins; casing is preserved exactly as entered.
    /// Old/imported activities without one fall back to "MURY <Sport>".
    private var stats: ShareImageComposer.Stats {
        let pace = Formatters.paceOrSpeed(
            sportType: activity.sportType,
            averagePaceSecondsPerKm: activity.averagePaceSecondsPerKm,
            averageSpeedMps: activity.averageSpeedMps
        )
        return ShareImageComposer.Stats(
            symbolName: activity.sportType.symbolName,
            sportLabel: activity.sportType.label,
            distance: Formatters.distance(meters: activity.distanceMeters.map(Double.init)),
            duration: Formatters.duration(seconds: activity.durationSeconds),
            paceOrSpeed: pace,
            date: Formatters.displayDate(date: activity.startedAt),
            title: activity.eventName ?? "",
            usesPaceMetric: activity.sportType.usesPaceMetric,
            weekday: activity.startedAt.formatted(.dateTime.weekday(.wide))
        )
    }

    var body: some View {
        NavigationStack { exportContent }
    }

    private var sharingContent: some View {
        VStack(spacing: 14) {
            Picker("Template", selection: $template) {
                ForEach(ShareTemplate.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("share-template")

            TabView(selection: $template) {
                // One uniform ForEach, every page the same width: mixing fixed pages with a conditional ForEach
                // left the later pages stopping half-way across the screen.
                ForEach(ShareTemplate.allCases) { item in
                    templatePage(item)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(item)
                }
            }
            .tabViewStyle(.page)
            .frame(maxHeight: 640)

            if template.overlayLayout != nil {
                Menu {
                    ForEach(availableMetrics) { metric in
                        Toggle(metric.label, isOn: Binding(
                            get: { selectedMetrics.contains(metric.id) },
                            set: { selected in
                                if selected { selectedMetrics.insert(metric.id) }
                                else { selectedMetrics.remove(metric.id) }
                            }
                        ))
                        .accessibilityIdentifier("share-metric-\(metric.id.rawValue)")
                    }
                } label: {
                    Label("Metrics", systemImage: "slider.horizontal.3")
                }
                .disabled(availableMetrics.isEmpty)
                .accessibilityIdentifier("share-metrics")
                if template == .route && coordinates.count < 2 {
                    Text("No route recorded. Only available statistics are shown.")
                        .font(.footnote)
                }
            }

            if template == .video {
                videoDurationPicker
                if isGeneratingVideo { videoGenerationControls }
            }

            HStack {
                shareSection
                if template != .video {
                    Button(action: copyPNG) {
                        Label("Copy PNG", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedImage == nil)
                    .accessibilityIdentifier("share-copy-png")
                }
            }
            if copiedPNG {
                Text("PNG copied. Paste it over a photo in a compatible app.")
                    .font(.footnote)
                    .accessibilityIdentifier("share-copy-success")
            }

            Button(action: saveToFiles) {
                Label("Save to Files", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!isReadyToSave || showExporter)

            if exportSucceeded {
                Text("Saved to Files.")
                    .font(MuryTypography.font(.footnote, size: 13, weight: .regular))
            }

            if template == .classic {
                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        Label("Gallery", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if photo != nil {
                    Button(role: .destructive) {
                        photo = nil
                    } label: {
                        Label("Transparent background", systemImage: "xmark.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(theme.canvas)
        .toolbarBackground(theme.navigation, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var lifecycleContent: some View {
        sharingContent
        .task(id: renderKey) {
            clearExportFeedback()
            invalidateVideo()
            mapCardImage = nil
            recomposeClassic()
            recomposeOverlays()
            await recomposeMapCard()
        }
        .onChange(of: photo) {
            clearExportFeedback()
            recomposeClassic()
        }
        .onChange(of: template) {
            clearExportFeedback()
            recomposeOverlays()
        }
        .onChange(of: videoDuration) { invalidateVideo() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { invalidateVideo() }
        }
        .onChange(of: selectedMetrics) {
            clearExportFeedback()
            recomposeOverlays()
        }
        .onChange(of: photoPickerItem) {
            Task { await loadPickedPhoto() }
        }
        .onDisappear {
            invalidateVideo()
        }
    }

    private var previewContent: some View {
        lifecycleContent
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { photo = $0 }
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: Binding(
            get: { fullPreview != nil },
            set: { if !$0 { fullPreview = nil } }
        )) {
            if let fullPreview {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ScrollView {
                        Image(uiImage: fullPreview)
                            .resizable()
                            .scaledToFit()
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                self.fullPreview = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var exportContent: some View {
        previewContent
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: exportDocument?.contentType ?? .png,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                exportSucceeded = true
            case .failure(let error):
                let cocoaError = error as NSError
                if !(error is CancellationError),
                   !(cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError) {
                    exportError = error.localizedDescription
                }
            }
        }
        .alert("Couldn't prepare export", isPresented: exportErrorPresented) {
            if exportDocument != nil {
                Button("Try again") {
                    clearExportFeedback()
                    showExporter = true
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .sheet(item: $sharedVideo) { file in
            VideoShareSheet(file: file)
        }
        .fullScreenCover(isPresented: $showFlyover) {
            FlyoverView(activity: activity)
        }
        .alert("Couldn't create video", isPresented: videoErrorPresented) {
            Button("Retry") { startVideo() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(videoErrorMessage)
        }
    }

    private var exportErrorPresented: Binding<Bool> {
        Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
    }

    private var videoErrorPresented: Binding<Bool> {
        Binding(get: { videoError != nil }, set: { if !$0 { videoError = nil } })
    }

    private var videoErrorMessage: String {
        let guidance = String(localized: "Try again. If the problem continues, choose a shorter video or share a PNG.")
        return guidance + "\n" + (videoError ?? "")
    }

    private var videoDurationPicker: some View {
        Picker("Video duration", selection: $videoDuration) {
            ForEach(ShareVideoComposer.ClipDuration.allCases, id: \.rawValue) { (duration: ShareVideoComposer.ClipDuration) in
                Text("\(duration.rawValue) s").tag(duration)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("share-video-duration")
    }

    @ViewBuilder
    private var videoGenerationControls: some View {
        ProgressView(value: videoProgress) {
            Text("Creating video: \(Int(videoProgress * 100))%")
        }
        .accessibilityIdentifier("share-video-progress")
        Button("Cancel", action: invalidateVideo)
            .accessibilityIdentifier("share-video-cancel")
    }

    private var availableMetrics: [ShareImageComposer.OverlayValue] {
        ShareImageComposer.overlayMetrics(for: activity)
    }

    private var selectedImage: UIImage? {
        switch template {
        case .classic: return composedImage
        case .mapCard: return mapCardImage
        case .video: return nil
        case .column, .compact, .route, .ticket, .edge, .receipt:
            return template.overlayLayout.flatMap { overlayImages[$0] }
        }
    }

    @ViewBuilder
    private func templatePage(_ item: ShareTemplate) -> some View {
        switch item {
        case .classic: classicPreview
        case .mapCard: preview(mapCardImage)
        case .video: videoPreview
        default:
            if let layout = item.overlayLayout {
                transparentPreview(overlayImages[layout])
            } else {
                ProgressView()
            }
        }
    }

    private var classicPreview: some View {
        transparentPreview(composedImage, transparent: photo == nil)
    }

    @ViewBuilder
    private func transparentPreview(_ image: UIImage?, transparent: Bool = true) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background {
                    if transparent { TransparencyCheckerboard().accessibilityHidden(true) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .contentShape(RoundedRectangle(cornerRadius: 20))
                .accessibilityLabel("Activity sharing preview")
                .onTapGesture { fullPreview = image }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func preview(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .contentShape(RoundedRectangle(cornerRadius: 20))
                .onTapGesture { fullPreview = image }
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(.fill.tertiary)
                .aspectRatio(0.5625, contentMode: .fit)
                .overlay { ProgressView() }
        }
    }

    @ViewBuilder
    private var videoPreview: some View {
        if let videoURL {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .aspectRatio(0.5625, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        } else if let mapCardImage {
            preview(mapCardImage)
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(.fill.tertiary)
                .aspectRatio(0.5625, contentMode: .fit)
                .overlay { ProgressView() }
        }
    }

    /// Share (or, for the video template, the generate trigger) styled as the
    /// primary action. Camera/gallery sit below it so template swiping never
    /// shuffles the controls.
    @ViewBuilder
    private var shareSection: some View {
        switch template {
        case .classic, .mapCard, .column, .compact, .route, .ticket, .edge, .receipt:
            imageShareLink(selectedImage)
        case .video:
            VStack(spacing: 12) {
            if let videoURL {
                Button {
                    do { sharedVideo = try VideoShareFile(source: videoURL) }
                    catch { exportError = error.localizedDescription }
                } label: {
                    Label("Share video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(theme.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.large)
                .accessibilityIdentifier("share-video-share")
            } else {
                Button {
                    startVideo()
                } label: {
                    if isGeneratingVideo {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Generate video", systemImage: "film")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(theme.onAccent)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.large)
                .disabled(isGeneratingVideo)
                .accessibilityIdentifier("share-video-generate")
            }
            Button {
                showFlyover = true
            } label: {
                Text("3D Flyover Video")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(theme.accent)
            .controlSize(.large)
            .disabled(isGeneratingVideo || coordinates.count < 2)
            .accessibilityIdentifier("share-video-flyover")
            }
        }
    }

    @ViewBuilder
    private func imageShareLink(_ image: UIImage?) -> some View {
        if let image, let png = try? SharePNG(image: image) {
            ShareLink(item: png, preview: SharePreview("My MURY activity", image: Image(uiImage: image))) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(theme.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .controlSize(.large)
        } else {
            Button("Share") {}
                .disabled(true)
        }
    }

    private func copyPNG() {
        guard let selectedImage else { return }
        clearExportFeedback()
        do {
            try SharePNG(image: selectedImage).copyToPasteboard()
            copiedPNG = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func recomposeOverlays() {
        let metrics = availableMetrics.filter { selectedMetrics.contains($0.id) }
        overlayImages.removeAll()
        guard let layout = template.overlayLayout else { return }
        overlayImages[layout] = imageComposer.composeOverlay(layout: layout, coordinates: coordinates, stats: stats, metrics: metrics)
    }

    private var isReadyToSave: Bool {
        switch template {
        case .classic: return composedImage != nil
        case .mapCard: return mapCardImage != nil
        case .video: return videoURL != nil && !isGeneratingVideo
        case .column, .compact, .route, .ticket, .edge, .receipt: return selectedImage != nil
        }
    }

    private func clearExportFeedback() {
        copiedPNG = false
        exportError = nil
        exportSucceeded = false
    }

    private func saveToFiles() {
        clearExportFeedback()
        exportDocument = nil
        guard isReadyToSave else { return }
        do {
            let name: String
            switch template {
            case .classic:
                guard let composedImage else { return }
                exportDocument = try ShareExportDocument(image: composedImage)
                name = "classic"
            case .mapCard:
                guard let mapCardImage else { return }
                exportDocument = try ShareExportDocument(image: mapCardImage)
                name = "map"
            case .column, .compact, .route, .ticket, .edge, .receipt:
                guard let selectedImage else { return }
                exportDocument = try ShareExportDocument(image: selectedImage)
                name = "overlay-\(template.rawValue)"
            case .video:
                guard let videoURL else { return }
                exportDocument = try ShareExportDocument(videoURL: videoURL)
                name = "video"
            }
            exportFilename = "MURY-\(name)-\(activity.startedAt.formatted(.iso8601.year().month().day().dateSeparator(.dash)))"
            showExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func recomposeClassic() {
        composedImage = imageComposer.compose(
            photo: photo,
            coordinates: coordinates,
            stats: stats
        )
    }

    private func recomposeMapCard() async {
        let composer = imageComposer
        let snapshot = await composer.mapSnapshot(coordinates: coordinates)
        guard !Task.isCancelled else { return }
        mapCardImage = composer.composeMapCard(snapshot: snapshot, coordinates: coordinates, stats: stats, revealedSegments: replaySegments)
    }

    private func startVideo() {
        invalidateVideo()
        let id = generationID
        let duration = videoDuration
        isGeneratingVideo = true
        videoTask = Task { await generateVideo(id: id, duration: duration) }
    }

    private func invalidateVideo() {
        generationID = UUID()
        videoTask?.cancel()
        videoTask = nil
        isGeneratingVideo = false
        videoProgress = 0
        videoError = nil
        cleanupVideo()
    }

    private func generateVideo(id: UUID, duration: ShareVideoComposer.ClipDuration) async {
        defer {
            if generationID == id {
                isGeneratingVideo = false
                videoTask = nil
            }
        }
        do {
            let style = theme.shareStyle(for: colorScheme)
            let snapshot = await ShareImageComposer(style: style).mapSnapshot(coordinates: coordinates)
            try Task.checkCancellation()
            let url = try await ShareVideoComposer.composeVideo(
                snapshot: snapshot, coordinates: coordinates, stats: stats, style: style,
                duration: duration, segments: replaySegments, onProgress: { progress in
                    guard generationID == id else { return }
                    videoProgress = progress
                })
            if Task.isCancelled || generationID != id {
                try? FileManager.default.removeItem(at: url)
            } else {
                videoURL = url
            }
        } catch is CancellationError {
            // Cancellation belongs to the generation that was invalidated.
        } catch {
            if generationID == id && !Task.isCancelled { videoError = error.localizedDescription }
        }
    }

    private func cleanupVideo() {
        if let videoURL { try? FileManager.default.removeItem(at: videoURL) }
        videoURL = nil
    }

    private func loadPickedPhoto() async {
        guard let photoPickerItem,
              let data = try? await photoPickerItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photo = image
    }
}

private struct TransparencyCheckerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 16
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.28)))
            for row in 0..<Int(ceil(size.height / tile)) {
                for column in 0..<Int(ceil(size.width / tile)) where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(Color(white: 0.38)))
                }
            }
        }
    }
}

private struct VideoShareSheet: UIViewControllerRepresentable {
    let file: VideoShareFile
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        controller.completionWithItemsHandler = { [file] _, _, _, _ in
            // Retain the independent file through the consumer's completion callback.
            _ = file
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
