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
        buildCasePathMembers(
            macroName: "Routable",
            node: node,
            declaration: declaration,
            context: context
        )
    }
    
    // MARK: - Extension Macro
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else { return [] }
        // Generic enums are diagnosed in the member-macro pass; skip synthesising
        // a `Route` conformance extension so the compiler doesn't see a partial
        // expansion alongside the diagnostic.
        guard enumDecl.genericParameterClause == nil else { return [] }

        let extensionDecl = try ExtensionDeclSyntax("extension \(type): Route {}")
        return [extensionDecl]
    }
}

// Diagnostics moved to `MacroDiagnostic.swift` (shared between
// @Routable and @CasePathable).
