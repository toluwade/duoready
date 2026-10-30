import Foundation

/// Contents of `.duoready.json`.
public struct ScanConfiguration: Codable, Sendable, Equatable {
    public struct RuleOverride: Codable, Sendable, Equatable {
        public var enabled: Bool?
        public var severity: Severity?

        public init(enabled: Bool? = nil, severity: Severity? = nil) {
            self.enabled = enabled
            self.severity = severity
        }
    }

    public static let currentVersion = 1
    public static let defaultFileName = ".duoready.json"

    public var version: Int
    /// Glob patterns relative to the scan root, e.g. `Vendor/**`.
    public var exclude: [String]
    public var rules: [String: RuleOverride]
    /// Findings at or above this severity make the scan fail.
    public var failOn: Severity
    /// Baseline file, relative to the configuration file's directory.
    public var baseline: String?
    /// Scan test targets and test files too. Off by default, because tests
    /// often fix sizes deliberately.
    public var includeTests: Bool

    public init(
        version: Int = ScanConfiguration.currentVersion,
        exclude: [String] = [],
        rules: [String: RuleOverride] = [:],
        failOn: Severity = .error,
        baseline: String? = nil,
        includeTests: Bool = false
    ) {
        self.version = version
        self.exclude = exclude
        self.rules = rules
        self.failOn = failOn
        self.baseline = baseline
        self.includeTests = includeTests
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        exclude = try container.decodeIfPresent([String].self, forKey: .exclude) ?? []
        rules = try container.decodeIfPresent([String: RuleOverride].self, forKey: .rules) ?? [:]
        failOn = try container.decodeIfPresent(Severity.self, forKey: .failOn) ?? .error
        baseline = try container.decodeIfPresent(String.self, forKey: .baseline)
        includeTests = try container.decodeIfPresent(Bool.self, forKey: .includeTests) ?? false
    }

    public static func load(from url: URL) throws -> ScanConfiguration {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigurationError.unreadable(path: url.path, reason: error.localizedDescription)
        }
        let config: ScanConfiguration
        do {
            config = try JSONDecoder().decode(ScanConfiguration.self, from: data)
        } catch {
            throw ConfigurationError.invalidJSON(path: url.path, reason: String(describing: error))
        }
        guard config.version == currentVersion else {
            throw ConfigurationError.unsupportedVersion(config.version)
        }
        return config
    }

    /// Rejects rule IDs the registry doesn't know, which are almost always typos.
    public func validate(against registry: RuleRegistry) throws {
        let unknown = Set(rules.keys).subtracting(registry.ruleIDs).sorted()
        if !unknown.isEmpty {
            throw ConfigurationError.unknownRules(unknown)
        }
    }

    public func isEnabled(_ ruleID: String) -> Bool {
        rules[ruleID]?.enabled ?? true
    }

    public func severity(for metadata: RuleMetadata) -> Severity {
        rules[metadata.id]?.severity ?? metadata.defaultSeverity
    }
}

public enum ConfigurationError: Error, CustomStringConvertible, Equatable {
    case unreadable(path: String, reason: String)
    case invalidJSON(path: String, reason: String)
    case unsupportedVersion(Int)
    case unknownRules([String])

    public var description: String {
        switch self {
        case let .unreadable(path, reason):
            "Could not read configuration at \(path): \(reason)"
        case let .invalidJSON(path, reason):
            "Configuration at \(path) is not valid: \(reason)"
        case let .unsupportedVersion(version):
            "Configuration version \(version) is not supported (expected \(ScanConfiguration.currentVersion))."
        case let .unknownRules(ids):
            "Configuration references unknown rule IDs: \(ids.joined(separator: ", "))"
        }
    }
}
