import DuoReadyCore
import DuoReadyRules
import Testing

@Suite("DR002 Layout decisions based on orientation")
struct OrientationLayoutRuleTests {
    let rule = OrientationLayoutRule()

    @Test("Flags orientation in if, guard, switch and ternary conditions")
    func problematic() {
        let findings = check("""
            if UIDevice.current.orientation.isLandscape { stack.axis = .horizontal }
            guard windowScene.interfaceOrientation.isPortrait else { return }
            switch UIApplication.shared.statusBarOrientation {
            case .portrait: columns = 1
            default: columns = 2
            }
            let columns = view.window?.windowScene?.interfaceOrientation == .portrait ? 1 : 2
            """)
        #expect(findings.map(\.line) == [1, 2, 3, 7])
    }

    @Test("Does not flag size-class or bounds-based layout")
    func corrected() {
        let findings = check("""
            if traitCollection.horizontalSizeClass == .regular { stack.axis = .horizontal }
            let columns = view.bounds.width > 600 ? 2 : 1
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag orientation that drives camera or video rotation")
    func mediaRotationException() {
        let findings = check("""
            switch UIDevice.current.orientation {
            case .landscapeLeft: connection.videoOrientation = .landscapeRight
            default: connection.videoOrientation = .portrait
            }
            if UIDevice.current.orientation == .portrait {
                connection.videoRotationAngle = 90
            }
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag orientation outside a condition")
    func notADecision() {
        let findings = check("""
            let orientation = UIDevice.current.orientation
            logger.log("orientation: \\(UIDevice.current.orientation)")
            let cols = isWide ? UIDevice.current.orientation : nil
            let other = device.orientation == .portrait ? 1 : 2
            """)
        #expect(findings.isEmpty)
    }

    @Test("Flags conditions inside nested closures and #if blocks")
    func edgeCases() {
        let findings = check("""
            #if os(iOS)
            DispatchQueue.main.async {
                if case .landscapeLeft = UIDevice.current.orientation { self.relayout() }
            }
            #endif
            """)
        #expect(findings.map(\.line) == [3])
    }

    private func check(_ source: String) -> [Finding] {
        rule.check(SwiftSourceFile(relativePath: "Test.swift", source: source))
    }
}
