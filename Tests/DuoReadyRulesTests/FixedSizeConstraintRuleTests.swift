import DuoReadyCore
import DuoReadyRules
import Testing

@Suite("DR005 Constraints that pin content to screen-sized constants")
struct FixedSizeConstraintRuleTests {
    let rule = FixedSizeConstraintRule()

    @Test("Flags screen-sized width and height constants")
    func problematic() {
        let findings = check("""
            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalToConstant: 375),
                card.heightAnchor.constraint(equalToConstant: 667),
            ])
            let c = NSLayoutConstraint(item: card, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 414)
            """)
        #expect(findings.map(\.line) == [2, 3, 5])
        #expect(findings.first?.message == "Fixed width constraint of 375 points assumes the window is at least that wide.")
    }

    @Test("Does not flag constraints relative to the container")
    func corrected() {
        let findings = check("""
            card.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9)
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 600)
            card.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor)
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag small fixed sizes or lowered priorities")
    func exceptions() {
        let findings = check("""
            icon.widthAnchor.constraint(equalToConstant: 44)
            map.heightAnchor.constraint(equalToConstant: 320)
            card.widthAnchor.constraint(equalToConstant: 400).withPriority(.defaultHigh)
            let c = NSLayoutConstraint(item: card, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 1, constant: 400)
            """)
        #expect(findings.isEmpty)
    }

    @Test("Handles optional chaining, floats and #if blocks")
    func edgeCases() {
        let findings = check("""
            let a = view?.widthAnchor.constraint(equalToConstant: 390.0)
            #if os(macOS)
            let b = window.widthAnchor.constraint(equalToConstant: 800)
            #endif
            """)
        #expect(findings.map(\.line) == [1])
    }

    private func check(_ source: String) -> [Finding] {
        rule.check(SwiftSourceFile(relativePath: "Test.swift", source: source))
    }
}
