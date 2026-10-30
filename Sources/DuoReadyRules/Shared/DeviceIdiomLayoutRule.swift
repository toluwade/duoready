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
            ternary whose branches set sizes, spacing, padding, insets, margins, columns, frames, \
            axes or constraint constants, or whose ternary branches are numbers. Conditions that \
            also check a size class are not reported, and neither are feature checks such as \
            presenting a popover on iPad. An idiom stored in a variable (e.g. isPad) and checked \
            later is not tracked.
            """
    )

    /// Name suffixes that mean a branch sets geometry, e.g. `cellWidth`,
    /// `leadingPadding`, `numberOfColumns`. Matched case-insensitively against
    /// whole identifiers, so `showiPadSecondaryColumn` doesn't count.
    static let layoutNameSuffixes = [
        "width", "height", "padding", "spacing", "inset", "insets", "margin", "margins",
        "frame", "constant", "axis", "columns",
    ]
    /// Whole names that mean a branch sets geometry.
    static let layoutNames: Set<String> = [
        "size", "itemsize", "estimateditemsize", "contentsize", "preferredcontentsize", "columncount",
    ]

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)

        var reported = Set<SyntaxIdentifier>()
        return visitor.candidates.compactMap { node -> Finding? in
            guard !node.isInNonIOSPlatformBlock,
                  let decision = node.enclosingDecision(),
                  // One finding per condition, even if it checks the idiom twice.
                  !reported.contains(decision.id)
            else { return nil }

            let parts = DecisionParts(decision)
            let names = decision.identifierNames
            guard names.contains("pad") || names.contains("phone") else { return nil }
            // `idiom == .pad && horizontalSizeClass == .regular` already adapts to the window.
            guard !parts.conditionNames.contains(where: { $0.lowercased().contains("sizeclass") }) else { return nil }
            guard Self.setsLayout(parts) else { return nil }

            reported.insert(decision.id)
            return finding(at: node, in: file, message: "Layout dimensions are chosen by device type (\(node.trimmedDescription)) rather than available space.")
        }
    }

    static func setsLayout(_ parts: DecisionParts) -> Bool {
        let names = parts.branchNames.map { $0.lowercased() }
        if names.contains(where: { name in layoutNames.contains(name) || layoutNameSuffixes.contains { name.hasSuffix($0) } }) {
            return true
        }
        // `idiom == .pad ? 40 : 16`
        return parts.branches.first?.as(ExprSyntax.self)?.numericLiteralValue != nil
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
