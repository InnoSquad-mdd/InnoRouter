// MARK: - MacroDiagnostic.swift
// InnoRouterMacrosPlugin - shared diagnostic + FixIt plumbing
// Copyright © 2026 Inno Squad. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Shared diagnostic payload for every InnoRouter macro.
///
/// Both ``RoutableMacro`` and ``CasePathableMacro`` emit the same
/// family of diagnostics, so we centralise the `DiagnosticMessage` +
/// `FixItMessage` machinery here instead of duplicating it per macro.
enum MacroDiagnostic: DiagnosticMessage {
    /// Declaration that the macro was attached to is not an enum.
    case requiresEnum(macroName: String)
    /// Declaration is an enum but has no cases — expansion produces
    /// nothing useful; surfaced as a warning, not an error.
    case emptyEnum(macroName: String)
    /// Declaration is a generic enum. The generated `CasePath<Self, T>`
    /// members cannot propagate the parent's generic parameters into a
    /// nested `enum Cases`, so expansion is rejected as an error.
    case unsupportedGenericEnum(macroName: String)

    var severity: DiagnosticSeverity {
        switch self {
        case .requiresEnum: return .error
        // Promoted from .warning to .error in 4.0.0. A `@Routable` /
        // `@CasePathable` macro applied to an empty enum produces zero
        // members; the warning was easy to miss in noisy build logs and
        // turned the macro into a silent no-op. Failing the build
        // forces the author to either add a case or remove the macro,
        // which matches every other macro diagnostic's severity in
        // this plugin.
        case .emptyEnum: return .error
        case .unsupportedGenericEnum: return .error
        }
    }

    var message: String {
        switch self {
        case .requiresEnum(let name):
            return "@\(name) can only be applied to enum declarations"
        case .emptyEnum(let name):
            return "@\(name) applied to an enum with no cases produces no case paths — consider adding at least one case or removing the macro"
        case .unsupportedGenericEnum(let name):
            return "@\(name) does not support generic enum declarations. Generic parameters cannot be propagated through the generated `CasePath` members. Consider separating generic cases into a non-generic wrapper enum."
        }
    }

    var diagnosticID: MessageID {
        switch self {
        case .requiresEnum:
            return MessageID(domain: "InnoRouterMacros", id: "requiresEnum")
        case .emptyEnum:
            return MessageID(domain: "InnoRouterMacros", id: "emptyEnum")
        case .unsupportedGenericEnum:
            return MessageID(domain: "InnoRouterMacros", id: "unsupportedGenericEnum")
        }
    }
}

/// FixIt payload that accompanies ``MacroDiagnostic/requiresEnum`` when
/// the misapplied declaration is a `struct` or `class` — the two
/// keywords we can confidently suggest replacing with `enum`. Other
/// declaration kinds (protocol, actor, extension) get the diagnostic
/// without a FixIt because the shape change is too large to preview.
struct ReplaceKeywordWithEnumFixIt: FixItMessage {
    let originalKeyword: String

    var message: String {
        "Change `\(originalKeyword)` to `enum`"
    }

    var fixItID: MessageID {
        MessageID(domain: "InnoRouterMacros", id: "replaceKeywordWithEnum")
    }
}

/// Note attached to ``MacroDiagnostic/requiresEnum`` when the
/// misapplied declaration is a `protocol` or `actor`. These shapes
/// differ from `enum` enough that a one-keyword FixIt would silently
/// erase important semantics (witness tables, isolation), so the
/// macro emits a refactor hint instead of an automated rewrite.
struct RequiresEnumManualRefactorNote: NoteMessage {
    let originalKeyword: String

    var message: String {
        "Refactor manually — declaration shape differs from enum (`\(originalKeyword)` cannot be safely auto-replaced)."
    }

    var fixItID: MessageID {
        MessageID(domain: "InnoRouterMacros", id: "requiresEnumManualRefactor")
    }

    var noteID: MessageID { fixItID }
}

/// Emits the "must be applied to an enum" diagnostic and attaches a
/// keyword-replacement FixIt when the misapplied declaration is a
/// `struct` or `class`. For `protocol` / `actor` declarations the
/// diagnostic carries a manual-refactor note instead, because those
/// shapes cannot be safely auto-rewritten as enums.
func emitRequiresEnumDiagnostic(
    macroName: String,
    node: AttributeSyntax,
    declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
) {
    let fixIts = makeRequiresEnumFixIts(for: declaration)
    let notes = makeRequiresEnumNotes(for: declaration, attachedTo: node)
    context.diagnose(
        Diagnostic(
            node: node,
            message: MacroDiagnostic.requiresEnum(macroName: macroName),
            notes: notes,
            fixIts: fixIts
        )
    )
}

/// Emits the empty-enum warning.
func emitEmptyEnumDiagnostic(
    macroName: String,
    node: AttributeSyntax,
    context: some MacroExpansionContext
) {
    context.diagnose(
        Diagnostic(
            node: node,
            message: MacroDiagnostic.emptyEnum(macroName: macroName)
        )
    )
}

/// Emits the "generic enums are not supported" diagnostic. The diagnostic is
/// pinned to the enum's generic parameter clause when available so the
/// compiler error highlights the offending `<...>` rather than the macro
/// attribute itself.
func emitUnsupportedGenericEnumDiagnostic(
    macroName: String,
    node: AttributeSyntax,
    enumDecl: EnumDeclSyntax,
    context: some MacroExpansionContext
) {
    let anchor: SyntaxProtocol = enumDecl.genericParameterClause ?? Syntax(node)
    context.diagnose(
        Diagnostic(
            node: anchor,
            message: MacroDiagnostic.unsupportedGenericEnum(macroName: macroName)
        )
    )
}

private func makeRequiresEnumFixIts(
    for declaration: some DeclGroupSyntax
) -> [FixIt] {
    if let structDecl = declaration.as(StructDeclSyntax.self) {
        return [keywordReplacementFixIt(
            original: structDecl.structKeyword,
            originalKeyword: "struct"
        )]
    }
    if let classDecl = declaration.as(ClassDeclSyntax.self) {
        return [keywordReplacementFixIt(
            original: classDecl.classKeyword,
            originalKeyword: "class"
        )]
    }
    return []
}

private func makeRequiresEnumNotes(
    for declaration: some DeclGroupSyntax,
    attachedTo node: AttributeSyntax
) -> [Note] {
    if let protocolDecl = declaration.as(ProtocolDeclSyntax.self) {
        return [Note(
            node: Syntax(protocolDecl.protocolKeyword),
            message: RequiresEnumManualRefactorNote(originalKeyword: "protocol")
        )]
    }
    if let actorDecl = declaration.as(ActorDeclSyntax.self) {
        return [Note(
            node: Syntax(actorDecl.actorKeyword),
            message: RequiresEnumManualRefactorNote(originalKeyword: "actor")
        )]
    }
    return []
}

private func keywordReplacementFixIt(
    original: TokenSyntax,
    originalKeyword: String
) -> FixIt {
    let replacement = TokenSyntax(
        .keyword(.enum),
        leadingTrivia: original.leadingTrivia,
        trailingTrivia: original.trailingTrivia,
        presence: .present
    )
    return FixIt(
        message: ReplaceKeywordWithEnumFixIt(originalKeyword: originalKeyword),
        changes: [.replace(oldNode: Syntax(original), newNode: Syntax(replacement))]
    )
}
