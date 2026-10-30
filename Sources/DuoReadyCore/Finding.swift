/// How serious a finding is. Ordered so thresholds can be compared with `>=`.
public enum Severity: String, Codable, Sendable, CaseIterable, Comparable {
    case info
    case warning
    case error

    private var rank: Int {
        switch self {
        case .info: 0
        case .warning: 1
        case .error: 2
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// A single diagnostic produced by a rule. Every rule, reporter and baseline
/// speaks this one model, so its shape is part of the public JSON contract.
public struct Finding: Codable, Sendable, Hashable {
    public let ruleID: String
    public let severity: Severity
    public let message: String
    /// Path relative to the scanned root, using `/` separators.
    public let file: String
    public let line: Int
    public let column: Int?
    public let explanation: String
    public let suggestion: String?
    /// Identifies the finding independently of its line number, so baselines
    /// keep matching when unrelated code above it is added or removed.
    /// Derived from the rule, file and the normalized text of the flagged line.
    public let fingerprint: String

    /// - Parameter fingerprint: Pass the value from ``Finding/fingerprint(ruleID:file:sourceLine:)``.
    ///   When omitted, it is derived from the line number, which is only stable
    ///   while the file is unchanged.
    public init(
        ruleID: String,
        severity: Severity,
        message: String,
        file: String,
        line: Int,
        column: Int?,
        explanation: String,
        suggestion: String?,
        fingerprint: String? = nil
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.file = file
        self.line = line
        self.column = column
        self.explanation = explanation
        self.suggestion = suggestion
        self.fingerprint = fingerprint ?? Self.fingerprint(ruleID: ruleID, file: file, sourceLine: "line \(line)")
    }

    public func with(severity: Severity) -> Finding {
        Finding(
            ruleID: ruleID, severity: severity, message: message, file: file,
            line: line, column: column, explanation: explanation, suggestion: suggestion,
            fingerprint: fingerprint
        )
    }

    /// A 64-bit FNV-1a hash, as 16 hex digits, of the rule ID, file path and the
    /// flagged line with whitespace collapsed. Deterministic across machines.
    public static func fingerprint(ruleID: String, file: String, sourceLine: some StringProtocol) -> String {
        let normalized = sourceLine.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "\(ruleID)\u{0}\(file)\u{0}\(normalized)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }
}

extension Finding: Comparable {
    /// Deterministic ordering: file, then position, then rule.
    public static func < (lhs: Finding, rhs: Finding) -> Bool {
        (lhs.file, lhs.line, lhs.column ?? 0, lhs.ruleID)
            < (rhs.file, rhs.line, rhs.column ?? 0, rhs.ruleID)
    }
}
