// MARK: - InnoRouterMacrosTests.swift
// InnoRouter Macros Tests
// Copyright © 2025 Inno Squad. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(InnoRouterMacrosPlugin)
@testable import InnoRouterMacrosPlugin

func makeTestMacros() -> [String: Macro.Type] {
    [
        "Routable": RoutableMacro.self,
        "CasePathable": CasePathableMacro.self,
    ]
}
#endif

// MARK: - Routable Macro Tests

final class RoutableMacroTests: XCTestCase {
    
    func testRoutableBasicEnum() throws {
        #if canImport(InnoRouterMacrosPlugin)
        assertMacroExpansion(
            """
            @Routable
            enum HomeRoute {
                case home
                case settings
            }
            """,
            expandedSource: """
            enum HomeRoute {
                case home
                case settings

                public enum Cases {
                        public static let home = CasePath<Self, Void>(
                            embed: { _ in
                                .home
                            },
                            extract: {
                                if case .home = $0 {
                                    return ()
                                };
                                return nil
                            }
                        )
                        public static let settings = CasePath<Self, Void>(
                            embed: { _ in
                                .settings
                            },
                            extract: {
                                if case .settings = $0 {
                                    return ()
                                };
                                return nil
                            }
                        )
                }

                public func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
                    casePath.extract(from: self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(from: self)
                }
            }

            extension HomeRoute: Route {
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw XCTSkip("Macros not available")
        #endif
    }
    
    func testRoutableWithAssociatedValues() throws {
        #if canImport(InnoRouterMacrosPlugin)
        assertMacroExpansion(
            """
            @Routable
            enum ProductRoute {
                case list
                case detail(id: String)
            }
            """,
            expandedSource: """
            enum ProductRoute {
                case list
                case detail(id: String)

                public enum Cases {
                        public static let list = CasePath<Self, Void>(
                            embed: { _ in
                                .list
                            },
                            extract: {
                                if case .list = $0 {
                                    return ()
                                };
                                return nil
                            }
                        )
                        public static let detail = CasePath<Self, String>(
                            embed: { value in
                                .detail(id: value)
                            },
                            extract: {
                                if case .detail(let id) = $0 {
                                    return id
                                };
                                return nil
                            }
                        )
                }

                public func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
                    casePath.extract(from: self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(from: self)
                }
            }

            extension ProductRoute: Route {
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw XCTSkip("Macros not available")
        #endif
    }
    
    func testRoutableWithMultipleAssociatedValues() throws {
        #if canImport(InnoRouterMacrosPlugin)
        assertMacroExpansion(
            """
            @Routable
            enum ProfileRoute {
                case main
                case edit(userId: String, section: Int)
            }
            """,
            expandedSource: """
            enum ProfileRoute {
                case main
                case edit(userId: String, section: Int)

                public enum Cases {
                        public static let main = CasePath<Self, Void>(
                            embed: { _ in
                                .main
                            },
                            extract: {
                                if case .main = $0 {
                                    return ()
                                };
                                return nil
                            }
                        )
                        public static let edit = CasePath<Self, (String, Int)>(
                            embed: { value in
                                .edit(userId: value.0, section: value.1)
                            },
                            extract: {
                                if case .edit(let userId, let section) = $0 {
                                    return (userId, section)
                                };
                                return nil
                            }
                        )
                }

                public func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
                    casePath.extract(from: self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(from: self)
                }
            }

            extension ProfileRoute: Route {
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw XCTSkip("Macros not available")
        #endif
    }
    
    func testRoutableOnlyAppliestoEnum() throws {
        #if canImport(InnoRouterMacrosPlugin)
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
                DiagnosticSpec(message: "@Routable can only be applied to enum declarations", line: 1, column: 1)
            ],
            macros: makeTestMacros()
        )
        #else
        throw XCTSkip("Macros not available")
        #endif
    }
}

// MARK: - CasePathable Macro Tests

final class CasePathableMacroTests: XCTestCase {
    
    func testCasePathableBasicEnum() throws {
        #if canImport(InnoRouterMacrosPlugin)
        assertMacroExpansion(
            """
            @CasePathable
            enum Destination {
                case home
                case profile(userId: String)
            }
            """,
            expandedSource: """
            enum Destination {
                case home
                case profile(userId: String)

                public enum Cases {
                        public static let home = CasePath<Self, Void>(
                            embed: { _ in
                                .home
                            },
                            extract: {
                                if case .home = $0 {
                                    return ()
                                };
                                return nil
                            }
                        )
                        public static let profile = CasePath<Self, String>(
                            embed: { value in
                                .profile(userId: value)
                            },
                            extract: {
                                if case .profile(let userId) = $0 {
                                    return userId
                                };
                                return nil
                            }
                        )
                }

                public func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
                    casePath.extract(from: self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(from: self)
                }
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw XCTSkip("Macros not available")
        #endif
    }
    
    func testCasePathableOnlyAppliesToEnum() throws {
        #if canImport(InnoRouterMacrosPlugin)
        assertMacroExpansion(
            """
            @CasePathable
            class NotAnEnum {
            }
            """,
            expandedSource: """
            class NotAnEnum {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@CasePathable can only be applied to enum declarations", line: 1, column: 1)
            ],
            macros: makeTestMacros()
        )
        #else
        throw XCTSkip("Macros not available")
        #endif
    }
}
