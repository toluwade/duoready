/// The set of rules a scan can run, keyed by stable rule ID.
public struct RuleRegistry: Sendable {
    public let rules: [any SwiftRule]

    public init(rules: [any SwiftRule]) {
        var seen = Set<String>()
        for rule in rules {
            precondition(seen.insert(rule.metadata.id).inserted, "Duplicate rule ID \(rule.metadata.id)")
        }
        self.rules = rules.sorted { $0.metadata.id < $1.metadata.id }
    }

    public var ruleIDs: Set<String> { Set(rules.map(\.metadata.id)) }

    public func rule(withID id: String) -> (any SwiftRule)? {
        rules.first { $0.metadata.id == id }
    }
}
