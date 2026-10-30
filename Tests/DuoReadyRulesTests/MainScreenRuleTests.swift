import DuoReadyCore
@testable import DuoReadyRules
import Testing

@Suite("DR001 UIScreen.main usage")
struct MainScreenRuleTests {
    let rule = MainScreenRule()

    @Test("Flags UIScreen.main and reports its position")
    func problematic() {
        let findings = check("""
            import UIKit
            let width = UIScreen.main.bounds.width
            """)
        #expect(findings.count == 1)
        #expect(findings.first?.line == 2)
        #expect(findings.first?.column == 13)
        #expect(findings.first?.message == "UIScreen.main.bounds assumes a single, fixed screen.")
    }

    @Test("Does not flag geometry read from the view or scene")
    func corrected() {
        let findings = check("""
            override func viewDidLayoutSubviews() {
                let width = view.bounds.width
                let scale = traitCollection.displayScale
                let screen = view.window?.windowScene?.screen
            }
            """)
        #expect(findings.isEmpty)
    }

    @Test("Ignores lookalikes: other types' main, strings and comments")
    func lookalikes() {
        let findings = check("""
            let queue = DispatchQueue.main
            let bundle = Bundle.main
            let text = "UIScreen.main"
            // UIScreen.main is deprecated
            let screen = MyScreen.main
            """)
        #expect(findings.isEmpty)
    }

    @Test("Handles module-qualified access, line breaks and #if blocks")
    func edgeCases() {
        let findings = check("""
            #if os(iOS)
            let a = UIKit.UIScreen.main.scale
            #endif
            let b = UIScreen
                .main
                .nativeBounds
            """)
        #expect(findings.map(\.line) == [2, 4])
    }

    @Test("Tailors the fix to the member being read", arguments: [
        ("bounds", "containing view"),
        ("scale", "displayScale"),
        ("brightness", "windowScene?.screen"),
    ])
    func tailoredSuggestion(member: String, expected: String) {
        let finding = check("let x = UIScreen.main.\(member)").first
        #expect(finding?.suggestion?.contains(expected) == true)
    }

    private func check(_ source: String) -> [Finding] {
        rule.check(SwiftSourceFile(relativePath: "Test.swift", source: source))
    }
}
