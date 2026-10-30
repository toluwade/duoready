import DuoReadyCore
import SwiftSyntax

/// DR005: Auto Layout constraints that fix a view to a screen-sized constant.
public struct FixedSizeConstraintRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR005",
        title: "Constraints that pin content to screen-sized constants",
        category: .uiKit,
        defaultSeverity: .warning,
        confidence: .medium,
        rationale: """
            A required constraint that sets a view's width to 320 points or more, or its height to \
            568 points or more, assumes the window is at least that large. In a narrower or shorter \
            window, the content clips or Auto Layout has to break constraints.
            """,
        suggestion: """
            Relate the size to the container instead (for example, \
            widthAnchor.constraint(equalTo: container.widthAnchor)), cap it with \
            lessThanOrEqualToConstant, or lower the constraint's priority.
            """,
        limitations: """
            Reports widthAnchor/heightAnchor.constraint(equalToConstant:) and \
            NSLayoutConstraint(item:attribute:relatedBy:toItem:nil…) with a literal constant. \
            Constants stored in variables, constraints in Interface Builder files and priority \
            changes made after creation are not detected.
            """
    )

    enum Axis: String {
        case width, height

        var threshold: Double {
            switch self {
            case .width: DeviceDimensions.narrowestWidth
            case .height: DeviceDimensions.shortestHeight
            }
        }
    }

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.matches
            .filter { !$0.node.isInNonIOSPlatformBlock && !Self.priorityIsLowered($0.node) }
            .map { match in
                finding(at: match.node, in: file, message: "Fixed \(match.axis.rawValue) constraint of \(formatPoints(match.value)) points assumes the window is at least that \(match.axis == .width ? "wide" : "tall").")
            }
    }

    /// `….constraint(equalToConstant: 400).withPriority(.defaultHigh)` style
    /// chains, or setting `.priority` on the result in the same expression.
    static func priorityIsLowered(_ call: FunctionCallExprSyntax) -> Bool {
        guard let member = call.parent?.as(MemberAccessExprSyntax.self) else { return false }
        return member.declName.baseName.text.lowercased().contains("priority")
    }

    private struct Match {
        let node: FunctionCallExprSyntax
        let axis: Axis
        let value: Double
    }

    private final class Visitor: SyntaxVisitor {
        var matches: [Match] = []

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            if let match = anchorConstraint(node) ?? layoutConstraint(node), match.value >= match.axis.threshold {
                matches.append(match)
            }
            return .visitChildren
        }

        /// `view.widthAnchor.constraint(equalToConstant: 375)`
        private func anchorConstraint(_ node: FunctionCallExprSyntax) -> Match? {
            guard let callee = node.calledExpression.as(MemberAccessExprSyntax.self),
                  callee.declName.baseName.text == "constraint",
                  let anchor = callee.base?.as(MemberAccessExprSyntax.self)?.declName.baseName.text,
                  let value = node.arguments.argument("equalToConstant")?.numericLiteralValue
            else { return nil }
            switch anchor {
            case "widthAnchor": return Match(node: node, axis: .width, value: value)
            case "heightAnchor": return Match(node: node, axis: .height, value: value)
            default: return nil
            }
        }

        /// `NSLayoutConstraint(item: v, attribute: .width, relatedBy: .equal, toItem: nil, …, constant: 375)`
        private func layoutConstraint(_ node: FunctionCallExprSyntax) -> Match? {
            guard node.calledExpression.trimmedDescription == "NSLayoutConstraint",
                  let attribute = node.arguments.argument("attribute")?.trimmedDescription,
                  node.arguments.argument("relatedBy")?.trimmedDescription == ".equal",
                  node.arguments.argument("toItem")?.is(NilLiteralExprSyntax.self) == true,
                  let value = node.arguments.argument("constant")?.numericLiteralValue
            else { return nil }
            switch attribute {
            case ".width": return Match(node: node, axis: .width, value: value)
            case ".height": return Match(node: node, axis: .height, value: value)
            default: return nil
            }
        }
    }
}
