import DuoReadyCore
import Foundation
import SwiftSyntax

extension ExprSyntax {
    /// The dotted name of a plain member chain such as `UIDevice.current`,
    /// or nil when the expression is anything more complex (calls, subscripts, …).
    var dottedName: String? {
        if let ref = self.as(DeclReferenceExprSyntax.self) {
            return ref.baseName.text
        }
        if let member = self.as(MemberAccessExprSyntax.self), let base = member.base?.dottedName {
            return base + "." + member.declName.baseName.text
        }
        return nil
    }
}

extension SyntaxProtocol {
    /// Returns the branching statement or expression when this node is part of the
    /// condition of an `if`, `guard`, `while`, `switch` subject or ternary.
    /// Returns nil when the node is merely used inside a branch body.
    func enclosingDecision() -> Syntax? {
        var current = Syntax(self)
        while let parent = current.parent {
            if parent.is(ConditionElementSyntax.self) {
                // Climb to the owning if/guard/while for context.
                var owner = parent
                while let next = owner.parent,
                      !(next.is(IfExprSyntax.self) || next.is(GuardStmtSyntax.self) || next.is(WhileStmtSyntax.self))
                {
                    owner = next
                }
                return owner.parent ?? owner
            }
            if let switchExpr = parent.as(SwitchExprSyntax.self), switchExpr.subject.id == current.id {
                return parent
            }
            if let list = parent.as(ExprListSyntax.self),
               let index = list.firstIndex(where: { $0.id == current.id }),
               list[list.index(after: index)...].contains(where: { $0.is(UnresolvedTernaryExprSyntax.self) })
            {
                return list.parent ?? parent
            }
            if parent.is(CodeBlockSyntax.self) || parent.is(ClosureExprSyntax.self)
                || parent.is(SwitchCaseSyntax.self) || parent.is(MemberBlockSyntax.self)
            {
                return nil
            }
            current = parent
        }
        return nil
    }
}

extension SyntaxProtocol {
    /// Identifier tokens anywhere inside this node.
    var identifierNames: Set<String> {
        var names = Set<String>()
        for token in tokens(viewMode: .sourceAccurate) {
            if case let .identifier(name) = token.tokenKind {
                names.insert(name)
            }
        }
        return names
    }
}

extension ExprSyntax {
    /// The value of an integer or floating-point literal, e.g. `375` or `812.0`.
    var numericLiteralValue: Double? {
        if let literal = self.as(IntegerLiteralExprSyntax.self) {
            return Double(literal.literal.text.replacingOccurrences(of: "_", with: ""))
        }
        if let literal = self.as(FloatLiteralExprSyntax.self) {
            return Double(literal.literal.text.replacingOccurrences(of: "_", with: ""))
        }
        return nil
    }

    /// The last identifier in the expression, e.g. `height` for `view.bounds.size.height`.
    var trailingIdentifier: String? {
        var last: String?
        for token in tokens(viewMode: .sourceAccurate) {
            if case let .identifier(name) = token.tokenKind { last = name }
        }
        return last
    }

    /// Whether the expression names a width or height, e.g. `bounds.width` or `screenHeight`.
    var namesDimension: Bool {
        guard let name = trailingIdentifier?.lowercased() else { return false }
        return name.hasSuffix("width") || name.hasSuffix("height")
    }
}

extension LabeledExprListSyntax {
    /// The expression passed for `label`, if any.
    func argument(_ label: String) -> ExprSyntax? {
        first { $0.label?.text == label }?.expression
    }
}

extension SyntaxProtocol {
    /// True inside `#if os(macOS)` and similar blocks that never compile for iOS.
    var isInNonIOSPlatformBlock: Bool {
        var current = parent
        while let node = current {
            if let clause = node.as(IfConfigClauseSyntax.self), let condition = clause.condition {
                let text = condition.trimmedDescription
                let otherPlatforms = ["os(macOS)", "os(watchOS)", "os(tvOS)", "os(visionOS)"]
                if !text.contains("!"), !text.contains("os(iOS)"), otherPlatforms.contains(where: text.contains) {
                    return true
                }
            }
            current = node.parent
        }
        return false
    }

    /// True inside a SwiftUI preview (`#Preview { … }` or a `PreviewProvider`),
    /// where fixed frames deliberately simulate a device.
    var isInSwiftUIPreview: Bool {
        var current = parent
        while let node = current {
            if let macro = node.as(MacroExpansionExprSyntax.self), macro.macroName.text == "Preview" {
                return true
            }
            if let macro = node.as(MacroExpansionDeclSyntax.self), macro.macroName.text == "Preview" {
                return true
            }
            if let decl = node.asProtocol(DeclGroupSyntax.self),
               decl.inheritanceClause?.inheritedTypes.contains(where: { $0.type.trimmedDescription == "PreviewProvider" }) == true
            {
                return true
            }
            current = node.parent
        }
        return false
    }
}

