import LiveActivityKit
import SwiftUI

/// The gallery: one page per template with its Lock Screen banner and its Dynamic Island, and a page with every
/// template in the island. A screenshot launch opens one page.
struct GalleryView: View {
    enum Page: String, CaseIterable, Identifiable {
        case delivery
        case timer
        case score
        case ride
        case island

        var id: String { rawValue }

        var title: String {
            switch self {
            case .delivery: "Delivery"
            case .timer: "Timer"
            case .score: "Score"
            case .ride: "Ride"
            case .island: "Island"
            }
        }

        init(scene: ScreenshotScene) {
            switch scene {
            case .delivery: self = .delivery
            case .timer: self = .timer
            case .score: self = .score
            case .island: self = .island
            }
        }
    }

    let scene: ScreenshotScene?

    @State private var page: Page
    @State private var launcher = LiveActivityLauncher()

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _page = State(initialValue: scene.map(Page.init(scene:)) ?? .delivery)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Live Activities")
                    .font(.system(size: 30, weight: .bold))
                Picker("Template", selection: $page) {
                    ForEach(Page.allCases) { page in
                        Text(page.title).tag(page)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 10)
            .background(Color(white: 0.06))
        }
        .background(Color(white: 0.06).ignoresSafeArea())
        // Every countdown reads as at DemoData.now, so the gallery looks the same in every frame.
        .liveActivityNow(DemoData.now)
        .task {
            guard let scene else { return }
            // Tells scripts/screenshots.sh that the scene is on screen. Nothing in the gallery animates and the
            // countdowns are static, so the frame is final once it has been drawn.
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? await Task.sleep(for: .seconds(1.5))
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .delivery:
            TemplatePage(
                summary: "Steps from order to door, an arrival countdown and the courier.",
                attributes: DemoData.delivery,
                state: DemoData.deliveryState(at: DemoData.now)
            )
            LauncherControls(kind: .delivery, launcher: launcher, advanceTitle: "Next step")
        case .timer:
            TemplatePage(
                summary: "A countdown that ticks on its own between updates, with pause and resume.",
                attributes: DemoData.timer,
                state: DemoData.timerState(at: DemoData.now)
            )
            LauncherControls(kind: .timer, launcher: launcher, advanceTitle: "Pause or resume")
        case .score:
            TemplatePage(
                summary: "Two teams, the score, the period clock and the last play.",
                attributes: DemoData.score,
                state: DemoData.scoreState(at: DemoData.now)
            )
            LauncherControls(kind: .score, launcher: launcher, advanceTitle: "Score")
        case .ride:
            TemplatePage(
                summary: "The driver's arrival, the route and the car to look for.",
                attributes: DemoData.ride,
                state: DemoData.rideState(at: DemoData.now)
            )
            LauncherControls(kind: .ride, launcher: launcher, advanceTitle: "Next phase")
        case .island:
            IslandPage()
        }
    }
}
