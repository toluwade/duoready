import DuoReadyCore
import SwiftSyntax

/// DR009: an ArrangementView inside a container that hides part of it.
public struct ArrangementViewPlacementRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR009",
        title: "ArrangementView inside a list, scroll view or split view",
        category: .swiftUI,
        defaultSeverity: .warning,
        confidence: .high,
        rationale: """
            An arrangement view lays out a primary and a secondary view around iPhone Duo's fold. \
            Apple: "Avoid placing an arrangement view inside a navigation split view, list, scroll \
            view, or other container that might cause part of your view to become inaccessible."
            """,
        suggestion: """
            Make the ArrangementView the outer container of the screen, and put lists or scroll views \
            inside its primary or secondary view instead.
            """,
        limitations: """
            Reports an ArrangementView written directly inside a List, ScrollView, Form or \
            NavigationSplitView in the same view body. An arrangement view in a separate view type \
            that a list later contains is not seen.
            """
    )

    static let containers: Set<String> = ["List", "ScrollView", "Form", "NavigationSplitView"]

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.matches.map { call, container in
            finding(at: call, in: file, message: "ArrangementView is inside a \(container), which can make part of it inaccessible on iPhone Duo.")
        }
    }

    private final class Visitor: SyntaxVisitor {
        var matches: [(FunctionCallExprSyntax, String)] = []

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            if node.calledName == "ArrangementView",
               let container = node.enclosingCalls.lazy.compactMap(\.calledName)
                   .first(where: ArrangementViewPlacementRule.containers.contains)
            {
                matches.append((node, container))
            }
            return .visitChildren
        }
    }
}
