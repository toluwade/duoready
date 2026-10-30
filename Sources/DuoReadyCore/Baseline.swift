import Foundation

/// Findings that existed when a project adopted DuoReady.
///
/// Scans hide findings that match the baseline, so a project with many
/// existing findings can fail CI only on new ones. Entries match by
/// fingerprint (rule, file and flagged source text), not line number, so they
/// survive edits elsewhere in the file. Editing the flagged line itself, or
/// renaming the file, makes the finding new again.
public struct Baseline: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Hashable, Comparable {
        public let ruleID: String
        public let file: String
        /// Where the finding was when the baseline was written. For people
        /// reading the file only; matching ignores it.
        public let line: Int
        public let fingerprint: String
        public let message: String

        public init(_ finding: Finding) {
            ruleID = finding.ruleID
            file = finding.file
            line = finding.line
            fingerprint = finding.fingerprint
            message = finding.message
        }

        public static func < (lhs: Entry, rhs: Entry) -> Bool {
            (lhs.file, lhs.line, lhs.ruleID, lhs.fingerprint) < (rhs.file, rhs.line, rhs.ruleID, rhs.fingerprint)
        }
    }

    public static let currentVersion = 1
    public static let defaultFileName = ".duoready-baseline.json"

    public var version: Int
    public var entries: [Entry]

    public init(findings: [Finding]) {
        version = Self.currentVersion
        entries = findings.map(Entry.init).sorted()
    }

    enum CodingKeys: String, CodingKey {
        case version
        case entries = "findings"
    }

    public static func load(from url: URL) throws -> Baseline {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BaselineError.unreadable(path: url.path, reason: error.localizedDescription)
        }
        let baseline: Baseline
        do {
            baseline = try JSONDecoder().decode(Baseline.self, from: data)
        } catch {
            throw BaselineError.invalid(path: url.path, reason: String(describing: error))
        }
        guard baseline.version == currentVersion else {
            throw BaselineError.unsupportedVersion(baseline.version)
        }
        return baseline
    }

    /// Pretty-printed with sorted keys and a trailing newline, so the file
    /// diffs cleanly when committed.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // Encoding plain value types cannot fail.
        return try! encoder.encode(self) + Data("\n".utf8)
    }

    public struct Application: Sendable, Equatable {
        /// Findings not covered by the baseline.
        public let remaining: [Finding]
        /// Findings hidden because the baseline covers them.
        public let suppressedCount: Int
        /// Baseline entries with no matching finding: fixed, edited or moved.
        public let staleEntries: [Entry]
    }

    /// Splits findings into new and baselined ones. Each entry absorbs at most
    /// one finding, so a second identical problem on an identical line still
    /// counts as new.
    public func apply(to findings: [Finding]) -> Application {
        var available: [String: [Entry]] = [:]
        for entry in entries {
            available[entry.fingerprint, default: []].append(entry)
        }

        var remaining: [Finding] = []
        var suppressed = 0
        for finding in findings {
            if var matches = available[finding.fingerprint], !matches.isEmpty {
                matches.removeFirst()
                available[finding.fingerprint] = matches
                suppressed += 1
            } else {
                remaining.append(finding)
            }
        }
        return Application(
            remaining: remaining,
            suppressedCount: suppressed,
            staleEntries: available.values.flatMap { $0 }.sorted()
        )
    }
}

public enum BaselineError: Error, CustomStringConvertible, Equatable {
    case unreadable(path: String, reason: String)
    case invalid(path: String, reason: String)
    case unsupportedVersion(Int)

    public var description: String {
        switch self {
        case let .unreadable(path, reason):
            "Could not read baseline at \(path): \(reason.hasSuffix(".") ? reason : reason + ".") Create one with `duoready baseline`."
        case let .invalid(path, reason):
            "Baseline at \(path) is not valid: \(reason)"
        case let .unsupportedVersion(version):
            "Baseline version \(version) is not supported (expected \(Baseline.currentVersion))."
        }
    }
}

extension ScanResult {
    /// The result with baselined findings removed and counted.
    public func applying(_ baseline: Baseline) -> ScanResult {
        let application = baseline.apply(to: findings)
        return ScanResult(
            findings: application.remaining,
            issues: issues,
            filesScanned: filesScanned,
            baselineSuppressed: application.suppressedCount,
            staleBaselineEntries: application.staleEntries.count
        )
    }
}
