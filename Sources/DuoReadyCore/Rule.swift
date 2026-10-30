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

/// Anything with rule metadata. Concrete rules adopt ``SwiftRule`` or
/// ``ProjectRule``.
///
/// Rules are pure: they never touch the file system, never know which
/// reporter will display their output, and never rewrite source.
public protocol Rule: Sendable {
    var metadata: RuleMetadata { get }
}

/// A rule that inspects one parsed Swift file.
public protocol SwiftRule: Rule {
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
        return metadata.finding(
            file: file.relativePath, line: location.line, column: location.column,
            sourceLine: file.line(location.line) ?? "", message: message, suggestion: suggestion
        )
    }
}

/// Something a ``ProjectRule`` noticed in a Swift file, kept until every file
/// has been read. For example: "this file declares a UIKit app delegate".
public struct ProjectNote: Sendable, Hashable {
    public let kind: String
    public let file: String
    public let line: Int
    public let column: Int
    public let sourceLine: String

    public init(kind: String, at node: some SyntaxProtocol, in file: SwiftSourceFile) {
        let location = file.location(of: node)
        self.kind = kind
        self.file = file.relativePath
        self.line = location.line
        self.column = location.column
        self.sourceLine = String(file.line(location.line) ?? "")
    }
}

/// What a ``ProjectRule`` sees once every file has been read.
public struct ProjectContext: Sendable {
    /// Notes the rule took from Swift files, in path order.
    public let notes: [ProjectNote]
    public let propertyLists: [PropertyListFile]
    public let projectSettings: [ProjectSettingsFile]

    public init(notes: [ProjectNote], propertyLists: [PropertyListFile], projectSettings: [ProjectSettingsFile]) {
        self.notes = notes
        self.propertyLists = propertyLists
        self.projectSettings = projectSettings
    }

    public func notes(_ kind: String) -> [ProjectNote] {
        notes.filter { $0.kind == kind }
    }
}

/// A rule that needs the whole project: Info.plist files, Xcode build
/// settings, or facts gathered from several Swift files.
///
/// Swift files aren't kept in memory, so a rule records what it needs from
/// each one with ``notes(for:)``, then decides in ``check(_:)``.
public protocol ProjectRule: Rule {
    func notes(for file: SwiftSourceFile) -> [ProjectNote]
    func check(_ project: ProjectContext) -> [Finding]
}

extension ProjectRule {
    public func notes(for file: SwiftSourceFile) -> [ProjectNote] { [] }

    public func finding(at note: ProjectNote, message: String, suggestion: String? = nil) -> Finding {
        metadata.finding(
            file: note.file, line: note.line, column: note.column,
            sourceLine: note.sourceLine, message: message, suggestion: suggestion
        )
    }

    public func finding(in plist: PropertyListFile, key: String, message: String, suggestion: String? = nil) -> Finding {
        let line = plist.line(ofKey: key)
        return metadata.finding(
            file: plist.relativePath, line: line, column: nil,
            sourceLine: plist.text(ofLine: line), message: message, suggestion: suggestion
        )
    }

    public func finding(in settings: ProjectSettingsFile, line: Int, message: String, suggestion: String? = nil) -> Finding {
        metadata.finding(
            file: settings.relativePath, line: line, column: nil,
            sourceLine: settings.lines[line - 1], message: message, suggestion: suggestion
        )
    }
}

extension RuleMetadata {
    func finding(
        file: String, line: Int, column: Int?, sourceLine: some StringProtocol,
        message: String, suggestion: String?
    ) -> Finding {
        Finding(
            ruleID: id,
            severity: defaultSeverity,
            message: message,
            file: file,
            line: line,
            column: column,
            explanation: rationale,
            suggestion: suggestion ?? self.suggestion,
            fingerprint: Finding.fingerprint(ruleID: id, file: file, sourceLine: sourceLine)
        )
    }
}
