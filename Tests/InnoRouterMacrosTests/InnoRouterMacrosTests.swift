// MARK: - InnoRouterMacrosTests.swift
// InnoRouter Macros Tests
// Copyright © 2025 Inno Squad. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

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

@Suite("Routable Macro Tests")
struct RoutableMacroTests {
    @Test("Basic enum expansion")
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
                        public static let home = CasePath<HomeRoute, Void>(
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
                        public static let settings = CasePath<HomeRoute, Void>(
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
                    casePath.extract(self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(self)
                }
            }

            extension HomeRoute: Route {
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw Skip("Macros not available")
        #endif
    }

    @Test("Associated values expansion")
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
                        public static let list = CasePath<ProductRoute, Void>(
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
                        public static let detail = CasePath<ProductRoute, String>(
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
                    casePath.extract(self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(self)
                }
            }

            extension ProductRoute: Route {
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw Skip("Macros not available")
        #endif
    }

    @Test("Multiple associated values expansion")
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
                        public static let main = CasePath<ProfileRoute, Void>(
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
                        public static let edit = CasePath<ProfileRoute, (String, Int)>(
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
                    casePath.extract(self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(self)
                }
            }

            extension ProfileRoute: Route {
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw Skip("Macros not available")
        #endif
    }

    @Test("Underscore external label expansion")
    func testRoutableWithUnderscoreExternalLabel() throws {
        #if canImport(InnoRouterMacrosPlugin)
        assertMacroExpansion(
            """
            @Routable
            enum DetailRoute {
                case detail(_ id: String)
            }
            """,
            expandedSource: """
            enum DetailRoute {
                case detail(_ id: String)

                public enum Cases {
                        public static let detail = CasePath<DetailRoute, String>(
                            embed: { value in
                                .detail(value)
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
                    casePath.extract(self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(self)
                }
            }

            extension DetailRoute: Route {
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw Skip("Macros not available")
        #endif
    }

    @Test("Mixed labels expansion")
    func testRoutableWithMixedLabels() throws {
        #if canImport(InnoRouterMacrosPlugin)
        assertMacroExpansion(
            """
            @Routable
            enum MixedRoute {
                case edit(_ id: String, section: Int)
            }
            """,
            expandedSource: """
            enum MixedRoute {
                case edit(_ id: String, section: Int)

                public enum Cases {
                        public static let edit = CasePath<MixedRoute, (String, Int)>(
                            embed: { value in
                                .edit(value.0, section: value.1)
                            },
                            extract: {
                                if case .edit(let id, let section) = $0 {
                                    return (id, section)
                                };
                                return nil
                            }
                        )
                }

                public func `is`<Value>(_ casePath: CasePath<Self, Value>) -> Bool {
                    casePath.extract(self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(self)
                }
            }

            extension MixedRoute: Route {
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw Skip("Macros not available")
        #endif
    }

    @Test("Rejects non-enum declarations")
    func testRoutableOnlyAppliesToEnum() throws {
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
        throw Skip("Macros not available")
        #endif
    }
}

// MARK: - CasePathable Macro Tests

@Suite("CasePathable Macro Tests")
struct CasePathableMacroTests {
    @Test("Basic enum expansion")
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
                        public static let home = CasePath<Destination, Void>(
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
                        public static let profile = CasePath<Destination, String>(
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
                    casePath.extract(self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(self)
                }
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw Skip("Macros not available")
        #endif
    }

    @Test("Underscore external label expansion")
    func testCasePathableWithUnderscoreExternalLabel() throws {
        #if canImport(InnoRouterMacrosPlugin)
        assertMacroExpansion(
            """
            @CasePathable
            enum Destination {
                case profile(_ userId: String)
            }
            """,
            expandedSource: """
            enum Destination {
                case profile(_ userId: String)

                public enum Cases {
                        public static let profile = CasePath<Destination, String>(
                            embed: { value in
                                .profile(value)
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
                    casePath.extract(self) != nil
                }

                public subscript <Value>(case casePath: CasePath<Self, Value>) -> Value? {
                    casePath.extract(self)
                }
            }
            """,
            macros: makeTestMacros()
        )
        #else
        throw Skip("Macros not available")
        #endif
    }

    @Test("Rejects non-enum declarations")
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
        throw Skip("Macros not available")
        #endif
    }
}
