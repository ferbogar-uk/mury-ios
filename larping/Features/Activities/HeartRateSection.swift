import Charts
import SwiftData
import SwiftUI

/// Heart-rate graph and time in zones for the activity detail. It shows
/// nothing when the activity has too few heart-rate readings to draw.
///
/// The zones use the highest heart rate recorded in any real activity, so
/// there is nothing to set up. The arithmetic lives in `HeartRateZones.swift`.
struct HeartRateSection: View {
    @Environment(\.brandTheme) private var theme
    @Query private var allActivities: [CDActivity]

    let activity: CDActivity

    @State private var model: HeartRateModel?
    @State private var selectedMinute: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let model {
                graphCard(model)
                zonesCard(model)
            }
        }
        // Building the model reads every activity's heart rates, so it runs once
        // when the screen appears and not on every touch of the graph.
        .task(id: activity.id) {
            model = makeModel()
        }
    }

    private func makeModel() -> HeartRateModel? {
        let samples = activity.trackPoints.compactMap { point -> HeartRateSample? in
            guard let bpm = point.heartRateBpm, bpm > 0 else { return nil }
            return HeartRateSample(timestamp: point.timestamp, bpm: bpm)
        }
        return HeartRateModel(
            samples: samples,
            origin: activity.startedAt,
            measuredMax: HeartRateZones.measuredMaxBpm(in: allActivities.map(\.statsEntry)),
            ownMax: activity.maxHeartRateBpm
        )
    }

    private func selectedPoint(in model: HeartRateModel) -> HeartRatePoint? {
        selectedMinute.flatMap { HeartRateSeries.nearest(to: $0 * 60, in: model.points) }
    }

    // MARK: graph

    private func graphCard(_ model: HeartRateModel) -> some View {
        let selected = selectedPoint(in: model)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heart rate")
                    .font(MuryTypography.font(.headline, size: 17, weight: .bold))
                Spacer()
                Text(headerText(model, selected: selected))
                    .font(MuryTypography.font(.caption, size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(HeartRateZone.allCases) { zone in
                    if let band = model.band(for: zone) {
                        RectangleMark(
                            xStart: .value("Start", 0.0),
                            xEnd: .value("End", model.totalMinutes),
                            yStart: .value("From", band.lowerBound),
                            yEnd: .value("To", band.upperBound)
                        )
                        .foregroundStyle(zone.color.opacity(0.22))
                    }
                }
                ForEach(model.points) { point in
                    LineMark(
                        x: .value("Minute", point.seconds / 60),
                        y: .value("bpm", point.bpm)
                    )
                    .foregroundStyle(theme.ink)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
                if let selected {
                    RuleMark(x: .value("Minute", selected.seconds / 60))
                        .foregroundStyle(theme.ink.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    PointMark(
                        x: .value("Minute", selected.seconds / 60),
                        y: .value("bpm", selected.bpm)
                    )
                    .symbolSize(70)
                    .foregroundStyle(theme.ink)
                }
            }
            .chartXScale(domain: 0...model.totalMinutes)
            .chartYScale(domain: model.yRange)
            .chartXSelection(value: $selectedMinute)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text("\(Int(minutes))")
                        }
                    }
                }
            }
            .chartXAxisLabel("min", alignment: .trailing)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
            }
            .frame(height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Heart rate graph")
            .accessibilityValue("Average \(model.averageBpm), highest \(model.peakBpm) beats per minute")
            .accessibilityIdentifier("activity-heart-rate-chart")

            Text("Drag across the graph to read any moment.")
                .font(MuryTypography.font(.caption2, size: 11))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func headerText(_ model: HeartRateModel, selected: HeartRatePoint?) -> String {
        if let selected {
            return "\(Formatters.duration(seconds: Int(selected.seconds))) · \(Int(selected.bpm.rounded())) bpm"
        }
        return "Avg \(model.averageBpm) · Max \(model.peakBpm) bpm"
    }

    // MARK: zones

    private func zonesCard(_ model: HeartRateModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Time in zones")
                .font(MuryTypography.font(.headline, size: 17, weight: .bold))

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(model.durations.filter { $0.seconds > 0 }) { duration in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(duration.zone.color)
                            .frame(width: max(3, geo.size.width * duration.fraction))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                ForEach(model.durations) { duration in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(duration.zone.color)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(duration.zone.shortName) \(duration.zone.name)")
                                .font(MuryTypography.font(.subheadline, size: 14, weight: .semibold))
                            Text(model.zones.rangeText(of: duration.zone))
                                .font(MuryTypography.font(.caption2, size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Formatters.duration(seconds: duration.seconds))
                            .font(MuryTypography.font(.subheadline, size: 14).monospacedDigit())
                        Text("\(Int((duration.fraction * 100).rounded()))%")
                            .font(MuryTypography.font(.subheadline, size: 14, weight: .semibold).monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Divider()

            Text(model.usesMeasuredMax
                ? "Zones use your highest recorded heart rate, \(model.zones.maxBpm) bpm."
                : "Zones use this activity's highest heart rate, \(model.zones.maxBpm) bpm.")
                .font(MuryTypography.font(.caption2, size: 11))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("activity-heart-rate-zones")
    }
}

/// Everything the section draws, worked out once from the readings.
private struct HeartRateModel {
    let zones: HeartRateZones
    let points: [HeartRatePoint]
    let durations: [ZoneDuration]
    let averageBpm: Int
    let peakBpm: Int
    /// False when no real activity has a reading and the zones fall back to this
    /// activity's own highest value.
    let usesMeasuredMax: Bool
    let yRange: ClosedRange<Double>
    let totalMinutes: Double

    /// A few readings do not make a graph worth showing.
    static let minimumSamples = 10

    init?(samples: [HeartRateSample], origin: Date, measuredMax: Int?, ownMax: Int?) {
        guard samples.count >= Self.minimumSamples,
              let zones = HeartRateZones(maxBpm: measuredMax ?? ownMax) else { return nil }
        let points = HeartRateSeries.points(from: samples, origin: origin)
        guard let last = points.last else { return nil }

        let bpms = samples.map(\.bpm)
        let lowest = bpms.min() ?? 0
        let peak = bpms.max() ?? 0
        let low = max(0, ((lowest - 5) / 10) * 10)
        let high = ((max(peak, zones.lowerEdge(of: .z5)) + 5 + 9) / 10) * 10

        self.zones = zones
        self.points = points
        self.durations = zones.timeInZones(samples)
        self.averageBpm = bpms.reduce(0, +) / bpms.count
        self.peakBpm = peak
        self.usesMeasuredMax = measuredMax != nil
        self.yRange = Double(low)...Double(max(high, low + 10))
        self.totalMinutes = max(last.seconds / 60, 1)
    }

    /// The part of the graph a zone covers, cut to what the graph shows.
    func band(for zone: HeartRateZone) -> ClosedRange<Double>? {
        let lower = zone == .z1 ? yRange.lowerBound : Double(zones.lowerEdge(of: zone))
        let upper: Double
        if let next = HeartRateZone(rawValue: zone.rawValue + 1) {
            upper = Double(zones.lowerEdge(of: next))
        } else {
            upper = yRange.upperBound
        }
        let clampedLower = max(lower, yRange.lowerBound)
        let clampedUpper = min(upper, yRange.upperBound)
        return clampedLower < clampedUpper ? clampedLower...clampedUpper : nil
    }
}

private extension HeartRateZone {
    var color: Color {
        switch self {
        case .z1: return Color(red: 0xA7 / 255, green: 0xD8 / 255, blue: 0xF3 / 255)
        case .z2: return Color(red: 0x6B / 255, green: 0xB3 / 255, blue: 0xD1 / 255)
        case .z3: return Color(red: 0xE3 / 255, green: 0xB3 / 255, blue: 0x41 / 255)
        case .z4: return Color(red: 0xE0 / 255, green: 0x70 / 255, blue: 0x2F / 255)
        case .z5: return Color(red: 0xB2 / 255, green: 0x0E / 255, blue: 0x1C / 255)
        }
    }
}
