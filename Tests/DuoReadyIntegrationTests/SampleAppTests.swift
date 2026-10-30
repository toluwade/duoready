import DuoReadyCore
import DuoReadyRules
import Foundation
import Testing

/// End-to-end scan of a small fixture app with its own `.duoready.json`.
@Suite("Sample app scan")
struct SampleAppTests {
    let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/SampleApp")

    func scan() throws -> ScanResult {
        let configuration = try ScanConfiguration.load(from: root.appendingPathComponent(".duoready.json"))
        try configuration.validate(against: .builtIn)
        return try Scanner(registry: .builtIn, configuration: configuration).scan(root: root)
    }

    @Test("Produces exactly the expected findings, in order")
    func goldenFindings() throws {
        let result = try scan()
        let summary = result.findings.map { "\($0.file):\($0.line) \($0.ruleID) \($0.severity.rawValue)" }
        #expect(summary == [
            "Views/CheckoutViewController.swift:8 DR004 warning",
            "Views/CheckoutViewController.swift:10 DR005 warning",
            "Views/GalleryViewController.swift:8 DR001 warning",
            "Views/GalleryViewController.swift:10 DR002 error",
            "Views/LegacyBanner.swift:5 DR001 warning",
            "Views/OnboardingView.swift:5 DR003 warning",
            "Views/OnboardingView.swift:7 DR006 info",
        ])
        #expect(result.filesScanned == 6)
        #expect(result.failingFindings(threshold: .error).count == 1)
    }

    @Test("A baseline of the current findings hides all of them")
    func baselineRoundTrip() throws {
        let result = try scan()
        let applied = result.applying(Baseline(findings: result.findings))
        #expect(applied.findings.isEmpty)
        #expect(applied.baselineSuppressed == result.findings.count)
        #expect(applied.staleBaselineEntries == 0)
    }

    @Test("Repeated scans are identical")
    func deterministic() throws {
        #expect(try scan().findings == scan().findings)
    }
}
