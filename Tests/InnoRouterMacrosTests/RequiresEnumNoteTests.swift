// MARK: - RequiresEnumNoteTests.swift
// InnoRouterMacrosTests - protocol/actor note attached to .requiresEnum
// Copyright © 2026 Inno Squad. All rights reserved.

#if canImport(InnoRouterMacrosPlugin)

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InnoRouterMacrosPlugin

@Suite("@Routable / @CasePathable requiresEnum protocol/actor note")
struct RequiresEnumNoteTests {

    @Test("@Routable on a protocol attaches the manual-refactor note (no FixIt)")
    func routableOnProtocolEmitsNote() throws {
        assertMacroExpansion(
            """
            @Routable
            protocol NotAnEnum {
            }
            """,
            expandedSource: """
            protocol NotAnEnum {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "[InnoRouterMacro.E001] @Routable can only be applied to enum declarations",
                    line: 1,
                    column: 1,
                    notes: [
                        NoteSpec(
                            message: "Refactor manually — declaration shape differs from enum (`protocol` cannot be safely auto-replaced).",
                            line: 2,
                            column: 1
                        )
                    ],
                    fixIts: []
                )
            ],
            macros: makeTestMacros()
        )
    }

    @Test("@Routable on an actor attaches the manual-refactor note (no FixIt)")
    func routableOnActorEmitsNote() throws {
        assertMacroExpansion(
            """
            @Routable
            actor NotAnEnum {
            }
            """,
            expandedSource: """
            actor NotAnEnum {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "[InnoRouterMacro.E001] @Routable can only be applied to enum declarations",
                    line: 1,
                    column: 1,
                    notes: [
                        NoteSpec(
                            message: "Refactor manually — declaration shape differs from enum (`actor` cannot be safely auto-replaced).",
                            line: 2,
                            column: 1
                        )
                    ],
                    fixIts: []
                )
            ],
            macros: makeTestMacros()
        )
    }

    @Test("@CasePathable on an actor attaches the manual-refactor note")
    func casePathableOnActorEmitsNote() throws {
        assertMacroExpansion(
            """
            @CasePathable
            actor NotAnEnum {
            }
            """,
            expandedSource: """
            actor NotAnEnum {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "[InnoRouterMacro.E001] @CasePathable can only be applied to enum declarations",
                    line: 1,
                    column: 1,
                    notes: [
                        NoteSpec(
                            message: "Refactor manually — declaration shape differs from enum (`actor` cannot be safely auto-replaced).",
                            line: 2,
                            column: 1
                        )
                    ],
                    fixIts: []
                )
            ],
            macros: makeTestMacros()
        )
    }

    @Test("Struct misapplication still gets the keyword-replacement FixIt (no note)")
    func structKeepsFixItAndOmitsNote() throws {
        assertMacroExpansion(
            """
            @Routable
            struct NotAnEnum {
            }
            """,
            expandedSource: """
            struct NotAnEnum {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "[InnoRouterMacro.E001] @Routable can only be applied to enum declarations",
                    line: 1,
                    column: 1,
                    notes: [],
                    fixIts: [FixItSpec(message: "Change `struct` to `enum`")]
                )
            ],
            macros: makeTestMacros()
        )
    }
}

#endif
