import ArgumentParser
import DuoReadyCore
import DuoReadyRules
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Create or check a .duoready.json configuration file.",
        subcommands: [Init.self, Validate.self]
    )

    struct Init: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Write a starter configuration file.")

        @Argument(help: "Where to write the file.")
        var path: String = ScanConfiguration.defaultFileName

        @Flag(help: "Replace an existing file.")
        var force = false

        func run() throws {
            if FileManager.default.fileExists(atPath: path), !force {
                throw fail(.usage, "\(path) already exists. Pass --force to replace it.")
            }
            let starter = ScanConfiguration(
                exclude: ["Pods/**", "Carthage/**", "DerivedData/**", "build/**", "Vendor/**"],
                rules: Dictionary(uniqueKeysWithValues: RuleRegistry.builtIn.rules.map {
                    ($0.metadata.id, ScanConfiguration.RuleOverride(enabled: true, severity: $0.metadata.defaultSeverity))
                }),
                failOn: .error
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            do {
                try (try encoder.encode(starter) + Data("\n".utf8)).write(to: URL(fileURLWithPath: path))
            } catch {
                throw fail(.scanFailure, "Could not write \(path): \(error.localizedDescription)")
            }
            print("Wrote \(path)")
        }
    }

    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Check a configuration file for errors.")

        @Argument(help: "The file to check.")
        var path: String = ScanConfiguration.defaultFileName

        func run() throws {
            do {
                try ScanConfiguration.load(from: URL(fileURLWithPath: path)).validate(against: .builtIn)
            } catch let error as ConfigurationError {
                throw fail(.usage, error.description)
            }
            print("\(path) is valid.")
        }
    }
}
