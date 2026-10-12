import Foundation

/// Push tokens as your server wants them.
///
/// ActivityKit hands out a Live Activity's push token as `Data`; APNs and most servers expect it as lowercase hex.
///
/// ```swift
/// PushToken.hexString(token)          // "8f3a…"
/// PushToken.data(fromHex: "8f3a")     // Data([0x8f, 0x3a])
/// ```
public enum PushToken {
    /// The token as lowercase hex, two characters per byte.
    public static func hexString(_ token: Data) -> String {
        let digits = Array("0123456789abcdef")
        var text = ""
        text.reserveCapacity(token.count * 2)
        for byte in token {
            text.append(digits[Int(byte >> 4)])
            text.append(digits[Int(byte & 0x0F)])
        }
        return text
    }

    /// Parses hex (either case, an even number of digits) back into a token, or `nil` for anything else.
    public static func data(fromHex hex: String) -> Data? {
        let characters = Array(hex)
        guard characters.count.isMultiple(of: 2) else { return nil }
        var data = Data()
        data.reserveCapacity(characters.count / 2)
        var index = 0
        while index < characters.count {
            guard let high = characters[index].hexDigitValue, let low = characters[index + 1].hexDigitValue else {
                return nil
            }
            data.append(UInt8(high << 4 | low))
            index += 2
        }
        return data
    }
}
