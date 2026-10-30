import DuoReadyCore
import Foundation

/// Stable, machine-readable output. Keys are sorted so reports diff cleanly.
public struct JSONReporter: Reporter {
    public static let schemaVersion = 1

    struct Report: Encodable {
        struct Tool: Encodable {
            let name: String
            let version: String
        }

        struct Totals: Encodable {
            let filesScanned: Int
            let findings: Int
            let failing: Int
            let failOn: Severity
            let baselineSuppressed: Int
            let staleBaselineEntries: Int
        }

        let schemaVersion: Int
        let tool: Tool
        let summary: Totals
        let findings: [Finding]
        let issues: [ScanIssue]
    }

    public init() {}

    public func render(_ result: ScanResult, failOn threshold: Severity) -> String {
        let report = Report(
            schemaVersion: Self.schemaVersion,
            tool: .init(name: "duoready", version: DuoReady.version),
            summary: .init(
                filesScanned: result.filesScanned,
                findings: result.findings.count,
                failing: result.failingFindings(threshold: threshold).count,
                failOn: threshold,
                baselineSuppressed: result.baselineSuppressed,
                staleBaselineEntries: result.staleBaselineEntries
            ),
            findings: result.findings,
            issues: result.issues
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // Encoding plain value types cannot fail.
        let data = try! encoder.encode(report)
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}
