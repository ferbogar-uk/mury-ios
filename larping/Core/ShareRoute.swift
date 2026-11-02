import CoreLocation

/// Distance excludes segment gaps. Invalid samples split a segment instead of bridging missing data.
struct ShareRoute {
    let segments: [[CLLocationCoordinate2D]]
    let totalDistance: Double
    private let edgeLengths: [[Double]]

    init(segments source: [[CLLocationCoordinate2D]]) {
        var valid: [[CLLocationCoordinate2D]] = []
        for segment in source {
            var run: [CLLocationCoordinate2D] = []
            for point in segment {
                guard point.latitude.isFinite, point.longitude.isFinite,
                      CLLocationCoordinate2DIsValid(point) else {
                    if !run.isEmpty { valid.append(run); run = [] }
                    continue
                }
                if let last = run.last, last.latitude == point.latitude, last.longitude == point.longitude { continue }
                run.append(point)
            }
            if !run.isEmpty { valid.append(run) }
        }
        self.segments = valid
        edgeLengths = valid.map { segment in
            zip(segment, segment.dropFirst()).map { start, end in
                CLLocation(latitude: start.latitude, longitude: start.longitude)
                    .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
            }
        }
        totalDistance = edgeLengths.reduce(0) { $0 + $1.reduce(0, +) }
    }

    func revealedSegments(at progress: Double) -> [[CLLocationCoordinate2D]] {
        guard totalDistance > 0 else { return segments }
        let fraction = progress.isNaN ? 0 : min(1, max(0, progress))
        if fraction >= 1 { return segments }
        var remaining = totalDistance * fraction
        var revealed: [[CLLocationCoordinate2D]] = []
        for (index, segment) in segments.enumerated() {
            var visible = [segment[0]]
            for (edge, length) in edgeLengths[index].enumerated() {
                if remaining >= length {
                    visible.append(segment[edge + 1])
                    remaining -= length
                } else {
                    if remaining > 0 {
                        let start = segment[edge], end = segment[edge + 1]
                        let t = remaining / length
                        // Interpolate the shortest longitude arc across the date line.
                        var longitudeDelta = end.longitude - start.longitude
                        if longitudeDelta > 180 { longitudeDelta -= 360 }
                        if longitudeDelta < -180 { longitudeDelta += 360 }
                        let longitude = start.longitude + longitudeDelta * t
                        visible.append(.init(latitude: start.latitude + (end.latitude - start.latitude) * t,
                                             longitude: longitude > 180 ? longitude - 360 : (longitude < -180 ? longitude + 360 : longitude)))
                    }
                    revealed.append(visible)
                    return revealed
                }
            }
            revealed.append(visible)
            if remaining <= 0 { return revealed }
        }
        return revealed
    }
}
