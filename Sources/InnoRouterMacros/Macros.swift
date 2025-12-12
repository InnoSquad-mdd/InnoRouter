// MARK: - Macros.swift
// InnoRouter Macros - Public Macro Declarations
// Copyright © 2025 Inno Squad. All rights reserved.

@_exported import InnoRouterCore

// MARK: - @Routable

/// Route enum에 CasePath 지원과 프로토콜 conformance를 자동 생성합니다.
///
/// ## 생성되는 것들
/// - `Cases` enum: 각 case에 대한 CasePath
/// - `is(_:)` 메서드: case 체크
/// - `subscript[case:]`: case의 associated value 추출
/// - `Route` conformance (`Hashable`/`Sendable` 포함)
///
/// ## Example
/// ```swift
/// @Routable
/// enum HomeRoute: Route {
///     case list
///     case detail(id: String)
///     case settings(section: SettingsSection)
/// }
///
/// // Usage
/// let route: HomeRoute = .detail(id: "123")
/// route[case: HomeRoute.Cases.detail]  // Optional("123")
/// route.is(HomeRoute.Cases.list)       // false
/// HomeRoute.Cases.detail          // CasePath<HomeRoute, String>
/// ```
@attached(member, names: named(Cases), named(`is`), named(subscript))
@attached(extension, conformances: Route)
public macro Routable() = #externalMacro(
    module: "InnoRouterMacrosPlugin",
    type: "RoutableMacro"
)

// MARK: - @CasePathable

/// Enum에 CasePath 지원을 추가합니다. @Routable의 경량 버전입니다.
///
/// Route 프로토콜 없이 일반 enum에도 사용 가능합니다.
///
/// ## Example
/// ```swift
/// @CasePathable
/// enum Destination {
///     case home
///     case profile(userId: String)
/// }
/// ```
@attached(member, names: named(Cases), named(`is`), named(subscript))
public macro CasePathable() = #externalMacro(
    module: "InnoRouterMacrosPlugin",
    type: "CasePathableMacro"
)
