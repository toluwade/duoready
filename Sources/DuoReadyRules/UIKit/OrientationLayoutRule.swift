import DuoReadyCore
import SwiftSyntax

/// DR002: branching on device or interface orientation to choose a layout.
public struct OrientationLayoutRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR002",
        title: "Layout decisions based on orientation",
        category: .uiKit,
        defaultSeverity: .warning,
        confidence: .medium,
        rationale: """
            Orientation says how the device is held, not how much space the app has. A window can be \
            narrow while the device is in landscape, or wide while it is in portrait, so layouts \
            chosen from orientation break when the window is resized or shares the display.
            """,
        suggestion: """
            Choose layouts from the available size instead: size classes (traitCollection / \
            @Environment(\\.horizontalSizeClass)), the container's bounds, or ViewThatFits in SwiftUI.
            """,
        limitations: """
            Only reports orientation values used in an if, guard, while, switch or ternary condition. \
            Decisions that drive camera, video or image rotation are not reported, because device \
            orientation is the correct input there.
            """
    )

    /// Orientation sources, matched by the final member name and, where it is
    /// ambiguous, by the base expression.
    static let orientationMembers: [String: Set<String>?] = [
        "orientation": ["UIDevice.current"],
        "statusBarOrientation": nil,
        "interfaceOrientation": nil,
    ]

    /// Identifiers indicating the decision drives media rotation, not layout.
    static let mediaOrientationIdentifiers: Set<String> = [
        "videoOrientation", "videoRotationAngle", "imageOrientation",
        "AVCaptureVideoOrientation", "AVCaptureConnection", "CGImagePropertyOrientation",
        "videoRotationAngleForHorizonLevelCapture", "videoRotationAngleForHorizonLevelPreview",
    ]

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)

        return visitor.candidates.compactMap { node -> Finding? in
            guard let decision = node.enclosingDecision() else { return nil }
            if !decision.identifierNames.isDisjoint(with: Self.mediaOrientationIdentifiers) {
                return nil
            }
            let name = node.trimmedDescription
            return finding(at: node, in: file, message: "Layout branches on \(name), which does not reflect the app's available space.")
        }
    }

    private final class Visitor: SyntaxVisitor {
        var candidates: [MemberAccessExprSyntax] = []

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            let member = node.declName.baseName.text
            guard let requiredBases = OrientationLayoutRule.orientationMembers[member] else {
                return .visitChildren
            }
            if let requiredBases {
                guard let base = node.base?.dottedName, requiredBases.contains(base) else {
                    return .visitChildren
                }
            }
            candidates.append(node)
            return .skipChildren
        }
    }
}
