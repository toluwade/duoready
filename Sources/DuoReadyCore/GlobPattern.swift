import Foundation

/// A small, predictable glob matcher for repository-relative paths.
///
/// - `**` matches any number of path components (including none).
/// - `*` matches within a single component.
/// - `?` matches one character within a component.
/// - A pattern with no `/` matches at any depth, like `.gitignore`.
public struct GlobPattern: Sendable {
    public let pattern: String
    private let regex: NSRegularExpression

    public init(_ pattern: String) throws {
        self.pattern = pattern
        var body = pattern
        if body.hasPrefix("./") { body.removeFirst(2) }
        if !body.contains("/") { body = "**/" + body }
        if body.hasSuffix("/") { body += "**" }
        regex = try NSRegularExpression(pattern: "^" + Self.translate(body) + "$")
    }

    public func matches(_ relativePath: String) -> Bool {
        let range = NSRange(relativePath.startIndex..., in: relativePath)
        return regex.firstMatch(in: relativePath, range: range) != nil
    }

    private static func translate(_ glob: String) -> String {
        var result = ""
        var chars = Array(glob)[...]
        while let char = chars.popFirst() {
            switch char {
            case "*" where chars.first == "*":
                chars.removeFirst()
                if chars.first == "/" {
                    chars.removeFirst()
                    result += "(?:.*/)?"
                } else {
                    result += ".*"
                }
            case "*":
                result += "[^/]*"
            case "?":
                result += "[^/]"
            default:
                result += NSRegularExpression.escapedPattern(for: String(char))
            }
        }
        return result
    }
}
