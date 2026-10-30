import DuoReadyCore
import DuoReadyRules
import Testing

@Suite("DR004 Fixed screen dimensions used for layout decisions")
struct FixedScreenDimensionRuleTests {
    let rule = FixedScreenDimensionRule()

    @Test("Flags device detection by screen size")
    func problematic() {
        let findings = check("""
            if view.bounds.height == 812 { topInset = 44 }
            let hasNotch = UIScreen.main.bounds.height >= 812
            if screenWidth < 375 { font = .small }
            switch UIScreen.main.nativeBounds.height {
            case 1136: break
            case 568: model = .se
            case 667, 736: model = .plus
            default: break
            }
            """)
        #expect(findings.map(\.line) == [1, 2, 3, 6, 7, 7])
        #expect(findings.first?.message == "view.bounds.height == 812 matches a specific device's screen size of 812 points.")
    }

    @Test("Does not flag breakpoints on the view's own size")
    func corrected() {
        let findings = check("""
            if view.bounds.width > 600 { stack.axis = .horizontal }
            let isCompact = size.width < 500
            if containerWidth >= 768 { columns = 3 }
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag device numbers that aren't dimensions")
    func lookalikes() {
        let findings = check("""
            if retryCount == 375 { stop() }
            let isLarge = itemCount > 812
            if bounds.width == 100 { hide() }
            switch statusCode { case 320: break; default: break }
            #expect(thumbnail?.width == 320)
            if image.size.height == 812 { useLargeAsset() }
            switch photo.width { case 375: break; default: break }
            """)
        #expect(findings.isEmpty)
    }

    @Test("Flags device detection through a geometry proxy")
    func geometryProxy() {
        let findings = check("""
            GeometryReader { geometry in
                if geometry.size.width == 375 { CompactView() }
            }
            """)
        #expect(findings.map(\.line) == [2])
    }

    @Test("Handles reversed operands, floats, compound conditions and #if")
    func edgeCases() {
        let findings = check("""
            if 812.0 == view.frame.size.height && isVisible { adjust() }
            #if os(macOS)
            if window.frame.width == 1024 { adjust() }
            #endif
            """)
        #expect(findings.map(\.line) == [1])
    }

    private func check(_ source: String) -> [Finding] {
        rule.check(SwiftSourceFile(relativePath: "Test.swift", source: source))
    }
}
