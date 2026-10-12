import Foundation

/// A color that travels in a Live Activity's attributes or push payload as a hex string, such as `"#FF6B00"`.
///
/// ```swift
/// let tint = ActivityTint(hex: "#552583")!     // also "552583" and "#535"
/// tint.hex                                      // "#552583"
/// tint.prefersDarkContent                       // false: draw white text on it
/// ```
public struct ActivityTint: Hashable, Sendable, Codable {
    /// Red, from 0 to 1.
    public let red: Double
    /// Green, from 0 to 1.
    public let green: Double
    /// Blue, from 0 to 1.
    public let blue: Double

    /// A color from components from 0 to 1; values outside are clamped and NaN reads 0.
    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    /// Parses `#RRGGBB` or `#RGB`, with or without `#`, in any case. Returns `nil` for anything else.
    public init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// `#RRGGBB` in uppercase.
    public var hex: String {
        "#" + [red, green, blue].map { component in
            let byte = Int((component * 255).rounded())
            let text = String(byte, radix: 16, uppercase: true)
            return text.count == 1 ? "0" + text : text
        }.joined()
    }

    /// The relative luminance (WCAG), from 0 for black to 1 for white.
    public var luminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// `true` when black text reads better on this color than white text.
    public var prefersDarkContent: Bool {
        // Contrast with black is (L + 0.05) / 0.05, with white 1.05 / (L + 0.05); they are equal at L ≈ 0.179.
        luminance > 0.179
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let tint = ActivityTint(hex: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a #RRGGBB color, got \(text)")
        }
        self = tint
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    private static func clamp(_ value: Double) -> Double {
        value.isNaN ? 0 : min(max(value, 0), 1)
    }

    // MARK: - Presets

    /// A color from 8-bit components, so presets equal their parsed hex.
    private static func bytes(_ red: Int, _ green: Int, _ blue: Int) -> ActivityTint {
        ActivityTint(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    /// `#FF6B00`, for deliveries.
    public static let orange = bytes(255, 107, 0)
    /// `#34C759`.
    public static let green = bytes(52, 199, 89)
    /// `#0A84FF`.
    public static let blue = bytes(10, 132, 255)
    /// `#AF52DE`.
    public static let purple = bytes(175, 82, 222)
    /// `#FF2D55`.
    public static let pink = bytes(255, 45, 85)
    /// `#30B0C7`.
    public static let teal = bytes(48, 176, 199)
    /// `#FFCC00`, for timers.
    public static let yellow = bytes(255, 204, 0)
}
