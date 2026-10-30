import SwiftSyntax

public enum RuleCategory: String, Codable, Sendable {
    case swiftUI = "SwiftUI"
    case uiKit = "UIKit"
    case shared = "Shared"
    case projectConfiguration = "ProjectConfiguration"
}

public enum RuleConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
}

/// Static description of a rule. Kept in one place so the CLI, JSON output
/// and RULES.md never disagree about what a rule is.
public struct RuleMetadata: Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let category: RuleCategory
    public let defaultSeverity: Severity
    public let confidence: RuleConfidence
    public let rationale: String
    public let suggestion: String
    public let limitations: String

    public init(
        id: String,
        title: String,
        category: RuleCategory,
        defaultSeverity: Severity,
        confidence: RuleConfidence,
        rationale: String,
        suggestion: String,
        limitations: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.defaultSeverity = defaultSeverity
        self.confidence = confidence
        self.rationale = rationale
        self.suggestion = suggestion
        self.limitations = limitations
    }

    public var documentationPath: String { "RULES.md#\(id.lowercased())" }
}

/// A rule that inspects one parsed Swift file.
///
/// Rules are pure: they never touch the file system, never know which
/// reporter will display their output, and never rewrite source.
public protocol SwiftRule: Sendable {
    var metadata: RuleMetadata { get }
    func check(_ file: SwiftSourceFile) -> [Finding]
}

extension SwiftRule {
    /// Builds a finding located at `node`, using the rule's default severity.
    /// The scanner applies configured severity overrides afterwards.
    public func finding(
        at node: some SyntaxProtocol,
        in file: SwiftSourceFile,
        message: String,
        suggestion: String? = nil
    ) -> Finding {
        let location = file.location(of: node)
        return Finding(
            ruleID: metadata.id,
            severity: metadata.defaultSeverity,
            message: message,
            file: file.relativePath,
            line: location.line,
            column: location.column,
            explanation: metadata.rationale,
            suggestion: suggestion ?? metadata.suggestion,
            fingerprint: Finding.fingerprint(
                ruleID: metadata.id, file: file.relativePath, sourceLine: file.line(location.line) ?? ""
            )
        )
    }
}
