import DuoReadyCore
import SwiftSyntax

/// DR012: looking up "the" window app-wide instead of the one the UI is in.
public struct AppWideWindowRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR012",
        title: "App-wide window lookups",
        category: .uiKit,
        defaultSeverity: .warning,
        confidence: .high,
        rationale: """
            iPhone Duo runs two apps side by side in Split View, and can show two windows of the \
            same app. App-wide lookups such as UIApplication.shared.keyWindow, .windows or \
            connectedScenes.first return an arbitrary window, which may not be the one your view is \
            in or have its size. keyWindow and windows are also deprecated.
            """,
        suggestion: """
            Use the window your UI is in: view.window or view.window?.windowScene in UIKit, or the \
            scene passed to your scene delegate. In SwiftUI, read geometry from the view instead.
            """,
        limitations: """
            Reports UIApplication.shared.keyWindow, UIApplication.shared.windows and \
            connectedScenes.first, except when the scene is only used to reach its delegate. A window \
            or scene stored earlier and passed around is not tracked.
            """
    )

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.matches.map { node in
            finding(at: node, in: file, message: "\(node.trimmedDescription) picks an arbitrary window, which may not be the one this UI is in.")
        }
    }

    private final class Visitor: SyntaxVisitor {
        var matches: [MemberAccessExprSyntax] = []

        /// `connectedScenes.first?.delegate as? SceneDelegate` reaches app
        /// state, not a window's size.
        static func readsSceneDelegate(_ node: MemberAccessExprSyntax) -> Bool {
            var current = Syntax(node)
            while let parent = current.parent,
                  parent.is(OptionalChainingExprSyntax.self) || parent.is(ForceUnwrapExprSyntax.self)
            {
                current = parent
            }
            return current.parent?.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "delegate"
        }

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            let member = node.declName.baseName.text
            let base = node.base?.trimmedDescription.replacingOccurrences(of: "?", with: "")
            let isMatch = switch member {
            case "keyWindow", "windows": base == "UIApplication.shared"
            case "first": base?.hasSuffix("connectedScenes") == true
            default: false
            }
            guard isMatch, !node.isInNonIOSPlatformBlock, !Self.readsSceneDelegate(node) else { return .visitChildren }
            matches.append(node)
            return .skipChildren
        }
    }
}
