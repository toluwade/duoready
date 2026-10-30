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
                finding(at: match.node, in: file, message: "Fixed frame \(match.label) of \(formatPoints(match.value)) points won't adapt to smaller windows.")
            }
    }

    private struct Match {
        let node: LabeledExprSyntax
        let label: String
        let value: Double
    }

    private final class Visitor: SyntaxVisitor {
        var matches: [Match] = []

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard let callee = node.calledExpression.as(MemberAccessExprSyntax.self),
                  callee.declName.baseName.text == "frame"
            else { return .visitChildren }

            for argument in node.arguments {
                guard let label = argument.label?.text,
                      let value = argument.expression.numericLiteralValue
                else { continue }
                let threshold: Double
                switch label {
                case "width": threshold = DeviceDimensions.narrowestWidth
                case "height": threshold = DeviceDimensions.shortestHeight
                default: continue
                }
                if value >= threshold {
                    matches.append(Match(node: argument, label: label, value: value))
                }
            }
            return .visitChildren
        }
    }
}
