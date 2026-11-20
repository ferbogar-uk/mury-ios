import SwiftUI

/// The real MURY logo (white) across the top of a video, with a soft shadow so it reads on any map. No band.
struct VideoLogoMark: View {
    var body: some View {
        Image("LogoWhite")
            .resizable()
            .scaledToFit()
            .frame(width: 190)
            .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 2)
            .accessibilityHidden(true)
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
