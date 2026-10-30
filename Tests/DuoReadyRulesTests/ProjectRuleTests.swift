import DuoReadyCore
import DuoReadyRules
import Foundation
import Testing

/// Writes a throwaway project to disk and scans it with one rule.
private struct TempProject {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("duoready-\(UUID())")

    func write(_ path: String, _ contents: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    func scan(_ rule: any Rule) throws -> [Finding] {
        try Scanner(registry: RuleRegistry(rules: [rule])).scan(root: root).findings
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func plist(_ body: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \(body)
    </dict>
    </plist>
    """
}

private let sceneManifest = """
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
        <key>UISceneConfigurations</key>
        <dict>
            <key>UIWindowSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneDelegateClassName</key>
                    <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
                </dict>
            </array>
        </dict>
    </dict>
    """

private let uikitAppDelegate = """
    import UIKit

    @main
    class AppDelegate: UIResponder, UIApplicationDelegate {
        var window: UIWindow?
    }
    """

@Suite("DR010 UIRequiresFullScreen no longer prevents resizing")
struct RequiresFullScreenRuleTests {
    let rule = RequiresFullScreenRule()

    @Test("Flags the Info.plist key and the build setting, at the right lines")
    func problematic() throws {
        let project = TempProject()
        defer { project.remove() }
        try project.write("App/Info.plist", plist("""
            <key>CFBundleName</key>
            <string>App</string>
            <key>UIRequiresFullScreen</key>
            <true/>
            """))
        try project.write("App.xcodeproj/project.pbxproj", """
            buildSettings = {
                INFOPLIST_KEY_UIRequiresFullScreen = YES;
                PRODUCT_NAME = App;
            };
            """)
        let findings = try project.scan(rule)
        #expect(findings.map { "\($0.file):\($0.line)" } == ["App.xcodeproj/project.pbxproj:2", "App/Info.plist:7"])
    }

    @Test("Does not flag false values, a planned migration or other keys")
    func corrected() throws {
        let project = TempProject()
        defer { project.remove() }
        try project.write("A/Info.plist", plist("<key>UIRequiresFullScreen</key>\n<false/>"))
        try project.write("B/Info.plist", plist("""
            <key>UIRequiresFullScreen</key>
            <true/>
            <key>UIRequiresFullScreenIgnoredStartingWithVersion</key>
            <string>28.0</string>
            """))
        try project.write("C.xcodeproj/project.pbxproj", "INFOPLIST_KEY_UIRequiresFullScreen = NO;")
        #expect(try project.scan(rule).isEmpty)
    }

    @Test("Reads binary plists and skips test folders")
    func edgeCases() throws {
        let project = TempProject()
        defer { project.remove() }
        let binary = try PropertyListSerialization.data(
            fromPropertyList: ["UIRequiresFullScreen": true], format: .binary, options: 0
        )
        try FileManager.default.createDirectory(at: project.root.appendingPathComponent("App"), withIntermediateDirectories: true)
        try binary.write(to: project.root.appendingPathComponent("App/Info.plist"))
        try project.write("AppTests/Info.plist", plist("<key>UIRequiresFullScreen</key>\n<true/>"))
        let findings = try project.scan(rule)
        #expect(findings.map { "\($0.file):\($0.line)" } == ["App/Info.plist:1"])
    }
}

@Suite("DR011 UIKit app without the scene life cycle")
struct SceneLifecycleRuleTests {
    let rule = SceneLifecycleRule()

    @Test("Flags a UIKit app delegate with no scene configuration anywhere")
    func problematic() throws {
        let project = TempProject()
        defer { project.remove() }
        try project.write("App/AppDelegate.swift", uikitAppDelegate)
        try project.write("App/Info.plist", plist("<key>CFBundleName</key>\n<string>App</string>"))
        let findings = try project.scan(rule)
        #expect(findings.map { "\($0.file):\($0.line):\($0.column ?? 0)" } == ["App/AppDelegate.swift:4:7"])
        #expect(findings.first?.severity == .error)
    }

    @Test("Does not flag apps that adopted scenes in any supported way", arguments: [
        ("App/Info.plist", plist(sceneManifest)),
        ("App/SceneConfig.swift", """
            extension AppDelegate {
                func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
                    UISceneConfiguration(name: nil, sessionRole: session.role)
                }
            }
            """),
        ("App.xcodeproj/project.pbxproj", "INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;"),
    ])
    func adopted(path: String, contents: String) throws {
        let project = TempProject()
        defer { project.remove() }
        try project.write("App/AppDelegate.swift", uikitAppDelegate)
        try project.write(path, contents)
        #expect(try project.scan(rule).isEmpty)
    }

    @Test("Does not flag SwiftUI apps, even with an adapted app delegate")
    func swiftUI() throws {
        let project = TempProject()
        defer { project.remove() }
        try project.write("App/MyApp.swift", """
            @main
            struct MyApp: App {
                @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
                var body: some Scene { WindowGroup { ContentView() } }
            }
            """)
        try project.write("App/AppDelegate.swift", "class AppDelegate: NSObject, UIApplicationDelegate {}")
        #expect(try project.scan(rule).isEmpty)
    }

    @Test("Flags framework app delegates, honours suppressions, and ignores a scene manifest without configurations")
    func edgeCases() throws {
        let project = TempProject()
        defer { project.remove() }
        try project.write("ios/Runner/AppDelegate.swift", """
            @UIApplicationMain
            @objc class AppDelegate: FlutterAppDelegate {}
            """)
        try project.write("ios/Runner/Info.plist", plist("""
            <key>UIApplicationSceneManifest</key>
            <dict>
                <key>UIApplicationSupportsMultipleScenes</key>
                <false/>
            </dict>
            """))
        try project.write("ios/Other/AppDelegate.swift", """
            // duoready:ignore DR011
            @main class OtherDelegate: UIResponder, UIApplicationDelegate {}
            """)
        let findings = try project.scan(rule)
        #expect(findings.map(\.file) == ["ios/Runner/AppDelegate.swift"])
    }
}
