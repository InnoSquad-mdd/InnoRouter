// MARK: - CasePathMemberBuilder.swift
// InnoRouterMacrosPlugin - top-level expansion entry point that
// orchestrates the iteration + generation layers.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// `buildCasePathMembers` is the only function called from
// `RoutableMacro` and `CasePathableMacro`. It validates the
// declaration shape (must be a non-generic, non-empty enum),
// extracts cases through the iteration layer, and renders source
// through the generation layer.
//
// The split into three files mirrors the three responsibilities so
// each concern has its own audit surface:
//
//   CasePathEnumIteration.swift   — syntax tree → CasePathEnumCase
//   CasePathMemberGeneration.swift — CasePathEnumCase → source
//   CasePathMemberBuilder.swift    — orchestration + diagnostics
//
// Keeping the file names stable preserves git blame / file-link
// continuity for downstream forks.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

func buildCasePathMembers(
    macroName: String,
    node: AttributeSyntax,
    declaration: some DeclGroupSyntax,
    context: some MacroExpansionContext
) -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
        emitRequiresEnumDiagnostic(
            macroName: macroName,
            node: node,
            declaration: declaration,
            context: context
        )
        return []
    }

    if enumDecl.genericParameterClause != nil {
        emitUnsupportedGenericEnumDiagnostic(
            macroName: macroName,
            node: node,
            enumDecl: enumDecl,
            context: context
        )
        return []
    }

    let cases = extractCasePathEnumCases(from: enumDecl)
    guard !cases.isEmpty else {
        emitEmptyEnumDiagnostic(macroName: macroName, node: node, context: context)
        return []
    }

    let enumName = enumDecl.name.text
    let access = inferAccessLevel(from: enumDecl).keyword
    let casesMembers = cases.map { buildCasePathMember($0, enumName: enumName, access: access) }

    let casesEnum: DeclSyntax = """
        \(raw: access) enum Cases {
        \(raw: casesMembers.joined(separator: "\n"))
        }
        """

    let isMethod: DeclSyntax = """
        \(raw: access) func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
            casePath.extract(self) != nil
        }
        """

    let subscriptDecl: DeclSyntax = """
        \(raw: access) subscript<Value>(case casePath: CasePath<Self, Value>) -> Value? {
            casePath.extract(self)
        }
        """

    return [casesEnum, isMethod, subscriptDecl]
}
