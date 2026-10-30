import Foundation

/// Finds the Swift files a scan should read.
///
/// Scanned repositories are untrusted input (pull requests in CI), so this
/// never follows symbolic links and skips unreasonably large files.
public struct FileEnumerator: Sendable {
    /// Directory names that hold generated or third-party code in typical iOS repos.
    public static let defaultExcludedDirectories: Set<String> = [
        ".build", ".git", ".swiftpm", "build", "Carthage", "DerivedData", "Pods", "node_modules",
    ]
    public static let maximumFileSize = 4 * 1024 * 1024

    public struct Candidate: Sendable, Equatable {
        public let url: URL
        public let relativePath: String
    }

    private let excludes: [GlobPattern]
    private let includeTests: Bool

    public init(excludePatterns: [String], includeTests: Bool = false) throws {
        excludes = try excludePatterns.map(GlobPattern.init)
        self.includeTests = includeTests
    }

    /// Test targets and helpers, e.g. `Tests/`, `AppTests/`, `AppUITests/`, `TestHelpers/`.
    /// Tests often pin sizes on purpose (snapshot tests, fixtures), so their
    /// findings are mostly noise.
    /// Suffixes are matched case-sensitively so `Contests/` stays app code.
    static func isTestDirectory(_ name: String) -> Bool {
        ["tests", "test", "specs", "testhelpers", "testsupport", "testutilities", "fixtures", "mocks"]
            .contains(name.lowercased())
            || name.hasSuffix("Tests") || name.hasSuffix("Specs")
    }

    /// Test files outside a test directory, e.g. `ProfileViewTests.swift`.
    /// `Contest.swift` and `Manifest.swift` are not matched.
    static func isTestFile(_ name: String) -> Bool {
        let stem = (name as NSString).deletingPathExtension
        return ["Tests", "Test", "Spec", "Specs"].contains { stem.hasSuffix($0) }
    }

    /// Everything a scan reads, each list sorted by path.
    public struct Discovery: Sendable {
        public var swiftFiles: [Candidate] = []
        /// `.plist` files, such as Info.plist.
        public var propertyLists: [Candidate] = []
        /// `project.pbxproj` files, which hold Xcode build settings.
        public var projectFiles: [Candidate] = []
        public var skipped: [ScanIssue] = []
    }

    public func discover(in root: URL) throws -> Discovery {
        let root = root.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
            throw ScanError.pathNotFound(root.path)
        }

        // A single file can be scanned directly.
        if !isDirectory.boolValue {
            guard root.pathExtension == "swift" else { throw ScanError.notASwiftFile(root.path) }
            return Discovery(swiftFiles: [Candidate(url: root, relativePath: root.lastPathComponent)])
        }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants]
        ) else {
            throw ScanError.unreadableDirectory(root.path)
        }

        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        var discovery = Discovery()

        for case let url as URL in enumerator {
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(rootPrefix) else { continue }
            let relativePath = String(path.dropFirst(rootPrefix.count))
            let values = try? url.resourceValues(forKeys: Set(keys))

            if values?.isSymbolicLink == true {
                if values?.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            if values?.isDirectory == true {
                if Self.defaultExcludedDirectories.contains(url.lastPathComponent)
                    || (!includeTests && Self.isTestDirectory(url.lastPathComponent))
                    || isExcluded(relativePath + "/")
                {
                    enumerator.skipDescendants()
                } else if url.pathExtension == "xcodeproj" {
                    // Xcode projects are packages, so the enumerator doesn't enter them.
                    let project = url.appendingPathComponent("project.pbxproj")
                    if FileManager.default.fileExists(atPath: project.path) {
                        discovery.projectFiles.append(Candidate(url: project, relativePath: relativePath + "/project.pbxproj"))
                    }
                }
                continue
            }
            guard values?.isRegularFile == true, ["swift", "plist"].contains(url.pathExtension) else { continue }
            guard !isExcluded(relativePath) else { continue }
            if !includeTests, Self.isTestFile(url.lastPathComponent) { continue }
            if let size = values?.fileSize, size > Self.maximumFileSize {
                discovery.skipped.append(ScanIssue(file: relativePath, message: "Skipped: file is larger than \(Self.maximumFileSize / 1024 / 1024) MB."))
                continue
            }
            let candidate = Candidate(url: url, relativePath: relativePath)
            if url.pathExtension == "swift" {
                discovery.swiftFiles.append(candidate)
            } else {
                discovery.propertyLists.append(candidate)
            }
        }

        discovery.swiftFiles.sort { $0.relativePath < $1.relativePath }
        discovery.propertyLists.sort { $0.relativePath < $1.relativePath }
        discovery.projectFiles.sort { $0.relativePath < $1.relativePath }
        return discovery
    }

    private func isExcluded(_ relativePath: String) -> Bool {
        excludes.contains { $0.matches(relativePath) }
    }
}
