import Foundation

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
enum ScreenshotScene: String {
    /// The delivery template: its Lock Screen banner and its Dynamic Island.
    case delivery
    /// The timer template.
    case timer
    /// The score template.
    case score
    /// Every template in the Dynamic Island: compact, minimal and expanded.
    case island

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }
}
