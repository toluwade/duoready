import DuoReadyCore
import Foundation

/// SARIF 2.1.0, the format GitHub code scanning reads. Uploaded with
/// `github/codeql-action/upload-sarif`, findings appear in the repository's
/// Security tab and stay open until the code is fixed.
public struct SARIFReporter: Reporter {
    public static let documentationURL = "https://github.com/toluwade/duoready/blob/main/RULES.md"

    /// Every rule, so the report can describe rules even without findings.
    public var rules: [RuleMetadata]
    /// Prepended to finding paths so they resolve from the repository root.
    public var pathPrefix: String

    public init(rules: [RuleMetadata], pathPrefix: String = "") {
        self.rules = rules.sorted { $0.id < $1.id }
        self.pathPrefix = pathPrefix.isEmpty || pathPrefix.hasSuffix("/") ? pathPrefix : pathPrefix + "/"
    }

    public func render(_ result: ScanResult, failOn threshold: Severity) -> String {
        let ruleIndex = Dictionary(uniqueKeysWithValues: rules.enumerated().map { ($1.id, $0) })
        let log: [String: Any] = [
            "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
            "version": "2.1.0",
            "runs": [[
                "tool": [
                    "driver": [
                        "name": "DuoReady",
                        "version": DuoReady.version,
                        "semanticVersion": DuoReady.version,
                        "informationUri": "https://github.com/toluwade/duoready",
                        "rules": rules.map(Self.descriptor),
                    ] as [String: Any],
                ],
                "results": result.findings.map { finding in
                    var location: [String: Any] = ["startLine": finding.line]
                    if let column = finding.column { location["startColumn"] = column }
                    var entry: [String: Any] = [
                        "ruleId": finding.ruleID,
                        "level": Self.level(finding.severity),
                        "message": ["text": [finding.message, finding.suggestion.map { "Fix: \($0)" }].compactMap { $0 }.joined(separator: " ")],
                        "locations": [[
                            "physicalLocation": [
                                "artifactLocation": ["uri": pathPrefix + finding.file],
                                "region": location,
                            ] as [String: Any],
                        ]],
                        "partialFingerprints": ["duoreadyFingerprint/v1": finding.fingerprint],
                    ]
                    if let index = ruleIndex[finding.ruleID] { entry["ruleIndex"] = index }
                    return entry
                },
            ] as [String: Any]],
        ]
        // JSONSerialization can't fail on these plain values.
        let data = try! JSONSerialization.data(withJSONObject: log, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    static func descriptor(_ rule: RuleMetadata) -> [String: Any] {
        let help = "\(rule.suggestion)\n\nLimitations: \(rule.limitations)"
        return [
            "id": rule.id,
            "name": rule.title,
            "shortDescription": ["text": rule.title],
            "fullDescription": ["text": rule.rationale],
            "help": ["text": help, "markdown": "**Fix:** \(rule.suggestion)\n\n**Limitations:** \(rule.limitations)"],
            "helpUri": "\(documentationURL)#\(rule.id.lowercased())",
            "defaultConfiguration": ["level": level(rule.defaultSeverity)],
            "properties": [
                "tags": ["duoready", "resizability", rule.category.rawValue],
                "precision": rule.confidence == .high ? "high" : rule.confidence == .medium ? "medium" : "low",
                "problem.severity": level(rule.defaultSeverity) == "note" ? "recommendation" : level(rule.defaultSeverity),
            ] as [String: Any],
        ]
    }

    static func level(_ severity: Severity) -> String {
        switch severity {
        case .info: "note"
        case .warning: "warning"
        case .error: "error"
        }
    }
}
