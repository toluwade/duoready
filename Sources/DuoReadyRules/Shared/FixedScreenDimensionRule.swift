import DuoReadyCore
import SwiftSyntax

/// DR004: comparing a size with a specific device's screen dimension.
public struct FixedScreenDimensionRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR004",
        title: "Fixed screen dimensions used for layout decisions",
        category: .shared,
        defaultSeverity: .warning,
        confidence: .high,
        rationale: """
            Checks such as `height == 812` or `screenHeight >= 667` identify a particular device \
            model by its screen size. When the app's window is resized, or runs on a device with \
            new dimensions, these checks pick the wrong layout or none at all.
            """,
        suggestion: """
            Branch on size classes or on the space available to the view (for example, \
            view.bounds.width > 600 or ViewThatFits), not on a device's screen size.
            """,
        limitations: """
            Reports exact comparisons (==, !=) and switch cases that match the width or height of \
            a view, window, screen or geometry proxy against a known iPhone or iPad screen \
            dimension, and ordered comparisons (<, >, <=, >=) when the measured value comes from \
            the screen. Sizes of other things, such as images, and breakpoints that aren't device \
            dimensions are not reported. Arithmetic on either side is not evaluated.
            """
    )

    static let equalityOperators: Set<String> = ["==", "!="]

    /// Whether `expression` measures UI space (`view.bounds.height`, `screenWidth`,
    /// `geometry.size.width`) rather than content such as `thumbnail.width`.
    static func measuresUISpace(_ expression: some SyntaxProtocol) -> Bool {
        expression.identifierNames.contains { name in
            let lowered = name.lowercased()
            return ["screen", "window", "bounds", "frame", "geometry"].contains { lowered.contains($0) }
                || ["view", "proxy", "safearealayoutguide"].contains(lowered)
        }
    }
    static let orderingOperators: Set<String> = ["<", ">", "<=", ">="]

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        return visitor.matches
            .filter { !$0.node.isInNonIOSPlatformBlock }
            .map { finding(at: $0.node, in: file, message: "\($0.description) matches a specific device's screen size of \(formatPoints($0.value)) points.") }
    }

    private struct Match {
        let node: Syntax
        let value: Double
        let description: String
    }

    private final class Visitor: SyntaxVisitor {
        var matches: [Match] = []

        override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
            let elements = Array(node.elements)
            for (index, element) in elements.enumerated() {
                guard let op = element.as(BinaryOperatorExprSyntax.self)?.operator.text,
                      index > 0, index + 1 < elements.count
                else { continue }
                let isEquality = FixedScreenDimensionRule.equalityOperators.contains(op)
                guard isEquality || FixedScreenDimensionRule.orderingOperators.contains(op) else { continue }

                let lhs = elements[index - 1], rhs = elements[index + 1]
                for (measured, literal) in [(lhs, rhs), (rhs, lhs)] {
                    guard let value = literal.numericLiteralValue,
                          DeviceDimensions.points.contains(value),
                          measured.namesDimension,
                          FixedScreenDimensionRule.measuresUISpace(measured)
                    else { continue }
                    if !isEquality, !measured.trimmedDescription.lowercased().contains("screen") { continue }
                    matches.append(Match(
                        node: Syntax(lhs),
                        value: value,
                        description: "\(lhs.trimmedDescription) \(op) \(rhs.trimmedDescription)"
                    ))
                    break
                }
            }
            return .visitChildren
        }

        override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
            guard node.subject.namesDimension, FixedScreenDimensionRule.measuresUISpace(node.subject) else {
                return .visitChildren
            }
            for case let .switchCase(switchCase) in node.cases {
                guard let label = switchCase.label.as(SwitchCaseLabelSyntax.self) else { continue }
                for item in label.caseItems {
                    guard let pattern = item.pattern.as(ExpressionPatternSyntax.self),
                          let value = pattern.expression.numericLiteralValue,
                          DeviceDimensions.points.contains(value)
                    else { continue }
                    matches.append(Match(
                        node: Syntax(item),
                        value: value,
                        description: "case \(item.trimmedDescription) on \(node.subject.trimmedDescription)"
                    ))
                }
            }
            return .visitChildren
        }
    }
}
