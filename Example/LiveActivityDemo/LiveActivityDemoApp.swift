import SwiftUI

@main
struct LiveActivityDemoApp: App {
    var body: some Scene {
        WindowGroup {
            GalleryView(scene: ScreenshotScene.current)
                .preferredColorScheme(.dark)
        }
    }
}
