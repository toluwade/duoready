@testable import DuoReadyCore
import Foundation
import Testing

/// Flags every `fixme()` call; used to exercise the scanner without real rules.
struct FixmeRule: SwiftRule {
    let metadata = RuleMetadata(
        id: "DR900", title: "Test rule", category: .shared, defaultSeverity: .warning,
        confidence: .high, rationale: "Because.", suggestion: "Don't.", limitations: "None."
    )

    func check(_ file: SwiftSourceFile) -> [Finding] {
        file.tree.tokens(viewMode: .sourceAccurate)
            .filter { $0.text == "fixme" }
            .map { finding(at: $0, in: file, message: "fixme") }
    }
}

@Suite("Glob patterns")
struct GlobPatternTests {
    @Test(arguments: [
        ("Pods/**", "Pods/Alamofire/Source/Request.swift", true),
        ("Pods/**", "App/Pods.swift", false),
        ("**/Generated/**", "App/Generated/Assets.swift", true),
        ("**/Generated/**", "Generated/Assets.swift", true),
        ("*.generated.swift", "App/Deep/L10n.generated.swift", true),
        ("App/*.swift", "App/Main.swift", true),
        ("App/*.swift", "App/Views/Main.swift", false),
        ("Vendor/", "Vendor/Lib/File.swift", true),
        ("File?.swift", "File1.swift", true),
        ("a+b.swift", "a+b.swift", true),
    ])
    func matching(pattern: String, path: String, expected: Bool) throws {
        #expect(try GlobPattern(pattern).matches(path) == expected)
    }
}

@Suite("Configuration")
struct ConfigurationTests {
    let registry = RuleRegistry(rules: [FixmeRule()])

    @Test("Missing keys fall back to defaults")
    func defaults() throws {
        let config = try JSONDecoder().decode(ScanConfiguration.self, from: Data(#"{"version": 1}"#.utf8))
        #expect(config == ScanConfiguration())
    }

    @Test("Unknown rule IDs are rejected")
    func unknownRules() throws {
        let config = ScanConfiguration(rules: ["DR999": .init(enabled: false)])
        #expect(throws: ConfigurationError.unknownRules(["DR999"])) {
            try config.validate(against: registry)
        }
    }

    @Test("Unsupported versions are rejected")
    func version() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("duoready-\(UUID()).json")
        try Data(#"{"version": 2}"#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: ConfigurationError.unsupportedVersion(2)) {
            try ScanConfiguration.load(from: url)
        }
    }
}

@Suite("Scanner")
struct ScannerTests {
    let registry = RuleRegistry(rules: [FixmeRule()])

    @Test("Applies severity overrides and disabled rules")
    func overrides() {
        let file = SwiftSourceFile(relativePath: "A.swift", source: "fixme()")
        let raised = Scanner(registry: registry, configuration: .init(rules: ["DR900": .init(severity: .error)]))
        #expect(raised.scan(file: file).map(\.severity) == [.error])

        let disabled = Scanner(registry: registry, configuration: .init(rules: ["DR900": .init(enabled: false)]))
        #expect(disabled.scan(file: file).isEmpty)
    }

    @Test("Honours inline suppressions")
    func suppressions() {
        let file = SwiftSourceFile(relativePath: "A.swift", source: """
            fixme() // duoready:ignore DR900
            // duoready:ignore
            fixme()
            fixme() // duoready:ignore DR001
            // duoready:ignore DR900
            let spacer = 0
            fixme()
            """)
        #expect(Scanner(registry: registry).scan(file: file).map(\.line) == [4, 7])
    }

    @Test("Walks directories deterministically, skipping excluded and generated code")
    func discovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("duoready-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        for path in ["b/B.swift", "a/A.swift", "Pods/P/P.swift", "Vendor/V.swift", "a/notes.txt", ".build/X.swift"] {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("fixme()".utf8).write(to: url)
        }
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("link"), withDestinationURL: root.appendingPathComponent("a")
        )

        let result = try Scanner(registry: registry, configuration: .init(exclude: ["Vendor/**"])).scan(root: root)
        #expect(result.filesScanned == 2)
        #expect(result.findings.map(\.file) == ["a/A.swift", "b/B.swift"])
    }

    @Test("Reports a missing path as a scan error")
    func missingPath() {
        #expect(throws: ScanError.self) {
            try Scanner(registry: registry).scan(root: URL(fileURLWithPath: "/definitely/not/here"))
        }
    }

    @Test("Severity ordering supports thresholds")
    func severityOrdering() {
        #expect(Severity.info < .warning && Severity.warning < .error)
    }
}
