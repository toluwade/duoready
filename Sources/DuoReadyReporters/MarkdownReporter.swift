import DuoReadyCore
import Foundation

/// A Markdown summary for GitHub job summaries and pull-request comments.
public struct MarkdownReporter: Reporter {
    /// Rows shown before the table is cut short, so huge reports stay readable.
    public static let maximumRows = 50

    public var rules: [RuleMetadata]
    public var pathPrefix: String

    public init(rules: [RuleMetadata], pathPrefix: String = "") {
        self.rules = rules
        self.pathPrefix = pathPrefix.isEmpty || pathPrefix.hasSuffix("/") ? pathPrefix : pathPrefix + "/"
    }

    public func render(_ result: ScanResult, failOn threshold: Severity) -> String {
        var lines = ["## DuoReady", ""]
        let failing = result.failingFindings(threshold: threshold).count
        let status = failing > 0
            ? "**Failing:** \(failing) finding\(failing == 1 ? "" : "s") at or above `\(threshold.rawValue)`."
            : "**Passing:** no findings at or above `\(threshold.rawValue)`."
        lines.append("\(status) \(Summary.line(for: result))")
        lines += Summary.baselineNotes(for: result)

        guard !result.findings.isEmpty else { return lines.joined(separator: "\n") + "\n" }

        lines += ["", "| Severity | Rule | Location | Finding |", "| --- | --- | --- | --- |"]
        let ordered = result.findings.sorted { ($0.severity, $1.file, $1.line) > ($1.severity, $0.file, $0.line) }
        for finding in ordered.prefix(Self.maximumRows) {
            let link = "[\(finding.ruleID)](\(SARIFReporter.documentationURL)#\(finding.ruleID.lowercased()))"
            lines.append("| \(finding.severity.rawValue) | \(link) | `\(pathPrefix)\(finding.file):\(finding.line)` | \(Self.escape(finding.message)) |")
        }
        if ordered.count > Self.maximumRows {
            lines += ["", "…and \(ordered.count - Self.maximumRows) more. Run `duoready scan` locally for the full list."]
        }

        let found = Set(result.findings.map(\.ruleID))
        let fixes = rules.filter { found.contains($0.id) }.sorted { $0.id < $1.id }
        lines += ["", "<details><summary>How to fix</summary>", ""]
        lines += fixes.map { "- **\($0.id) \(Self.escape($0.title)):** \(Self.escape($0.suggestion))" }
        lines += ["", "</details>"]
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }
}
