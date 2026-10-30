import DuoReadyCore
import DuoReadyRules
import Testing

@Suite("DR003 Device-type checks used to select layout dimensions")
struct DeviceIdiomLayoutRuleTests {
    let rule = DeviceIdiomLayoutRule()

    @Test("Flags idiom checks that pick sizes, spacing or columns")
    func problematic() {
        let findings = check("""
            if UIDevice.current.userInterfaceIdiom == .pad {
                layout.itemSize = CGSize(width: 300, height: 300)
            }
            let padding: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 40 : 16
            switch traitCollection.userInterfaceIdiom {
            case .phone: stack.spacing = 8
            default: stack.spacing = 24
            }
            guard UIDevice.current.userInterfaceIdiom == .phone else { columns = 3; return }
            """)
        #expect(findings.map(\.line) == [1, 4, 5, 9])
    }

    @Test("Does not flag size-class based layout")
    func corrected() {
        let findings = check("""
            if traitCollection.horizontalSizeClass == .regular {
                layout.itemSize = CGSize(width: 300, height: 300)
            }
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag idiom checks for features or presentation")
    func featureChecks() {
        let findings = check("""
            if UIDevice.current.userInterfaceIdiom == .pad {
                controller.modalPresentationStyle = .popover
            }
            let supportsHaptics = UIDevice.current.userInterfaceIdiom == .phone ? true : false
            if UIDevice.current.userInterfaceIdiom == .mac { configureMenuBar(width: 200) }
            let idiom = UIDevice.current.userInterfaceIdiom
            """)
        #expect(findings.isEmpty)
    }

    @Test("Handles optional chaining, closures and non-iOS #if blocks")
    func edgeCases() {
        let findings = check("""
            DispatchQueue.main.async {
                if self.view.window?.traitCollection.userInterfaceIdiom == .pad { self.widthConstraint.constant = 500 }
            }
            #if os(macOS)
            if NSApp.userInterfaceIdiom == .pad { width = 1 }
            #endif
            """)
        #expect(findings.map(\.line) == [2])
    }

    private func check(_ source: String) -> [Finding] {
        rule.check(SwiftSourceFile(relativePath: "Test.swift", source: source))
    }
}
