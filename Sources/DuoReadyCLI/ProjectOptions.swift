import ArgumentParser
import DuoReadyCore
import DuoReadyRules
import Foundation

/// Arguments shared by every command that scans a project.
struct ProjectOptions: ParsableArguments {
    @Argument(help: "Directory or .swift file to scan.")
    var path: String = "."

    @Option(name: .shortAndLong, help: "Configuration file. Defaults to .duoready.json in the scanned directory, if present.")
    var config: String?

    var root: URL {
        URL(fileURLWithPath: path).standardizedFileURL
    }

    /// The scanned directory, or the directory containing the scanned file.
    var rootDirectory: URL {
        isDirectory(root) ? root : root.deletingLastPathComponent()
    }

    struct LoadedConfiguration {
        let configuration: ScanConfiguration
        /// Directory the configuration file is in, which relative paths inside it resolve against.
        let directory: URL
    }

    func loadConfiguration() throws -> LoadedConfiguration {
        let url: URL
        if let config {
            url = URL(fileURLWithPath: config).standardizedFileURL
        } else {
            url = rootDirectory.appendingPathComponent(ScanConfiguration.defaultFileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return LoadedConfiguration(configuration: ScanConfiguration(), directory: rootDirectory)
            }
        }
        do {
            let configuration = try ScanConfiguration.load(from: url)
            try configuration.validate(against: .builtIn)
            return LoadedConfiguration(configuration: configuration, directory: url.deletingLastPathComponent())
        } catch let error as ConfigurationError {
            throw fail(.usage, error.description)
        }
    }

    /// Where the baseline lives: the configured `baseline` path, else
    /// `.duoready-baseline.json` in the scanned directory.
    func defaultBaselineURL(for loaded: LoadedConfiguration) -> (url: URL, configured: Bool) {
        if let configured = loaded.configuration.baseline {
            return (URL(fileURLWithPath: configured, relativeTo: loaded.directory).standardizedFileURL, true)
        }
        return (rootDirectory.appendingPathComponent(Baseline.defaultFileName), false)
    }

    func scan(with configuration: ScanConfiguration) throws -> ScanResult {
        do {
            return try Scanner(registry: .builtIn, configuration: configuration).scan(root: root)
        } catch let error as ScanError {
            throw fail(.scanFailure, error.description)
        }
    }
}

func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
}
