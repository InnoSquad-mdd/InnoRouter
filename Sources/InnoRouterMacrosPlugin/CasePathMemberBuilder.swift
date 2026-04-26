// MARK: - CasePathMemberBuilder.swift
// InnoRouterMacrosPlugin - shared case-path member generation
// Copyright © 2026 Inno Squad. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private struct CasePathAssociatedValueParameter {
    let type: String
    let bindingName: String
    let emittedLabel: String?
}

private struct CasePathEnumCase {
    let name: String
    let emittedName: String
    let parameters: [CasePathAssociatedValueParameter]
}

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
    let casesMembers = cases.map { buildCasePathMember($0, enumName: enumName) }

    let casesEnum: DeclSyntax = """
        public enum Cases {
        \(raw: casesMembers.joined(separator: "\n"))
        }
        """

    let isMethod: DeclSyntax = """
        public func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
            casePath.extract(self) != nil
        }
        """

    let subscriptDecl: DeclSyntax = """
        public subscript<Value>(case casePath: CasePath<Self, Value>) -> Value? {
            casePath.extract(self)
        }
        """

    return [casesEnum, isMethod, subscriptDecl]
}

private func extractCasePathEnumCases(
    from enumDecl: EnumDeclSyntax
) -> [CasePathEnumCase] {
    enumDecl.memberBlock.members
        .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
        .flatMap { $0.elements }
        .map { enumCase in
            CasePathEnumCase(
                name: enumCase.name.text,
                emittedName: escapedIdentifier(enumCase.name),
                parameters: enumCase.parameterClause?.parameters.enumerated().map { index, param in
                    CasePathAssociatedValueParameter(
                        type: param.type.trimmedDescription,
                        bindingName: bindingName(for: param, index: index),
                        emittedLabel: emittedLabel(for: param)
                    )
                } ?? []
            )
        }
}

private func buildCasePathMember(
    _ enumCase: CasePathEnumCase,
    enumName: String
) -> String {
    if enumCase.parameters.isEmpty {
        return """
                public static let \(enumCase.emittedName) = CasePath<\(enumName), Void>(
                    embed: { _ in .\(enumCase.emittedName) },
                    extract: { if case .\(enumCase.emittedName) = $0 { return () }; return nil }
                )
        """
    }

    let tupleType = enumCase.parameters.count == 1
        ? enumCase.parameters[0].type
        : "(\(enumCase.parameters.map(\.type).joined(separator: ", ")))"

    let extractBindings = enumCase.parameters
        .map { "let \($0.bindingName)" }
        .joined(separator: ", ")

    let extractReturn = enumCase.parameters
        .map(\.bindingName)
        .joined(separator: ", ")

    let returnValue = enumCase.parameters.count == 1
        ? extractReturn
        : "(\(extractReturn))"

    let embedArgs = enumCase.parameters.enumerated().map { index, parameter in
        if enumCase.parameters.count == 1 {
            if let label = parameter.emittedLabel {
                return "\(label): value"
            }
            return "value"
        }

        if let label = parameter.emittedLabel {
            return "\(label): value.\(index)"
        }
        return "value.\(index)"
    }.joined(separator: ", ")

    return """
            public static let \(enumCase.emittedName) = CasePath<\(enumName), \(tupleType)>(
                embed: { value in .\(enumCase.emittedName)(\(embedArgs)) },
                extract: { if case .\(enumCase.emittedName)(\(extractBindings)) = $0 { return \(returnValue) }; return nil }
            )
    """
}

private func escapedIdentifier(_ token: TokenSyntax) -> String {
    let spelling = token.trimmedDescription
    if spelling.hasPrefix("`"), spelling.hasSuffix("`") {
        return spelling
    }
    return token.text
}

private func bindingName(
    for param: EnumCaseParameterSyntax,
    index: Int
) -> String {
    if let firstName = param.firstName?.text, firstName != "_" {
        return firstName
    }

    return param.secondName?.text ?? "v\(index)"
}

private func emittedLabel(for param: EnumCaseParameterSyntax) -> String? {
    guard let firstName = param.firstName?.text, firstName != "_" else {
        return nil
    }

    return firstName
}
