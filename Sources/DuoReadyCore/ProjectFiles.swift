import Foundation

/// A property-list value in a form rules can inspect safely.
public indirect enum PropertyListValue: Sendable, Equatable {
    case bool(Bool)
    case string(String)
    case number(Double)
    case array([PropertyListValue])
    case dictionary([String: PropertyListValue])
    /// Dates and data, which no rule needs to read.
    case other

    init(_ object: Any) {
        switch object {
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
            self = .bool(number.boolValue)
        case let number as NSNumber:
            self = .number(number.doubleValue)
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(array.map(PropertyListValue.init))
        case let dictionary as [String: Any]:
            self = .dictionary(dictionary.mapValues(PropertyListValue.init))
        default:
            self = .other
        }
    }

    public subscript(key: String) -> PropertyListValue? {
        guard case let .dictionary(dictionary) = self else { return nil }
        return dictionary[key]
    }

    /// True for `<true/>`, and for the strings `YES` and `true`, which Xcode
    /// accepts in build-setting substitutions.
    public var isTrue: Bool {
        switch self {
        case let .bool(value): value
        case let .string(value): ["yes", "true"].contains(value.lowercased())
        case let .number(value): value != 0
        default: false
        }
    }

    public var isEmpty: Bool {
        switch self {
        case let .array(values): values.isEmpty
        case let .dictionary(values): values.isEmpty
        default: false
        }
    }
}

/// A parsed `.plist` file, such as Info.plist.
public struct PropertyListFile: Sendable {
    public let relativePath: String
    public let root: PropertyListValue
    /// The XML text, when the file is XML. Binary plists have no lines.
    private let lines: [Substring]

    public init?(relativePath: String, data: Data) {
        guard let object = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return nil }
        self.relativePath = relativePath
        self.root = PropertyListValue(object)
        self.lines = String(data: data, encoding: .utf8)?
            .split(separator: "\n", omittingEmptySubsequences: false) ?? []
    }

    /// The 1-based line holding `<key>name</key>`, or 1 when it can't be located.
    public func line(ofKey name: String) -> Int {
        let tag = "<key>\(name)</key>"
        return (lines.firstIndex { $0.contains(tag) } ?? 0) + 1
    }

    public func text(ofLine number: Int) -> Substring {
        number >= 1 && number <= lines.count ? lines[number - 1] : ""
    }
}

/// An Xcode `project.pbxproj`, read as text for build settings such as
/// `INFOPLIST_KEY_UIRequiresFullScreen = YES;`.
public struct ProjectSettingsFile: Sendable {
    public let relativePath: String
    public let lines: [Substring]

    public init(relativePath: String, text: String) {
        self.relativePath = relativePath
        self.lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    }

    /// 1-based lines that assign `value` to the build setting `name`.
    public func lines(setting name: String, value: String) -> [Int] {
        lines.indices.compactMap { index in
            let parts = lines[index].split(separator: "=", maxSplits: 1)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces) == name,
                  parts[1].trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ";\""))).lowercased() == value.lowercased()
            else { return nil }
            return index + 1
        }
    }
}
