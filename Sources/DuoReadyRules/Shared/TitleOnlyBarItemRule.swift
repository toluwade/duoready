import DuoReadyCore
import SwiftSyntax

/// DR008: toolbar items with a title and no icon.
public struct TitleOnlyBarItemRule: SwiftRule {
    public init() {}

    public let metadata = RuleMetadata(
        id: "DR008",
        title: "Bar items with a title but no icon",
        category: .shared,
        defaultSeverity: .info,
        confidence: .high,
        rationale: """
            When iPhone Duo presents bars vertically, it shows each item as an icon. Apple: "If your \
            item has a title and doesn't have an icon, the system doesn't present it vertically." The \
            control disappears from the bar in those poses. Items with both a title and an icon work \
            everywhere: the system picks whichever fits.
            """,
        suggestion: """
            Give the item an icon as well as its title: Button("Edit", systemImage: "pencil") or a \
            Label in SwiftUI, and UIBarButtonItem(title:image:primaryAction:menu:) in UIKit.
            """,
        limitations: """
            Reports SwiftUI Buttons in a .toolbar whose label is only text, and \
            UIBarButtonItem(title:style:target:action:) without an image. Back-button items and \
            empty titles are not reported. Buttons inside a Menu, and \
            items with cancellation, confirmation, destructive, keyboard, principal or status \
            placement, are not reported. Neither are UIKit items in files that set an \
            inputAccessoryView (keyboard toolbars). Items built in a separate view or function are \
            not seen.
            """
    )

    /// Placements that never become vertical bar icons.
    static let exemptPlacements: Set<String> = [
        "cancellationAction", "confirmationAction", "destructiveAction", "keyboard", "principal", "status",
    ]

    public func check(_ file: SwiftSourceFile) -> [Finding] {
        let visitor = Visitor(viewMode: .sourceAccurate)
        visitor.walk(file.tree)
        let hasKeyboardAccessory = file.mentions("inputAccessoryView")

        var findings: [Finding] = []
        for call in visitor.buttons where Self.isTitleOnlyToolbarButton(call) {
            findings.append(finding(at: call, in: file, message: "Toolbar button has a title but no icon, so iPhone Duo hides it when bars move to the side."))
        }
        if !hasKeyboardAccessory {
            for call in visitor.barButtonItems where Self.isTitleOnlyBarButtonItem(call) {
                findings.append(finding(at: call, in: file, message: "UIBarButtonItem has a title but no image, so iPhone Duo hides it when bars move to the side."))
            }
        }
        return findings
    }

    static func isTitleOnlyBarButtonItem(_ call: FunctionCallExprSyntax) -> Bool {
        let labels = call.arguments.compactMap { $0.label?.text }
        guard labels.first == "title", !labels.contains("image") else { return false }
        // `UIBarButtonItem(title: "")` hides back-button text; it isn't a control.
        if let title = call.arguments.first?.expression.as(StringLiteralExprSyntax.self),
           title.segments.trimmedDescription.trimmingCharacters(in: .whitespaces).isEmpty
        {
            return false
        }
        // Back-button items only set the text of the next screen's Back button.
        if let assignee = assignmentTarget(of: call), assignee.hasSuffix("backBarButtonItem") {
            return false
        }
        return true
    }

    /// `navigationItem.backBarButtonItem` for `navigationItem.backBarButtonItem = <call>`.
    static func assignmentTarget(of call: FunctionCallExprSyntax) -> String? {
        guard let list = call.parent?.as(ExprListSyntax.self) else { return nil }
        let elements = Array(list)
        guard let index = elements.firstIndex(where: { $0.id == call.id }), index >= 2,
              elements[index - 1].is(AssignmentExprSyntax.self)
        else { return nil }
        return elements[index - 2].trimmedDescription
    }

    static func isTitleOnlyToolbarButton(_ call: FunctionCallExprSyntax) -> Bool {
        guard hasTextOnlyLabel(call) else { return false }

        // Must sit in a .toolbar { } without passing through a Menu or an exempt placement.
        for enclosing in call.enclosingCalls {
            if enclosing.modifierName == "toolbar" { return true }
            switch enclosing.calledName {
            case "Menu", "ControlGroup":
                return false
            case "ToolbarItem", "ToolbarItemGroup":
                if let placement = enclosing.arguments.argument("placement")?.as(MemberAccessExprSyntax.self),
                   exemptPlacements.contains(placement.declName.baseName.text)
                {
                    return false
                }
            default:
                continue
            }
        }
        return false
    }

    /// `Button("Edit") { }`, `Button("Edit", action: edit)` and
    /// `Button { } label: { Text("Edit") }`, but not `Button("Edit", systemImage: "pencil")`.
    static func hasTextOnlyLabel(_ call: FunctionCallExprSyntax) -> Bool {
        let labels = call.arguments.map { $0.label?.text }
        if labels.contains(where: { ["systemImage", "image"].contains($0) }) { return false }
        if let first = call.arguments.first, first.label == nil {
            // Button(_ titleKey:) / Button(_ title:)
            return first.expression.is(StringLiteralExprSyntax.self) || first.expression.is(DeclReferenceExprSyntax.self)
        }
        guard let label = call.additionalTrailingClosures.first(where: { $0.label.text == "label" })?.closure else {
            return false
        }
        let calls = label.statements.compactMap { $0.item.as(FunctionCallExprSyntax.self) }
        return calls.count == label.statements.count && !calls.isEmpty && calls.allSatisfy { $0.calledName == "Text" }
    }

    private final class Visitor: SyntaxVisitor {
        var buttons: [FunctionCallExprSyntax] = []
        var barButtonItems: [FunctionCallExprSyntax] = []

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            switch node.calledName {
            case "Button": buttons.append(node)
            case "UIBarButtonItem": barButtonItems.append(node)
            default: break
            }
            return .visitChildren
        }
    }
}
