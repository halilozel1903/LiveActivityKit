import LiveActivityKit
import SwiftUI

/// One template: its Lock Screen banner on a mock Lock Screen, then its compact and expanded Dynamic Island.
struct TemplatePage<Attributes: LiveActivityTemplate>: View {
    let summary: String
    let attributes: Attributes
    let state: Attributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GallerySection(title: "Lock Screen") {
                MockLockScreen {
                    Attributes.lockScreenPreview(attributes, state: state)
                }
            }

            GallerySection(title: "Dynamic Island") {
                VStack(spacing: 14) {
                    Attributes.compactPreview(attributes, state: state)
                    Attributes.expandedPreview(attributes, state: state)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Every template in the Dynamic Island: the compact presentation of each, two activities sharing the island in
/// the minimal presentation, and one expanded island.
struct IslandPage: View {
    var body: some View {
        let now = DemoData.now
        VStack(alignment: .leading, spacing: 22) {
            Text("Compact when one activity runs, minimal when two share the island, expanded on a long press.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GallerySection(title: "Compact") {
                VStack(spacing: 12) {
                    IslandRow(caption: "Delivery") {
                        DeliveryActivityAttributes.compactPreview(DemoData.delivery, state: DemoData.deliveryState(at: now))
                    }
                    IslandRow(caption: "Timer") {
                        TimerActivityAttributes.compactPreview(DemoData.timer, state: DemoData.timerState(at: now))
                    }
                    IslandRow(caption: "Score") {
                        ScoreActivityAttributes.compactPreview(DemoData.score, state: DemoData.scoreState(at: now))
                    }
                    IslandRow(caption: "Ride") {
                        RideActivityAttributes.compactPreview(DemoData.ride, state: DemoData.rideState(at: now))
                    }
                }
            }

            GallerySection(title: "Minimal") {
                VStack(spacing: 12) {
                    IslandRow(caption: "Delivery") {
                        DeliveryActivityAttributes.minimalPreview(DemoData.delivery, state: DemoData.deliveryState(at: now))
                    }
                    IslandRow(caption: "Ride") {
                        RideActivityAttributes.minimalPreview(DemoData.ride, state: DemoData.rideState(at: now))
                    }
                }
            }

            GallerySection(title: "Expanded") {
                ScoreActivityAttributes.expandedPreview(DemoData.score, state: DemoData.scoreState(at: now))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// An island with its template's name on the left.
struct IslandRow<Island: View>: View {
    let caption: String
    let island: Island

    init(caption: String, @ViewBuilder island: () -> Island) {
        self.caption = caption
        self.island = island()
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(caption)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Spacer(minLength: 0)
            island
            Spacer(minLength: 0)
        }
    }
}

/// A caption over a group of previews.
struct GallerySection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

/// A drawn Lock Screen: a wallpaper, the date and time, and the banner below them.
struct MockLockScreen<Banner: View>: View {
    let banner: Banner

    init(@ViewBuilder banner: () -> Banner) {
        self.banner = banner()
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                Text("Thursday, October 8")
                    .font(.system(size: 15, weight: .semibold))
                Text("9:41")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.top, 14)
            banner
                .padding(.horizontal, 8)
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.12, blue: 0.42),
                    Color(red: 0.55, green: 0.22, blue: 0.52),
                    Color(red: 0.93, green: 0.45, blue: 0.40),
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }
}

/// Buttons that start, step and end a real Live Activity of a template.
struct LauncherControls: View {
    let kind: LiveActivityLauncher.Kind
    let launcher: LiveActivityLauncher
    let advanceTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if launcher.isActive(kind) {
                    Button(advanceTitle) {
                        Task { await launcher.advance(kind) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("End", role: .destructive) {
                        Task { await launcher.end(kind) }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Start Live Activity", systemImage: "play.fill") {
                        launcher.start(kind)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if let message = launcher.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
