/// Inline opt-outs written as `// duoready:ignore DR001 DR002`.
///
/// A trailing comment suppresses findings on its own line. A comment on a
/// line by itself suppresses findings on the next line. With no rule IDs,
/// every rule is suppressed.
struct Suppressions {
    private static let marker = "duoready:ignore"
    private let file: SwiftSourceFile

    init(file: SwiftSourceFile) {
        self.file = file
    }

    func suppresses(_ finding: Finding) -> Bool {
        if let line = file.line(finding.line), matches(line, ruleID: finding.ruleID) {
            return true
        }
        if let previous = file.line(finding.line - 1),
           previous.trimmingPrefix(while: \.isWhitespace).hasPrefix("//"),
           matches(previous, ruleID: finding.ruleID)
        {
            return true
        }
        return false
    }

    private func matches(_ line: Substring, ruleID: String) -> Bool {
        guard let commentStart = line.range(of: "//"),
              let markerRange = line[commentStart.upperBound...].range(of: Self.marker)
        else { return false }
        let ids = line[markerRange.upperBound...]
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" })
            .filter { $0.hasPrefix("DR") }
        return ids.isEmpty || ids.contains { $0 == ruleID }
    }
}

private extension Substring {
    func trimmingPrefix(while predicate: (Character) -> Bool) -> Substring {
        self[(firstIndex { !predicate($0) } ?? endIndex)...]
    }
}
