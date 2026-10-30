@testable import DuoReadyCore
import Foundation
import Testing

@Suite("Baseline")
struct BaselineTests {
    func finding(_ ruleID: String = "DR001", file: String = "A.swift", line: Int, text: String) -> Finding {
        Finding(
            ruleID: ruleID, severity: .warning, message: "m", file: file, line: line, column: 1,
            explanation: "e", suggestion: nil,
            fingerprint: Finding.fingerprint(ruleID: ruleID, file: file, sourceLine: text)
        )
    }

    @Test("Hides baselined findings even after their line number changes")
    func survivesLineShifts() {
        let baseline = Baseline(findings: [finding(line: 4, text: "let w = UIScreen.main.bounds.width")])
        let moved = finding(line: 40, text: "let w = UIScreen.main.bounds.width")
        let result = baseline.apply(to: [moved])
        #expect(result.remaining.isEmpty)
        #expect(result.suppressedCount == 1)
        #expect(result.staleEntries.isEmpty)
    }

    @Test("Reports findings on edited lines, other files or other rules as new")
    func newFindings() {
        let baseline = Baseline(findings: [finding(line: 4, text: "let w = UIScreen.main.bounds.width")])
        let edited = finding(line: 4, text: "let width = UIScreen.main.bounds.width")
        let otherFile = finding(file: "B.swift", line: 4, text: "let w = UIScreen.main.bounds.width")
        let otherRule = finding("DR004", line: 4, text: "let w = UIScreen.main.bounds.width")
        let result = baseline.apply(to: [edited, otherFile, otherRule])
        #expect(result.remaining.count == 3)
        #expect(result.staleEntries.count == 1)
    }

    @Test("Each entry absorbs one finding, so a duplicate of a baselined problem is new")
    func multiplicity() {
        let text = "x = UIScreen.main.scale"
        let baseline = Baseline(findings: [finding(line: 1, text: text)])
        let result = baseline.apply(to: [finding(line: 1, text: text), finding(line: 9, text: text)])
        #expect(result.remaining.map(\.line) == [9])
        #expect(result.suppressedCount == 1)
    }

    @Test("Fingerprints ignore indentation, spacing and CRLF line endings")
    func normalization() {
        let a = Finding.fingerprint(ruleID: "DR001", file: "A.swift", sourceLine: "    let  w = UIScreen.main\r")
        let b = Finding.fingerprint(ruleID: "DR001", file: "A.swift", sourceLine: "let w = UIScreen.main")
        #expect(a == b)
        #expect(a.count == 16)
    }

    @Test("Files are sorted and round-trip unchanged")
    func encoding() throws {
        let baseline = Baseline(findings: [
            finding(file: "B.swift", line: 2, text: "b"),
            finding(file: "A.swift", line: 9, text: "a2"),
            finding(file: "A.swift", line: 1, text: "a1"),
        ])
        #expect(baseline.entries.map { "\($0.file):\($0.line)" } == ["A.swift:1", "A.swift:9", "B.swift:2"])

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("baseline-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try baseline.encoded().write(to: url)
        let loaded = try Baseline.load(from: url)
        #expect(loaded == baseline)
        #expect(loaded.encoded() == baseline.encoded())
    }

    @Test("Rejects unsupported versions")
    func version() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("baseline-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"version": 9, "findings": []}"#.utf8).write(to: url)
        #expect(throws: BaselineError.unsupportedVersion(9)) {
            try Baseline.load(from: url)
        }
    }

    @Test("Scan results carry suppressed and stale counts")
    func applyingToResult() {
        let kept = finding(line: 1, text: "kept")
        let result = ScanResult(findings: [kept, finding(line: 2, text: "new")], issues: [], filesScanned: 1)
        let baseline = Baseline(findings: [kept, finding(line: 3, text: "fixed")])
        let applied = result.applying(baseline)
        #expect(applied.findings.map(\.line) == [2])
        #expect(applied.baselineSuppressed == 1)
        #expect(applied.staleBaselineEntries == 1)
    }
}