/// Logical-point dimensions of shipping iPhone and iPad screens, in either
/// orientation. Comparing a size against one of these usually means the code
/// is detecting a specific device.
enum DeviceDimensions {
    static let points: Set<Double> = [
        // iPhone
        320, 375, 390, 393, 402, 414, 428, 430, 440,
        480, 568, 667, 736, 812, 844, 852, 874, 896, 926, 932, 956,
        // iPad
        744, 768, 810, 820, 834, 1024, 1112, 1133, 1180, 1194, 1210, 1366, 1376,
    ]

    /// Narrowest iPhone width. A fixed width at or above this cannot fit a
    /// narrow window without clipping.
    static let narrowestWidth: Double = 320
    /// Shortest current iPhone height in portrait.
    static let shortestHeight: Double = 568
}

func formatPoints(_ value: Double) -> String {
    value.rounded() == value ? String(Int(value)) : String(value)
}

/// The condition and branch bodies of a decision returned by
/// `enclosingDecision()`, so rules can inspect them separately.
struct DecisionParts {
    var condition: [Syntax] = []
    var branches: [Syntax] = []

    init(_ decision: Syntax) {
        if let ifExpr = decision.as(IfExprSyntax.self) {
            condition = [Syntax(ifExpr.conditions)]
            branches = [Syntax(ifExpr.body)] + (ifExpr.elseBody.map { [Syntax($0)] } ?? [])
        } else if let guardStmt = decision.as(GuardStmtSyntax.self) {
            condition = [Syntax(guardStmt.conditions)]
            branches = [Syntax(guardStmt.body)]
        } else if let whileStmt = decision.as(WhileStmtSyntax.self) {
            condition = [Syntax(whileStmt.conditions)]
            branches = [Syntax(whileStmt.body)]
        } else if let switchExpr = decision.as(SwitchExprSyntax.self) {
            condition = [Syntax(switchExpr.subject)]
            branches = switchExpr.cases.compactMap { $0.as(SwitchCaseSyntax.self).map { Syntax($0.statements) } }
        } else if let sequence = decision.as(SequenceExprSyntax.self) {
            let elements = Array(sequence.elements)
            if let index = elements.firstIndex(where: { $0.is(UnresolvedTernaryExprSyntax.self) }),
               let ternary = elements[index].as(UnresolvedTernaryExprSyntax.self)
            {
                condition = elements[..<index].map(Syntax.init)
                branches = [Syntax(ternary.thenExpression)] + elements[(index + 1)...].map(Syntax.init)
            }
        }
    }

    var conditionNames: Set<String> {
        condition.reduce(into: []) { $0.formUnion($1.identifierNames) }
    }

    var branchNames: Set<String> {
        branches.reduce(into: []) { $0.formUnion($1.identifierNames) }
    }
}

extension SyntaxProtocol {
    /// The nearest ancestor of the given type.
    func firstAncestor<T: SyntaxProtocol>(_ type: T.Type) -> T? {
        var current = parent
        while let node = current {
            if let match = node.as(type) { return match }
            current = node.parent
        }
        return nil
    }
}

extension FunctionCallExprSyntax {
    /// The type or function being called: `UIToolbar` for both
    /// `UIToolbar(frame: .zero)` and `UIToolbar.init()`, `Button` for `Button("Edit") {}`.
    var calledName: String? {
        if let reference = calledExpression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text
        }
        if let member = calledExpression.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "init",
           let base = member.base?.as(DeclReferenceExprSyntax.self)
        {
            return base.baseName.text
        }
        return nil
    }

    /// The modifier name for calls like `.toolbar { … }` or `view.toolbar { … }`.
    var modifierName: String? {
        calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
    }
}

extension SyntaxProtocol {
    /// Function calls whose arguments or closures contain this node, innermost
    /// first, without leaving the enclosing type or function declaration.
    ///
    /// A call this node is only the receiver of doesn't count: in
    /// `VStack { Button("Go") }.toolbar { … }` the button is not in the toolbar.
    var enclosingCalls: [FunctionCallExprSyntax] {
        var calls: [FunctionCallExprSyntax] = []
        var child = Syntax(self)
        while let node = child.parent {
            if node.is(MemberBlockSyntax.self) || node.is(FunctionDeclSyntax.self) { break }
            if let call = node.as(FunctionCallExprSyntax.self), call.calledExpression.id != child.id {
                calls.append(call)
            }
            child = node
        }
        return calls
    }
}

extension SwiftSourceFile {
    /// Whether any identifier in the file has this exact name.
    func mentions(_ identifier: String) -> Bool {
        tree.tokens(viewMode: .sourceAccurate).contains { $0.tokenKind == .identifier(identifier) }
    }
}
