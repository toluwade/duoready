import DuoReadyCore
import DuoReadyRules
import Testing

@Suite("DR006 SwiftUI frames with screen-sized fixed dimensions")
struct FixedFrameRuleTests {
    let rule = FixedFrameRule()

    @Test("Flags screen-sized fixed widths and heights")
    func problematic() {
        let findings = check("""
            struct Card: View {
                var body: some View {
                    Image("hero")
                        .frame(width: 390, height: 844)
                    Text("Hi").frame(width: 320)
                }
            }
            """)
        #expect(findings.map(\.line) == [4, 4, 5])
        #expect(findings.map(\.column) == [20, 32, 26])
        #expect(findings.first?.message == "Fixed frame width of 390 points won't adapt to smaller windows.")
    }

    @Test("Does not flag flexible or capped frames")
    func corrected() {
        let findings = check("""
            Image("hero").frame(maxWidth: .infinity, maxHeight: 600)
            Text("Hi").frame(minWidth: 400, idealWidth: 500)
            Image("hero").containerRelativeFrame(.horizontal)
            """)
        #expect(findings.isEmpty)
    }

    @Test("Does not flag small frames or previews")
    func exceptions() {
        let findings = check("""
            Image(systemName: "star").frame(width: 44, height: 44)
            Chart().frame(height: 300)
            #Preview {
                ContentView().frame(width: 393, height: 852)
            }
            struct ContentView_Previews: PreviewProvider {
                static var previews: some View {
                    ContentView().frame(width: 375, height: 667)
                }
            }
            """)
        #expect(findings.isEmpty)
    }

    @Test("Handles multi-line modifiers, floats and non-iOS #if blocks")
    func edgeCases() {
        let findings = check("""
            Text("Hi")
                .frame(
                    width: 400.5
                )
            #if os(macOS)
            Settings().frame(width: 600, height: 700)
            #endif
            """)
        #expect(findings.map(\.line) == [3])
    }

    private func check(_ source: String) -> [Finding] {
        rule.check(SwiftSourceFile(relativePath: "Test.swift", source: source))
    }
}
