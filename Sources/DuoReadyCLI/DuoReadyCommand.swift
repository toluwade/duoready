import ArgumentParser
import DuoReadyCore
import Foundation

/// Documented process exit statuses. CI relies on telling findings apart
/// from a scanner that could not run.
enum ExitStatus: Int32 {
    /// The scan completed with no findings at or above the failure threshold.
    case clean = 0
    /// The scan completed and findings crossed the failure threshold.
    case findings = 1
    /// Invalid arguments or configuration.
    case usage = 2
    /// The project could not be scanned.
    case scanFailure = 3
}

@main
struct DuoReadyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "duoready",
        abstract: "Find adaptive-layout and resizability problems in SwiftUI and UIKit code.",
        version: DuoReady.version,
        subcommands: [ScanCommand.self, BaselineCommand.self, RulesCommand.self, ConfigCommand.self, VersionCommand.self]
    )

    /// Replaces ArgumentParser's default entry point so argument errors exit
    /// with 2 rather than EX_USAGE (64).
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let status as ExitCode {
            Foundation.exit(status.rawValue)
        } catch {
            let code = exitCode(for: error)
            if code == .success {
                // --help and --version.
                print(fullMessage(for: error))
                Foundation.exit(ExitStatus.clean.rawValue)
            }
            FileHandle.standardError.write(Data((fullMessage(for: error) + "\n").utf8))
            Foundation.exit(ExitStatus.usage.rawValue)
        }
    }
}

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "version", abstract: "Print the installed version.")

    func run() {
        print(DuoReady.version)
    }
}

func printError(_ message: String) {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
}

func fail(_ status: ExitStatus, _ message: String) -> ExitCode {
    printError(message)
    return ExitCode(status.rawValue)
}
