import DuoReadyCore

/// Turns a scan result into text for one destination.
public protocol Reporter {
    func render(_ result: ScanResult, failOn threshold: Severity) -> String
}

public enum ReportFormat: String, CaseIterable, Sendable {
    case text
    case json
    case github
    case sarif
    case markdown
}

extension Severity {
    var plural: String {
        switch self {
        case .info: "info"
        case .warning: "warnings"
        case .error: "errors"
        }
    }
}

enum Summary {
    static func line(for result: ScanResult) -> String {
        let files = result.filesScanned == 1 ? "1 file" : "\(result.filesScanned) files"
        guard !result.findings.isEmpty else {
            return "Scanned \(files): no \(result.baselineSuppressed > 0 ? "new " : "")findings."
        }
        let counts = Severity.allCases.reversed().compactMap { severity -> String? in
            let count = result.findings.count { $0.severity == severity }
            guard count > 0 else { return nil }
            return count == 1 && severity != .info ? "1 \(severity.rawValue)" : "\(count) \(severity.plural)"
        }
        return "Scanned \(files): \(counts.joined(separator: ", "))."
    }

    /// What the baseline hid and whether it needs regenerating.
    static func baselineNotes(for result: ScanResult) -> [String] {
        var notes: [String] = []
        if result.baselineSuppressed > 0 {
            let count = result.baselineSuppressed
            notes.append("\(count) existing finding\(count == 1 ? " is" : "s are") hidden by the baseline.")
        }
        if result.staleBaselineEntries > 0 {
            let count = result.staleBaselineEntries
            notes.append("\(count) baseline entr\(count == 1 ? "y no longer matches" : "ies no longer match") any finding. Run `duoready baseline` to remove \(count == 1 ? "it" : "them").")
        }
        return notes
    }
}
