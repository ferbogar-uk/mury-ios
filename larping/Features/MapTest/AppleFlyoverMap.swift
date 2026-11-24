import MapKit
import SwiftUI

/// Apple's side of the comparison: the same hybrid 3D map the flyover uses, with the route as a red line.
struct AppleFlyoverMap: View {
    let route: [CLLocationCoordinate2D]
    let state: FlyoverPlan.State
    var marker: CLLocationCoordinate2D?
    var markerSymbolName: String = "figure.run"
    @Environment(\.brandTheme) private var theme

    var body: some View {
        Map(position: .constant(.camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: state.centerLatitude, longitude: state.centerLongitude),
            distance: state.distanceMeters, heading: state.headingDegrees, pitch: state.pitchDegrees))),
            interactionModes: []) {
            MapPolyline(coordinates: route)
                .stroke(theme.routeCasing, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: route)
                .stroke(theme.route, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            if let marker {
                Annotation("", coordinate: marker, anchor: .center) {
                    Image(systemName: markerSymbolName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(theme.route, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
    }
}
