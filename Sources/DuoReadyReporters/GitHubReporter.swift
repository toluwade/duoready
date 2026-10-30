import Foundation
import DuoReadyCore

/// GitHub Actions workflow commands, which GitHub renders as inline
/// annotations on the pull request diff.
public struct GitHubReporter: Reporter {
    /// Prepended to finding paths so annotations resolve from the repository
    /// root when the scan root is a subdirectory, e.g. `ios/`.
    public var pathPrefix: String

    public init(pathPrefix: String = "") {
        if pathPrefix.isEmpty || pathPrefix.hasSuffix("/") {
            self.pathPrefix = pathPrefix
        } else {
            self.pathPrefix = pathPrefix + "/"
        }
    }

    public func render(_ result: ScanResult, failOn threshold: Severity) -> String {
        var lines: [String] = []
        for finding in result.findings {
            var properties = [
                "file=\(Self.escapeProperty(pathPrefix + finding.file))",
                "line=\(finding.line)",
            ]
            if let column = finding.column {
                properties.append("col=\(column)")
            }
            properties.append("title=\(Self.escapeProperty("DuoReady \(finding.ruleID)"))")

            var message = finding.message
            if let suggestion = finding.suggestion {
                message += "\nFix: \(suggestion)"
            }
            lines.append("::\(Self.command(for: finding.severity)) \(properties.joined(separator: ","))::\(Self.escapeData(message))")
        }
        for issue in result.issues {
            lines.append("::notice file=\(Self.escapeProperty(pathPrefix + issue.file)),title=DuoReady::\(Self.escapeData(issue.message))")
        }
        lines.append(Summary.line(for: result))
        lines += Summary.baselineNotes(for: result)
        return lines.joined(separator: "\n") + "\n"
    }

    static func command(for severity: Severity) -> String {
        switch severity {
        case .info: "notice"
        case .warning: "warning"
        case .error: "error"
        }
    }

    /// Escaping rules from GitHub's workflow-command implementation (actions/toolkit).
    static func escapeData(_ value: String) -> String {
        value
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "\r", with: "%0D")
            .replacingOccurrences(of: "\n", with: "%0A")
    }

    static func escapeProperty(_ value: String) -> String {
        escapeData(value)
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ",", with: "%2C")
    }
}
