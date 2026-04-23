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
        buildCasePathMembers(
            macroName: "CasePathable",
            node: node,
            declaration: declaration,
            context: context
        )
    }
}

// Diagnostics moved to `MacroDiagnostic.swift` (shared between
// @Routable and @CasePathable).
