import ArgumentParser
import DuoReadyCore
import DuoReadyReporters
import Foundation

extension ReportFormat: ExpressibleByArgument {}
extension Severity: ExpressibleByArgument {}

struct ScanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan a project directory or Swift file.",
        discussion: """
            Findings recorded in a baseline are hidden and never fail the scan. The baseline is \
            the configured `baseline` file, or .duoready-baseline.json in the scanned directory.

            Exit status: 0 no failing findings, 1 findings at or above the threshold, \
            2 invalid arguments or configuration, 3 the project could not be scanned.
            """
    )

    @OptionGroup var project: ProjectOptions

    @Option(name: .shortAndLong, help: "Output format: text, json or github.")
    var format: ReportFormat = .text

    @Option(name: .shortAndLong, help: "Fail when findings are at or above this severity: info, warning or error. Overrides failOn in the configuration.")
    var severity: Severity?

    @Option(name: .shortAndLong, help: "Write the report to this file instead of standard output.")
    var output: String?

    @Option(help: "Baseline file to apply. Overrides the configured or default baseline.")
    var baseline: String?

    @Flag(help: "Report every finding, ignoring any baseline.")
    var noBaseline = false

    @Flag(help: "Include each rule's explanation in text output.")
    var explain = false

    func validate() throws {
        if baseline != nil, noBaseline {
            throw ValidationError("--baseline and --no-baseline can't be used together.")
        }
    }

    func run() throws {
        let loaded = try project.loadConfiguration()
        var result = try project.scan(with: loaded.configuration)
        if let baseline = try loadBaseline(loaded) {
            result = result.applying(baseline)
        }

        let threshold = severity ?? loaded.configuration.failOn
        let report = reporter().render(result, failOn: threshold)
        if let output {
            do {
                try report.write(toFile: output, atomically: true, encoding: .utf8)
            } catch {
                throw fail(.scanFailure, "Could not write report to \(output): \(error.localizedDescription)")
            }
        } else {
            print(report, terminator: "")
        }

        if !result.failingFindings(threshold: threshold).isEmpty {
            throw ExitCode(ExitStatus.findings.rawValue)
        }
    }

    /// An explicit or configured baseline must exist. The default file is
    /// optional, so projects without a baseline need no setup.
    private func loadBaseline(_ loaded: ProjectOptions.LoadedConfiguration) throws -> Baseline? {
        guard !noBaseline else { return nil }
        let url: URL
        if let baseline {
            url = URL(fileURLWithPath: baseline).standardizedFileURL
        } else {
            let resolved = project.defaultBaselineURL(for: loaded)
            guard resolved.configured || FileManager.default.fileExists(atPath: resolved.url.path) else { return nil }
            url = resolved.url
        }
        do {
            return try Baseline.load(from: url)
        } catch let error as BaselineError {
            throw fail(.usage, error.description)
        }
    }

    private func reporter() -> any Reporter {
        switch format {
        case .text: TextReporter(includeExplanations: explain)
        case .json: JSONReporter()
        case .github: GitHubReporter(pathPrefix: repositoryRelativePrefix())
        }
    }

    /// The scan root relative to the working directory (the checkout root in
    /// GitHub Actions), so annotation paths resolve against the repository.
    private func repositoryRelativePrefix() -> String {
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).resolvingSymlinksInPath().path
        let path = project.rootDirectory.resolvingSymlinksInPath().path
        guard path.hasPrefix(base + "/") else { return "" }
        return String(path.dropFirst(base.count + 1))
    }
}
