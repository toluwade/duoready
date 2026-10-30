import DuoReadyCore
import SwiftSyntax

/// DR003: choosing layout dimensions from the device type (iPhone vs iPad).
public struct DeviceIdiomLayoutRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR003",
        title: "Device-type checks used to select layout dimensions",
        category: .shared,
        defaultSeverity: .warning,
        confidence: .medium,
        rationale: """
            The device type doesn't tell you how much space the app has. An iPad app can run in a \
            window narrower than an iPhone, and a phone-sized device can show a wide window. Sizes \
            picked from userInterfaceIdiom are wrong whenever the window doesn't match the device.
            """,
        suggestion: """
            Pick dimensions from size classes (traitCollection.horizontalSizeClass or \
            @Environment(\\.horizontalSizeClass)) or from the container's actual size.
            """,
        limitations: """
            Reports userInterfaceIdiom compared with .pad or .phone in an if, guard, switch or \
            ternary whose branches set sizes, spacing, insets, columns, frames or constraint \
            constants, or whose ternary branches are numbers. An idiom stored in a variable \
            (e.g. isPad) and checked later is not tracked. Feature checks, such as choosing a \
            popover on iPad, are not reported.
            """
    )

    /// Name fragments that indicate a branch sets layout geometry.
    static let layoutNameFragments = [
        "width", "height", "frame", "spacing", "padding", "inset", "margin",
        "column", "itemsize", "constant", "axis", "anchor", "cgsize", "cgrect",
    ]

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)

        return visitor.candidates.compactMap { node -> Finding? in
            guard !node.isInNonIOSPlatformBlock,
                  let decision = node.enclosingDecision()
            else { return nil }

            let names = decision.identifierNames
            guard names.contains("pad") || names.contains("phone") else { return nil }
            guard Self.setsLayout(decision, names: names) else { return nil }

            return finding(at: node, in: file, message: "Layout dimensions are chosen by device type (\(node.trimmedDescription)) rather than available space.")
        }
    }

    static func setsLayout(_ decision: Syntax, names: Set<String>) -> Bool {
        let lowered = names.map { $0.lowercased() }
        if lowered.contains(where: { name in layoutNameFragments.contains { name.contains($0) } }) {
            return true
        }
        // `idiom == .pad ? 40 : 16`
        if let sequence = decision.as(SequenceExprSyntax.self),
           let ternary = sequence.elements.first(where: { $0.is(UnresolvedTernaryExprSyntax.self) })?
               .as(UnresolvedTernaryExprSyntax.self)
        {
            return ternary.thenExpression.numericLiteralValue != nil
        }
        return false
    }

    private final class Visitor: SyntaxVisitor {
        var candidates: [MemberAccessExprSyntax] = []

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            guard node.declName.baseName.text == "userInterfaceIdiom" else { return .visitChildren }
            candidates.append(node)
            return .skipChildren
        }
    }
}
