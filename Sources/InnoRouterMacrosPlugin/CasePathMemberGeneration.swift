// MARK: - CasePathMemberGeneration.swift
// InnoRouterMacrosPlugin - per-case CasePath member source
// generation, fed by the iteration layer.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// This file owns the *generation* layer: how a single
// ``CasePathEnumCase`` becomes the rendered Swift source string
// that the macro emits. It does not perform any syntax-tree
// inspection — that belongs in `CasePathEnumIteration.swift`.

import Foundation

internal func buildCasePathMember(
    _ enumCase: CasePathEnumCase,
    enumName: String,
    access: String
) -> String {
    let availabilityPrefix = enumCase.availabilityAttributes
        .map { "        \($0)\n" }
        .joined()

    if enumCase.parameters.isEmpty {
        return """
        \(availabilityPrefix)        \(access) static let \(enumCase.emittedName) = CasePath<\(enumName), Void>(
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
    \(availabilityPrefix)        \(access) static let \(enumCase.emittedName) = CasePath<\(enumName), \(tupleType)>(
                embed: { value in .\(enumCase.emittedName)(\(embedArgs)) },
                extract: { if case .\(enumCase.emittedName)(\(extractBindings)) = $0 { return \(returnValue) }; return nil }
            )
    """
}
