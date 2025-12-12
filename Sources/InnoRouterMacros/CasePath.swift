// MARK: - CasePath.swift
// InnoRouter Macros - CasePath Type
// Copyright © 2025 Inno Squad. All rights reserved.

import Foundation

// MARK: - CasePath

/// Enum case에 대한 KeyPath-like 접근을 제공하는 타입입니다.
///
/// `@Routable` 또는 `@CasePathable` 매크로가 자동으로 `CasePath` 인스턴스를 생성합니다.
///
/// ## Example
/// ```swift
/// @Routable
/// enum Route {
///     case detail(id: String)
/// }
///
/// let casePath = Route.Cases.detail  // CasePath<Route, String>
///
/// // Embed: value → enum
/// let route = casePath.embed("123")  // Route.detail(id: "123")
///
/// // Extract: enum → value?
/// casePath.extract(from: route)      // Optional("123")
/// ```
public struct CasePath<Root, Value>: Sendable {
    
    /// Associated value를 enum case로 변환합니다.
    public let embed: @Sendable (Value) -> Root
    
    /// Enum에서 associated value를 추출합니다.
    public let extract: @Sendable (Root) -> Value?
    
    /// CasePath를 생성합니다.
    ///
    /// - Parameters:
    ///   - embed: Value를 Root enum case로 변환하는 클로저
    ///   - extract: Root에서 Value를 추출하는 클로저
    public init(
        embed: @escaping @Sendable (Value) -> Root,
        extract: @escaping @Sendable (Root) -> Value?
    ) {
        self.embed = embed
        self.extract = extract
    }
}

// MARK: - Convenience Extensions

public extension CasePath where Value == Void {
    /// Void associated value를 위한 간편 embed
    func callAsFunction() -> Root {
        embed(())
    }
}

public extension CasePath {
    /// CasePath 체이닝을 위한 appending
    ///
    /// ```swift
    /// let path = Route.Cases.settings.appending(path: Settings.Cases.privacy)
    /// ```
    func appending<AppendedValue>(
        path: CasePath<Value, AppendedValue>
    ) -> CasePath<Root, AppendedValue> {
        CasePath<Root, AppendedValue>(
            embed: { self.embed(path.embed($0)) },
            extract: { self.extract($0).flatMap(path.extract) }
        )
    }
}
