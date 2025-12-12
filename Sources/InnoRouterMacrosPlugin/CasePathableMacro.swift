// MARK: - CasePathableMacro.swift
// InnoRouter Macros - @CasePathable Implementation
// Copyright © 2025 Inno Squad. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

// MARK: - CasePathable Macro

/// `@CasePathable` 매크로는 enum의 각 case에 대해 KeyPath-like 접근을 제공합니다.
/// @Routable의 경량 버전으로, Route 프로토콜 없이 사용 가능합니다.
///
/// ## Example
/// ```swift
/// @CasePathable
/// enum Destination {
///     case home
///     case profile(userId: String)
///     case settings(section: String, detail: Bool)
/// }
///
/// let dest: Destination = .profile(userId: "123")
/// dest[case: \.profile]  // Optional("123")
/// dest.is(\.home)        // false
/// ```
public struct CasePathableMacro: MemberMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: CasePathableDiagnostic.requiresEnum
                )
            )
            return []
        }
        
        let cases = enumDecl.memberBlock.members
            .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
            .flatMap { $0.elements }
        
        guard !cases.isEmpty else {
            return []
        }
        
        var casesMembers: [String] = []
        
        for enumCase in cases {
            let caseName = enumCase.name.text
            
            if let params = enumCase.parameterClause?.parameters, !params.isEmpty {
                let paramTypes = params.map { $0.type.trimmedDescription }.joined(separator: ", ")
                let tupleType = params.count == 1 ? paramTypes : "(\(paramTypes))"
                
                let extractBindings = params.enumerated().map { idx, param -> String in
                    param.firstName?.text ?? "v\(idx)"
                }.map { "let \($0)" }.joined(separator: ", ")
                
                let extractReturn = params.enumerated().map { idx, param -> String in
                    param.firstName?.text ?? "v\(idx)"
                }.joined(separator: ", ")
                
                let returnValue = params.count == 1 ? extractReturn : "(\(extractReturn))"
                
                let embedArgs = params.enumerated().map { idx, param -> String in
                    let label = param.firstName?.text
                    if params.count == 1 {
                        return label.map { "\($0): value" } ?? "value"
                    } else {
                        return label.map { "\($0): value.\(idx)" } ?? "value.\(idx)"
                    }
                }.joined(separator: ", ")
                
                casesMembers.append("""
                        public static let \(caseName) = CasePath<Self, \(tupleType)>(
                            embed: { value in .\(caseName)(\(embedArgs)) },
                            extract: { if case .\(caseName)(\(extractBindings)) = $0 { return \(returnValue) }; return nil }
                        )
                """)
            } else {
                casesMembers.append("""
                        public static let \(caseName) = CasePath<Self, Void>(
                            embed: { _ in .\(caseName) },
                            extract: { if case .\(caseName) = $0 { return () }; return nil }
                        )
                """)
            }
        }
        
        let casesEnum: DeclSyntax = """
            public enum Cases {
            \(raw: casesMembers.joined(separator: "\n"))
            }
            """
        
        let isMethod: DeclSyntax = """
            public func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
                casePath.extract(from: self) != nil
            }
            """
        
        let subscriptDecl: DeclSyntax = """
            public subscript<Value>(case casePath: CasePath<Self, Value>) -> Value? {
                casePath.extract(from: self)
            }
            """
        
        return [casesEnum, isMethod, subscriptDecl]
    }
}

// MARK: - Diagnostics

enum CasePathableDiagnostic: String, DiagnosticMessage {
    case requiresEnum
    
    var severity: DiagnosticSeverity { .error }
    
    var message: String {
        switch self {
        case .requiresEnum:
            return "@CasePathable can only be applied to enum declarations"
        }
    }
    
    var diagnosticID: MessageID {
        MessageID(domain: "InnoRouterMacros", id: rawValue)
    }
}
