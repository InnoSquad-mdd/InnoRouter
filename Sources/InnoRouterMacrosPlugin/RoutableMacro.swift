// MARK: - RoutableMacro.swift
// InnoRouter Macros - @Routable Implementation
// Copyright © 2025 Inno Squad. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

// MARK: - Routable Macro

/// `@Routable` 매크로는 Route enum에 다음을 자동 생성합니다:
/// - `Cases` enum: 각 case에 대한 CasePath
/// - `allCases` static property (associated value 없는 경우만)
/// - `description` computed property
///
/// ## Example
/// ```swift
/// @Routable
/// enum HomeRoute: Route {
///     case list
///     case detail(id: String)
///     case settings
/// }
///
/// // Generated:
/// extension HomeRoute {
///     enum Cases {
///         static let list = CasePath<HomeRoute, Void> { .list } extract: { ... }
///         static let detail = CasePath<HomeRoute, String> { .detail(id: $0) } extract: { ... }
///     }
/// }
/// ```
public struct RoutableMacro: MemberMacro, ExtensionMacro {
    
    // MARK: - Member Macro
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // enum인지 확인
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: RoutableDiagnostic.requiresEnum
                )
            )
            return []
        }
        
        // case들 추출
        let cases = enumDecl.memberBlock.members
            .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
            .flatMap { $0.elements }
        
        guard !cases.isEmpty else {
            return []
        }
        
        // Cases enum 생성
        var casesMembers: [String] = []
        
        for enumCase in cases {
            let caseName = enumCase.name.text
            
            if let params = enumCase.parameterClause?.parameters, !params.isEmpty {
                // Associated value가 있는 case
                let paramTypes = params.map { param -> String in
                    param.type.trimmedDescription
                }.joined(separator: ", ")
                
                let tupleType = params.count == 1 ? paramTypes : "(\(paramTypes))"
                
                // Extract 로직
                let extractBindings = params.enumerated().map { idx, param -> String in
                    let label = param.firstName?.text
                    if let label = label {
                        return "let \(label)"
                    } else {
                        return "let v\(idx)"
                    }
                }.joined(separator: ", ")
                
                let extractReturn = params.enumerated().map { idx, param -> String in
                    if let label = param.firstName?.text {
                        return label
                    } else {
                        return "v\(idx)"
                    }
                }.joined(separator: ", ")
                
                let returnValue = params.count == 1 ? extractReturn : "(\(extractReturn))"
                
                // Embed 로직
                let embedArgs = params.enumerated().map { idx, param -> String in
                    let label = param.firstName?.text
                    if params.count == 1 {
                        if let label = label {
                            return "\(label): value"
                        } else {
                            return "value"
                        }
                    } else {
                        if let label = label {
                            return "\(label): value.\(idx)"
                        } else {
                            return "value.\(idx)"
                        }
                    }
                }.joined(separator: ", ")
                
                casesMembers.append("""
                        public static let \(caseName) = CasePath<Self, \(tupleType)>(
                            embed: { value in .\(caseName)(\(embedArgs)) },
                            extract: { if case .\(caseName)(\(extractBindings)) = $0 { return \(returnValue) }; return nil }
                        )
                """)
            } else {
                // Associated value가 없는 case
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
        
        // is 메서드 생성
        let isMethod: DeclSyntax = """
            public func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
                casePath.extract(from: self) != nil
            }
            """
        
        // subscript 생성
        let subscriptDecl: DeclSyntax = """
            public subscript<Value>(case casePath: CasePath<Self, Value>) -> Value? {
                casePath.extract(from: self)
            }
            """
        
        return [casesEnum, isMethod, subscriptDecl]
    }
    
    // MARK: - Extension Macro
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.as(EnumDeclSyntax.self) != nil else { return [] }

        let extensionDecl = try ExtensionDeclSyntax("extension \(type): Route {}")
        return [extensionDecl]
    }
}

// MARK: - Diagnostics

enum RoutableDiagnostic: String, DiagnosticMessage {
    case requiresEnum
    
    var severity: DiagnosticSeverity { .error }
    
    var message: String {
        switch self {
        case .requiresEnum:
            return "@Routable can only be applied to enum declarations"
        }
    }
    
    var diagnosticID: MessageID {
        MessageID(domain: "InnoRouterMacros", id: rawValue)
    }
}
