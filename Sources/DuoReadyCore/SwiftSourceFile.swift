import SwiftParser
import SwiftSyntax

/// A parsed Swift file plus what rules need to report precise locations.
public struct SwiftSourceFile: Sendable {
    public let relativePath: String
    public let source: String
    public let tree: SourceFileSyntax
    private let converter: SourceLocationConverter
    private let lines: [Substring]

    public init(relativePath: String, source: String) {
        self.relativePath = relativePath
        self.source = source
        self.tree = Parser.parse(source: source)
        self.converter = SourceLocationConverter(fileName: relativePath, tree: tree)
        self.lines = source.split(separator: "\n", omittingEmptySubsequences: false)
    }

    /// 1-based line and column of the first non-trivia token of `node`.
    public func location(of node: some SyntaxProtocol) -> (line: Int, column: Int) {
        let location = node.startLocation(converter: converter)
        return (location.line, location.column)
    }

    /// The raw text of a 1-based line, or nil when out of range.
    public func line(_ number: Int) -> Substring? {
        guard number >= 1, number <= lines.count else { return nil }
        return lines[number - 1]
    }
}
