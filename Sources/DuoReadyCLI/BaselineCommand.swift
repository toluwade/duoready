import ArgumentParser
import DuoReadyCore
import Foundation

struct BaselineCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "baseline",
        abstract: "Record current findings so scans report only new ones.",
        discussion: """
            Writes every current finding to the baseline file, replacing its contents. Commit the \
            file, then rerun this command whenever you fix baselined findings to keep it small.
            """
    )

    @OptionGroup var project: ProjectOptions

    @Option(name: .shortAndLong, help: "Where to write the baseline. Defaults to the configured baseline, or .duoready-baseline.json in the scanned directory.")
    var output: String?

    func run() throws {
        let loaded = try project.loadConfiguration()
        let result = try project.scan(with: loaded.configuration)

        let url = output.map { URL(fileURLWithPath: $0).standardizedFileURL } ?? project.defaultBaselineURL(for: loaded).url
        let previous = try? Baseline.load(from: url)
        let baseline = Baseline(findings: result.findings)
        do {
            try baseline.encoded().write(to: url, options: .atomic)
        } catch {
            throw fail(.scanFailure, "Could not write baseline to \(url.path): \(error.localizedDescription)")
        }

        let count = baseline.entries.count
        var summary = "Wrote \(count) finding\(count == 1 ? "" : "s") to \(displayPath(url))"
        if let previous {
            summary += " (was \(previous.entries.count))"
        }
        print(summary + ".")
    }

    private func displayPath(_ url: URL) -> String {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).resolvingSymlinksInPath().path + "/"
        let path = url.resolvingSymlinksInPath().path
        return path.hasPrefix(cwd) ? String(path.dropFirst(cwd.count)) : path
    }
}
