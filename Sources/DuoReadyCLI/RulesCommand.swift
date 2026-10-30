import ArgumentParser
import DuoReadyCore
import DuoReadyRules
import Foundation

struct RulesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "rules", abstract: "List available rules.")

    enum Format: String, ExpressibleByArgument {
        case text, json
    }

    @Option(name: .shortAndLong, help: "Output format: text or json.")
    var format: Format = .text

    @Argument(help: "Show full details for this rule ID.")
    var ruleID: String?

    func run() throws {
        var rules = RuleRegistry.builtIn.rules.map(\.metadata)
        if let ruleID {
            rules = rules.filter { $0.id == ruleID.uppercased() }
            guard !rules.isEmpty else { throw fail(.usage, "Unknown rule ID \(ruleID)") }
        }

        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            print(String(decoding: try encoder.encode(rules), as: UTF8.self))
        case .text where ruleID != nil:
            for rule in rules {
                print("""
                    \(rule.id): \(rule.title)
                    Category: \(rule.category.rawValue)   Severity: \(rule.defaultSeverity.rawValue)   Confidence: \(rule.confidence.rawValue)

                    Why: \(rule.rationale)

                    Fix: \(rule.suggestion)

                    Limitations: \(rule.limitations)
                    """)
            }
        case .text:
            for rule in rules {
                let severity = rule.defaultSeverity.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
                print("\(rule.id)  \(severity)  \(rule.title)")
            }
        }
    }
}
