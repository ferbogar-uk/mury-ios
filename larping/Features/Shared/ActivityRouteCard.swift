import MapKit
import SwiftUI

/// An activity as a card: its route on a still map (white casing under the brand red) and three headline
/// numbers. Activities without a route show a calm sport header instead of an empty map.
struct ActivityRouteCard: View {
    let activity: CDActivity
    var mapHeight: CGFloat = 150
    @Environment(\.brandTheme) private var theme

    private var title: String {
        let name = activity.eventName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? activity.sportType.label : name
    }

    /// At most ~300 points: enough for the shape, light enough for a list of cards.
    private var coordinates: [CLLocationCoordinate2D] {
        let points = activity.trackPoints.sorted { $0.timestamp < $1.timestamp }
        guard points.count > 1 else { return [] }
        let step = max(1, points.count / 300)
        var picked = stride(from: 0, to: points.count, by: step).map { points[$0] }
        if let last = points.last, picked.last !== last { picked.append(last) }
        return picked.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        let route = coordinates
        VStack(alignment: .leading, spacing: 0) {
            if route.count > 1 {
                Map(initialPosition: .automatic, interactionModes: []) {
                    MapPolyline(coordinates: route)
                        .stroke(theme.routeCasing, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    MapPolyline(coordinates: route)
                        .stroke(theme.route, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    if let start = route.first {
                        Annotation("", coordinate: start) {
                            Circle().fill(.white).frame(width: 11, height: 11)
                                .overlay(Circle().stroke(theme.ink, lineWidth: 2))
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .frame(height: mapHeight)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if route.count <= 1 {
                        Image(systemName: activity.sportType.symbolName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(MuryTypography.font(.headline, size: 17, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(activity.startedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(MuryTypography.font(.subheadline, size: 13))
                        .foregroundStyle(theme.muted)
                }
                HStack(alignment: .top) {
                    stat("Distance", Formatters.distance(meters: activity.distanceMeters.map(Double.init)))
                    Spacer()
                    stat("Time", Formatters.duration(seconds: activity.durationSeconds))
                    Spacer()
                    stat(activity.averageHeartRateBpm == nil ? activity.sportType.usesPaceMetric ? "Pace" : "Speed" : "Avg HR",
                         activity.averageHeartRateBpm.map { "\($0)" }
                            ?? Formatters.paceOrSpeed(sportType: activity.sportType,
                                                      averagePaceSecondsPerKm: activity.averagePaceSecondsPerKm,
                                                      averageSpeedMps: activity.averageSpeedMps))
                }
            }
            .padding(14)
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: theme.ink.opacity(0.06), radius: 1, y: 1)
        .shadow(color: theme.ink.opacity(0.07), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(MuryTypography.font(.caption, size: 12)).foregroundStyle(theme.muted)
            Text(value).font(MuryTypography.font(.headline, size: 18, weight: .semibold)).monospacedDigit()
        }
    }
}
