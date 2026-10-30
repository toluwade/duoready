import DuoReadyCore
import SwiftSyntax

/// DR011: a UIKit app that hasn't adopted the scene life cycle.
public struct SceneLifecycleRule: ProjectRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR011",
        title: "UIKit app without the scene life cycle",
        category: .projectConfiguration,
        defaultSeverity: .error,
        confidence: .medium,
        rationale: """
            Apple (TN3187): "In the next major release following iOS 26, UIScene lifecycle will be \
            required when building with the latest SDK; otherwise, your app won't launch." Scenes are \
            also what lets the system resize your app and show it on both of iPhone Duo's displays.
            """,
        suggestion: """
            Adopt the scene life cycle: add a UIApplicationSceneManifest with a scene configuration to \
            Info.plist (or implement application(_:configurationForConnecting:options:)), add a \
            UIWindowSceneDelegate, and move window setup into it. A single scene is enough. See TN3187.
            """,
        limitations: """
            Reports a Swift app delegate marked @main or @UIApplicationMain (including subclasses of \
            framework app delegates, such as FlutterAppDelegate) when the scanned folder has no \
            UIApplicationSceneManifest with scene configurations, no \
            application(_:configurationForConnecting:options:), no SwiftUI App and no generated scene \
            manifest build setting. Objective-C app delegates are not read. Scan the whole app, so its \
            Info.plist is included.
            """
    )

    enum Note {
        static let appDelegateEntry = "app-delegate-entry"
        static let swiftUIApp = "swiftui-app"
        static let sceneConfiguration = "scene-configuration"
    }

    public func notes(for file: SwiftSourceFile) -> [ProjectNote] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.found.map { kind, node in ProjectNote(kind: kind, at: node, in: file) }
    }

    public func check(_ project: ProjectContext) -> [Finding] {
        let entries = project.notes(Note.appDelegateEntry)
        guard !entries.isEmpty,
              project.notes(Note.swiftUIApp).isEmpty,
              project.notes(Note.sceneConfiguration).isEmpty,
              !project.propertyLists.contains(where: Self.hasSceneConfigurations),
              !project.projectSettings.contains(where: {
                  !$0.lines(setting: "INFOPLIST_KEY_UIApplicationSceneManifest_Generation", value: "YES").isEmpty
              })
        else { return [] }

        return entries.map { entry in
            finding(at: entry, message: "This app delegate has no scene life cycle, so the app won't launch when built with the iOS 27 SDK.")
        }
    }

    static func hasSceneConfigurations(_ plist: PropertyListFile) -> Bool {
        guard let configurations = plist.root["UIApplicationSceneManifest"]?["UISceneConfigurations"] else { return false }
        return !configurations.isEmpty
    }

    private final class Visitor: SyntaxVisitor {
        var found: [(String, Syntax)] = []

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            let attributes = Set(node.attributes.compactMap { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription })
            let inherited = node.inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
            if !attributes.isDisjoint(with: ["main", "UIApplicationMain"]),
               inherited.contains(where: { $0 == "UIApplicationDelegate" || $0.hasSuffix("AppDelegate") })
            {
                found.append((Note.appDelegateEntry, Syntax(node.name)))
            }
            return .visitChildren
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            let attributes = node.attributes.compactMap { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription }
            if attributes.contains("main"),
               node.inheritanceClause?.inheritedTypes.contains(where: { $0.type.trimmedDescription == "App" }) == true
            {
                found.append((Note.swiftUIApp, Syntax(node.name)))
            }
            return .visitChildren
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            if node.name.text == "application",
               node.signature.parameterClause.parameters.contains(where: { $0.firstName.text == "configurationForConnecting" })
            {
                found.append((Note.sceneConfiguration, Syntax(node.name)))
            }
            return .skipChildren
        }
    }
}
