import Foundation

/// A non-fatal problem encountered while scanning, such as a skipped file.
public struct ScanIssue: Codable, Sendable, Hashable {
    public let file: String
    public let message: String

    public init(file: String, message: String) {
        self.file = file
        self.message = message
    }
}

public enum ScanError: Error, CustomStringConvertible {
    case pathNotFound(String)
    case notASwiftFile(String)
    case unreadableDirectory(String)
    case invalidExcludePattern(String)

    public var description: String {
        switch self {
        case let .pathNotFound(path): "No file or directory at \(path)"
        case let .notASwiftFile(path): "\(path) is not a .swift file"
        case let .unreadableDirectory(path): "Could not read directory \(path)"
        case let .invalidExcludePattern(pattern): "Invalid exclude pattern: \(pattern)"
        }
    }
}

public struct ScanResult: Codable, Sendable {
    public let findings: [Finding]
    public let issues: [ScanIssue]
    public let filesScanned: Int

    /// Findings hidden because a baseline covers them.
    public let baselineSuppressed: Int
    /// Baseline entries that no longer match any finding.
    public let staleBaselineEntries: Int

    public init(
        findings: [Finding],
        issues: [ScanIssue],
        filesScanned: Int,
        baselineSuppressed: Int = 0,
        staleBaselineEntries: Int = 0
    ) {
        self.findings = findings
        self.issues = issues
        self.filesScanned = filesScanned
        self.baselineSuppressed = baselineSuppressed
        self.staleBaselineEntries = staleBaselineEntries
    }

    public func failingFindings(threshold: Severity) -> [Finding] {
        findings.filter { $0.severity >= threshold }
    }
}

/// Runs enabled rules over files and applies configuration.
public struct Scanner: Sendable {
    public let registry: RuleRegistry
    public let configuration: ScanConfiguration

    public init(registry: RuleRegistry, configuration: ScanConfiguration = ScanConfiguration()) {
        self.registry = registry
        self.configuration = configuration
    }

    public func scan(root: URL) throws -> ScanResult {
        let enumerator: FileEnumerator
        do {
            enumerator = try FileEnumerator(excludePatterns: configuration.exclude, includeTests: configuration.includeTests)
        } catch {
            throw ScanError.invalidExcludePattern(configuration.exclude.joined(separator: ", "))
        }
        let (candidates, skipped) = try enumerator.swiftFiles(in: root)

        var findings: [Finding] = []
        var issues = skipped
        for candidate in candidates {
            guard let data = FileManager.default.contents(atPath: candidate.url.path),
                  let source = String(data: data, encoding: .utf8)
            else {
                issues.append(ScanIssue(file: candidate.relativePath, message: "Skipped: not readable as UTF-8."))
                continue
            }
            let file = SwiftSourceFile(relativePath: candidate.relativePath, source: source)
            if file.tree.hasError {
                issues.append(ScanIssue(file: file.relativePath, message: "Contains syntax errors; findings may be incomplete."))
            }
            findings += scan(file: file)
        }

        return ScanResult(findings: findings.sorted(), issues: issues, filesScanned: candidates.count)
    }

    /// Runs every enabled rule on one file, applying severity overrides and
    /// inline suppressions.
    public func scan(file: SwiftSourceFile) -> [Finding] {
        let suppressions = Suppressions(file: file)
        var results: [Finding] = []
        for rule in registry.rules where configuration.isEnabled(rule.metadata.id) {
            let severity = configuration.severity(for: rule.metadata)
            for finding in rule.check(file) where !suppressions.suppresses(finding) {
                results.append(finding.with(severity: severity))
            }
        }
        return results.sorted()
    }
}
