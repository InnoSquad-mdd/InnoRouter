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

    var severity: DiagnosticSeverity {
        switch self {
        case .requiresEnum: return .error
        case .emptyEnum: return .warning
        }
    }

    var message: String {
        switch self {
        case .requiresEnum(let name):
            return "@\(name) can only be applied to enum declarations"
        case .emptyEnum(let name):
            return "@\(name) applied to an enum with no cases produces no case paths — consider adding at least one case or removing the macro"
        }
    }

    var diagnosticID: MessageID {
        switch self {
        case .requiresEnum:
            return MessageID(domain: "InnoRouterMacros", id: "requiresEnum")
        case .emptyEnum:
            return MessageID(domain: "InnoRouterMacros", id: "emptyEnum")
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

/// Emits the "must be applied to an enum" diagnostic and attaches a
/// keyword-replacement FixIt when the misapplied declaration is a
/// `struct` or `class`.
func emitRequiresEnumDiagnostic(
    macroName: String,
    node: AttributeSyntax,
    declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
) {
    let fixIts = makeRequiresEnumFixIts(for: declaration)
    context.diagnose(
        Diagnostic(
            node: node,
            message: MacroDiagnostic.requiresEnum(macroName: macroName),
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
