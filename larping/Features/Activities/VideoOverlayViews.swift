import SwiftUI

/// The red MURY logo used on every video, and how its 3D look is built: the logo is
/// stacked a few times, one point lower each time, in a darker red (the "side" of the
/// letters), with a soft shadow cast under the whole block. Live screens and the
/// in-app render share these numbers so all videos look the same.
enum VideoLogo {
    /// The red horizontal logo from the brand pack (the light variant of `LogoHorizontal`).
    static let image = UIImage(named: "LogoHorizontal", in: nil,
                               compatibleWith: UITraitCollection(userInterfaceStyle: .light))
    static let width: CGFloat = 200
    static let depthLayers = 5
    /// Darker red for the extruded side.
    static let depthColor = UIColor(red: 0.42, green: 0.03, blue: 0.07, alpha: 1)
    static let shadowColor = UIColor.black.withAlphaComponent(0.6)
    static let shadowBlur: CGFloat = 10
    static let shadowOffset = CGSize(width: 0, height: 7)
}

/// The red MURY logo across the top of a video with a 3D look. No band.
struct VideoLogoMark: View {
    var body: some View {
        if let logo = VideoLogo.image {
            ZStack {
                ForEach((1...VideoLogo.depthLayers).reversed(), id: \.self) { layer in
                    Image(uiImage: logo)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(Color(uiColor: VideoLogo.depthColor))
                        .offset(y: CGFloat(layer))
                }
                Image(uiImage: logo)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            }
            .frame(width: VideoLogo.width)
            .compositingGroup()
            .shadow(color: Color(uiColor: VideoLogo.shadowColor), radius: VideoLogo.shadowBlur / 2,
                    x: VideoLogo.shadowOffset.width, y: VideoLogo.shadowOffset.height)
            .accessibilityHidden(true)
        }
    }
}

/// Strava-style glass card along the bottom of a video: avatar, name, activity, three numbers and a thin progress bar.
struct VideoInfoCard: View {
    let info: VideoOverlayInfo
    /// 0...1 along the route.
    let progress: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(info.initials)
                    .font(MuryTypography.font(.subheadline, size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.22), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(info.athleteName)
                        .font(MuryTypography.font(.subheadline, size: 14, weight: .bold))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Image(systemName: info.symbolName).font(.system(size: 11, weight: .semibold))
                        Text(info.activityTitle)
                            .font(MuryTypography.font(.caption, size: 12))
                            .lineLimit(1)
                    }
                    .opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            HStack(alignment: .top) {
                stat("Distance", info.distance)
                Spacer()
                stat(info.paceLabel, info.pace)
                Spacer()
                stat("Elevation", info.elevation)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.3))
                    Capsule().fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, progress))))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay { RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.3)) }
        }
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(MuryTypography.font(.caption, size: 11)).opacity(0.75)
            Text(value).font(MuryTypography.font(.headline, size: 17, weight: .bold)).monospacedDigit()
        }
    }
}
