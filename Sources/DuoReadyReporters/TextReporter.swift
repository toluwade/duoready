import DuoReadyCore

/// Compiler-style output that terminals and editors can hyperlink.
public struct TextReporter: Reporter {
    public var includeExplanations: Bool

    public init(includeExplanations: Bool = false) {
        self.includeExplanations = includeExplanations
    }

    public func render(_ result: ScanResult, failOn threshold: Severity) -> String {
        var lines: [String] = []
        for finding in result.findings {
            let column = finding.column.map { ":\($0)" } ?? ""
            lines.append("\(finding.file):\(finding.line)\(column): \(finding.severity.rawValue): [\(finding.ruleID)] \(finding.message)")
            if includeExplanations {
                lines.append("    Why: \(finding.explanation)")
            }
            if let suggestion = finding.suggestion {
                lines.append("    Fix: \(suggestion)")
            }
        }
        for issue in result.issues {
            lines.append("\(issue.file): note: \(issue.message)")
        }
        if !lines.isEmpty { lines.append("") }
        lines.append(Summary.line(for: result))
        lines += Summary.baselineNotes(for: result)

        let failing = result.failingFindings(threshold: threshold).count
        if failing > 0 {
            lines.append("\(failing) finding\(failing == 1 ? "" : "s") at or above '\(threshold.rawValue)'; failing.")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
