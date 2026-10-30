/// Inline opt-outs written as `// duoready:ignore DR001 DR002`.
///
/// A trailing comment suppresses findings on its own line. A comment on a
/// line by itself suppresses findings on the next line.
/// `// duoready:ignore-file DR001` anywhere in a file suppresses that rule
/// in the whole file. With no rule IDs, every rule is suppressed.
struct Suppressions {
    private static let marker = "duoready:ignore"
    private static let fileMarker = "duoready:ignore-file"
    private let file: SwiftSourceFile
    /// Rule IDs ignored in the whole file; empty when none are.
    private var fileWideIDs: Set<Substring> = []
    private var ignoresWholeFile = false

    init(file: SwiftSourceFile) {
        self.file = file
        guard file.source.contains(Self.fileMarker) else { return }
        for line in file.source.split(separator: "\n") {
            guard let ids = Self.ruleIDs(in: line, after: Self.fileMarker) else { continue }
            if ids.isEmpty { ignoresWholeFile = true }
            fileWideIDs.formUnion(ids)
        }
    }

    func suppresses(_ finding: Finding) -> Bool {
        suppresses(ruleID: finding.ruleID, line: finding.line)
    }

    func suppresses(ruleID: String, line number: Int) -> Bool {
        if ignoresWholeFile || fileWideIDs.contains(Substring(ruleID)) {
            return true
        }
        if let line = file.line(number), matches(line, ruleID: ruleID) {
            return true
        }
        if let previous = file.line(number - 1),
           previous.trimmingPrefix(while: \.isWhitespace).hasPrefix("//"),
           matches(previous, ruleID: ruleID)
        {
            return true
        }
        return false
    }

    private func matches(_ line: Substring, ruleID: String) -> Bool {
        guard let ids = Self.ruleIDs(in: line, after: Self.marker) else { return false }
        return ids.isEmpty || ids.contains { $0 == ruleID }
    }

    /// The rule IDs after `marker` in a `//` comment, or nil when the line has
    /// no such comment. `duoready:ignore` doesn't match `duoready:ignore-file`.
    private static func ruleIDs(in line: Substring, after marker: String) -> [Substring]? {
        guard let commentStart = line.range(of: "//"),
              let markerRange = line[commentStart.upperBound...].range(of: marker),
              line[markerRange.upperBound...].first != "-"
        else { return nil }
        return line[markerRange.upperBound...]
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" })
            .filter { $0.hasPrefix("DR") }
    }
}

private extension Substring {
    func trimmingPrefix(while predicate: (Character) -> Bool) -> Substring {
        self[(firstIndex { !predicate($0) } ?? endIndex)...]
    }
}
