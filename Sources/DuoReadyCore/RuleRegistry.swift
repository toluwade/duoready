/// The set of rules a scan can run, keyed by stable rule ID.
public struct RuleRegistry: Sendable {
    /// Every rule, sorted by ID.
    public let rules: [any Rule]

    public init(rules: [any Rule]) {
        var seen = Set<String>()
        for rule in rules {
            precondition(rule is any SwiftRule || rule is any ProjectRule, "\(rule.metadata.id) is neither a SwiftRule nor a ProjectRule")
            precondition(seen.insert(rule.metadata.id).inserted, "Duplicate rule ID \(rule.metadata.id)")
        }
        self.rules = rules.sorted { $0.metadata.id < $1.metadata.id }
    }

    public var swiftRules: [any SwiftRule] { rules.compactMap { $0 as? any SwiftRule } }
    public var projectRules: [any ProjectRule] { rules.compactMap { $0 as? any ProjectRule } }

    public var ruleIDs: Set<String> { Set(rules.map(\.metadata.id)) }
}
