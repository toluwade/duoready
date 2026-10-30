import DuoReadyCore
import SwiftSyntax

/// DR006: SwiftUI frames with screen-sized fixed widths or heights.
public struct FixedFrameRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR006",
        title: "SwiftUI frames with screen-sized fixed dimensions",
        category: .swiftUI,
        defaultSeverity: .info,
        confidence: .medium,
        rationale: """
            `.frame(width:height:)` proposes an exact size regardless of the space available. A \
            fixed width of 320 points or more, or a fixed height of 568 points or more, is about \
            the size of a whole screen, so the view clips or overflows in a smaller window.
            """,
        suggestion: """
            Use flexible sizing: .frame(maxWidth: .infinity), .frame(maxWidth: 400) to cap a size, \
            containerRelativeFrame, or GeometryReader when the size really depends on the container.
            """,
        limitations: """
            Reports `.frame(width:)` of 320 points or more and `.frame(height:)` of 568 points or \
            more, when the value is a literal. Frames inside #Preview, PreviewProvider and \
            non-iOS #if blocks are ignored. Smaller fixed frames, such as icons, are not reported. \
            A fixed frame inside a scroll view may be intentional.
            """
    )

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.matches
            .filter { !$0.node.isInNonIOSPlatformBlock && !$0.node.isInSwiftUIPreview }
            .map { match in
                finding(at: match.node, in: file, message: "Fixed frame \(match.description) won't adapt to smaller windows.")
            }
    }

    /// One per `.frame(…)` call, located at its first oversized argument.
    private struct Match {
        let node: LabeledExprSyntax
        let width: Double?
        let height: Double?

        var description: String {
            switch (width, height) {
            case let (width?, height?): "of \(formatPoints(width)) × \(formatPoints(height)) points"
            case let (width?, nil): "width of \(formatPoints(width)) points"
            case let (nil, height?): "height of \(formatPoints(height)) points"
            case (nil, nil): ""
            }
        }
    }

    private final class Visitor: SyntaxVisitor {
        var matches: [Match] = []

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard let callee = node.calledExpression.as(MemberAccessExprSyntax.self),
                  callee.declName.baseName.text == "frame"
            else { return .visitChildren }

            var first: LabeledExprSyntax?
            var width: Double?
            var height: Double?
            for argument in node.arguments {
                guard let label = argument.label?.text,
                      let value = argument.expression.numericLiteralValue
                else { continue }
                if label == "width", value >= DeviceDimensions.narrowestWidth {
                    width = value
                } else if label == "height", value >= DeviceDimensions.shortestHeight {
                    height = value
                } else {
                    continue
                }
                first = first ?? argument
            }
            if let first {
                matches.append(Match(node: first, width: width, height: height))
            }
            return .visitChildren
        }
    }
}
