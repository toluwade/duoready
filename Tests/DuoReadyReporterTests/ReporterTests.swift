import DuoReadyCore
@testable import DuoReadyReporters
import Foundation
import Testing

@Suite("Reporters")
struct ReporterTests {
    let result = ScanResult(
        findings: [
            Finding(
                ruleID: "DR001", severity: .warning, message: "UIScreen.main, 100% fixed.",
                file: "App/View, Main.swift", line: 4, column: 17,
                explanation: "Why.", suggestion: "Use view.bounds."
            ),
            Finding(
                ruleID: "DR002", severity: .info, message: "Orientation.",
                file: "App/Other.swift", line: 9, column: nil,
                explanation: "Why.", suggestion: nil
            ),
        ],
        issues: [],
        filesScanned: 3
    )

    @Test("Text output is compiler-style with a summary")
    func text() {
        let output = TextReporter().render(result, failOn: .warning)
        #expect(output.contains("App/View, Main.swift:4:17: warning: [DR001] UIScreen.main, 100% fixed.\n    Fix: Use view.bounds."))
        #expect(output.contains("App/Other.swift:9: info: [DR002] Orientation."))
        #expect(output.contains("Scanned 3 files: 1 warning, 1 info."))
        #expect(output.contains("1 finding at or above 'warning'; failing."))
    }

    @Test("JSON output round-trips findings")
    func json() throws {
        let output = JSONReporter().render(result, failOn: .error)
        let object = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
        let summary = try #require(object["summary"] as? [String: Any])
        #expect(summary["failing"] as? Int == 0)
        #expect(summary["findings"] as? Int == 2)
        let findings = try #require(object["findings"] as? [[String: Any]])
        #expect(findings.first?["ruleID"] as? String == "DR001")
    }

    @Test("GitHub annotations escape properties and data")
    func github() {
        let output = GitHubReporter(pathPrefix: "ios").render(result, failOn: .error)
        let lines = output.split(separator: "\n")
        #expect(lines[0] == "::warning file=ios/App/View%2C Main.swift,line=4,col=17,title=DuoReady DR001::UIScreen.main, 100%25 fixed.%0AFix: Use view.bounds.")
        #expect(lines[1] == "::notice file=ios/App/Other.swift,line=9,title=DuoReady DR002::Orientation.")
    }

    @Test("Text and GitHub output describe the baseline")
    func baselineNotes() {
        let baselined = ScanResult(findings: [], issues: [], filesScanned: 2, baselineSuppressed: 3, staleBaselineEntries: 1)
        let expected = """
            Scanned 2 files: no new findings.
            3 existing findings are hidden by the baseline.
            1 baseline entry no longer matches any finding. Run `duoready baseline` to remove it.

            """
        #expect(TextReporter().render(baselined, failOn: .error) == expected)
        #expect(GitHubReporter().render(baselined, failOn: .error) == expected)
    }

    @Test("Summary handles an empty scan")
    func emptySummary() {
        let empty = ScanResult(findings: [], issues: [], filesScanned: 1)
        #expect(TextReporter().render(empty, failOn: .error) == "Scanned 1 file: no findings.\n")
    }
}
