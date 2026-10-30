import DuoReadyCore
import SwiftSyntax

/// DR007: bars created by hand, which the system can't move to the side.
public struct CustomBarRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR007",
        title: "Custom bars the system can't present vertically",
        category: .uiKit,
        defaultSeverity: .warning,
        confidence: .high,
        rationale: """
            On iPhone Duo, the system presents navigation bars, toolbars and tab bars vertically on \
            the side of the display in some poses. It can only do that for bars it manages. A \
            UIToolbar, UINavigationBar or UITabBar that your code creates and adds as a subview stays \
            horizontal, takes up space the content needs, and looks out of place next to system bars.
            """,
        suggestion: """
            Let a container manage the bar: set toolbarItems on a view controller inside a \
            UINavigationController, use navigationItem for navigation-bar buttons, and use \
            UITabBarController for tabs.
            """,
        limitations: """
            Reports UIToolbar, UINavigationBar and UITabBar initializers. Subclasses (for example a \
            bar class passed to UINavigationController) are not reported, and neither are toolbars \
            in files that set an inputAccessoryView, where a toolbar above the keyboard is expected.
            """
    )

    static let barTypes: Set<String> = ["UIToolbar", "UINavigationBar", "UITabBar"]

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        let hasKeyboardAccessory = file.mentions("inputAccessoryView")
        return visitor.matches.compactMap { call, name in
            if name == "UIToolbar", hasKeyboardAccessory { return nil }
            return finding(
                at: call, in: file,
                message: "This \(name) is created by hand, so iPhone Duo can't move it to the side of the display with the system's bars."
            )
        }
    }

    private final class Visitor: SyntaxVisitor {
        var matches: [(FunctionCallExprSyntax, String)] = []

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            if let name = node.calledName, CustomBarRule.barTypes.contains(name), !node.isInNonIOSPlatformBlock {
                matches.append((node, name))
            }
            return .visitChildren
        }
    }
}
