import Foundation

/// Compares two content states by their encoded fields, the way ActivityKit sees them in a push payload.
///
/// ```swift
/// ContentStateDiff.changedKeys(from: old, to: new)                      // ["stepIndex", "eta"]
/// ContentStateDiff.hasChanges(from: old, to: new, ignoring: ["detail"]) // true
/// ```
///
/// Any `Encodable` state works. Keys are the coding keys of the top level; a nested change reports its top-level
/// key. A missing key and an explicit `null` are the same. A state that does not encode to a JSON object (an enum
/// with a raw value, for example) reports `wholeValueKey` when it changed.
public enum ContentStateDiff {
    /// The key reported for a state that is not a JSON object.
    public static let wholeValueKey = "self"

    /// The top-level keys whose values differ between `old` and `new`.
    public static func changedKeys<State: Encodable>(from old: State, to new: State) -> Set<String> {
        let before = encode(old)
        let after = encode(new)
        guard
            let beforeObject = before.flatMap(object(from:)),
            let afterObject = after.flatMap(object(from:))
        else {
            return before == after ? [] : [wholeValueKey]
        }
        var keys = Set<String>()
        for key in Set(beforeObject.keys).union(afterObject.keys) where canonical(beforeObject[key]) != canonical(afterObject[key]) {
            keys.insert(key)
        }
        return keys
    }

    /// `true` when any key other than `ignoring` changed.
    public static func hasChanges<State: Encodable>(from old: State, to new: State, ignoring: Set<String> = []) -> Bool {
        !changedKeys(from: old, to: new).subtracting(ignoring).isEmpty
    }

    private static func encode<State: Encodable>(_ value: State) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(value)
    }

    private static func object(from data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// One JSON value in a canonical form, wrapped in an array so numbers and strings are valid JSON too.
    /// `nil` and `null` both give `nil`.
    private static func canonical(_ value: Any?) -> Data? {
        guard let value, !(value is NSNull) else { return nil }
        return try? JSONSerialization.data(withJSONObject: [value], options: [.sortedKeys])
    }
}
