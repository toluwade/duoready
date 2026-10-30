import DuoReadyCore
import DuoReadyRules
import Foundation
import Testing

@Suite("Rule catalogue")
struct RuleCatalogTests {
    @Test("Every built-in rule has complete metadata and a well-formed ID")
    func metadataIsComplete() {
        for rule in RuleRegistry.builtIn.rules {
            let meta = rule.metadata
            #expect(meta.id.wholeMatch(of: /DR\d{3}/) != nil, "\(meta.id)")
            #expect(!meta.title.isEmpty)
            #expect(!meta.rationale.isEmpty)
            #expect(!meta.suggestion.isEmpty)
            #expect(!meta.limitations.isEmpty)
        }
    }

    @Test("RULES.md documents every built-in rule")
    func rulesAreDocumented() throws {
        let rulesDoc = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RULES.md")
        let text = try String(contentsOf: rulesDoc, encoding: .utf8)
        for id in RuleRegistry.builtIn.ruleIDs {
            #expect(text.contains("## \(id)"), "RULES.md is missing a section for \(id)")
        }
    }
}
