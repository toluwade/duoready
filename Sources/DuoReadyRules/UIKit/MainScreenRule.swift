import DuoReadyCore
import SwiftSyntax

/// DR001: `UIScreen.main` assumes the app lives on one known screen.
public struct MainScreenRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR001",
        title: "UIScreen.main usage",
        category: .uiKit,
        defaultSeverity: .warning,
        confidence: .high,
        rationale: """
            UIScreen.main describes a single, fixed display. On devices and configurations where \
            an app's window can be resized, moved between displays or shown alongside other apps, \
            the main screen's size no longer matches the space your UI actually has. Apple \
            deprecated UIScreen.main in iOS 16 for this reason.
            """,
        suggestion: """
            Read geometry from the context that owns the UI: view.bounds or view.window?.windowScene \
            in UIKit, or GeometryReader / containerRelativeFrame in SwiftUI.
            """,
        limitations: """
            Matches the literal expressions `UIScreen.main` and `UIKit.UIScreen.main`. It does not \
            track a screen stored in a variable or obtained through other APIs.
            """
    )

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.matches.map { match in
            finding(
                at: match.node,
                in: file,
                message: match.member.map { "UIScreen.main.\($0) assumes a single, fixed screen." }
                    ?? "UIScreen.main assumes a single, fixed screen.",
                suggestion: Self.suggestion(forMember: match.member)
            )
        }
    }

    /// A fix tailored to what the code reads from the screen.
    static func suggestion(forMember member: String?) -> String? {
        switch member {
        case "bounds", "nativeBounds", "applicationFrame":
            "Use the size of the containing view or window (view.bounds, view.window?.bounds) in UIKit, or GeometryReader / containerRelativeFrame in SwiftUI."
        case "scale", "nativeScale":
            "Use traitCollection.displayScale in UIKit, or @Environment(\\.displayScale) in SwiftUI."
        case "traitCollection":
            "Use the traitCollection of the view or view controller that is being laid out."
        case "brightness", "maximumFramesPerSecond", "coordinateSpace":
            "Resolve the screen the UI is actually on with view.window?.windowScene?.screen."
        default:
            nil
        }
    }

    private struct Match {
        let node: MemberAccessExprSyntax
        let member: String?
    }

    private final class Visitor: SyntaxVisitor {
        var matches: [Match] = []

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            guard node.declName.baseName.text == "main",
                  let base = node.base?.dottedName,
                  base == "UIScreen" || base == "UIKit.UIScreen"
            else { return .visitChildren }

            let member = node.parent?.as(MemberAccessExprSyntax.self)?.declName.baseName.text
            matches.append(Match(node: node, member: member))
            return .skipChildren
        }
    }
}
