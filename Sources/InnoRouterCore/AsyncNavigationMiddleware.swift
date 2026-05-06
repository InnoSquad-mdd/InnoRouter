// MARK: - AsyncNavigationMiddleware.swift
// InnoRouterCore - opt-in async middleware slot layered around the
// synchronous NavigationCommand pipeline.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// `NavigationMiddleware` is `@MainActor`-synchronous by design —
// the synchronous core keeps the command algebra deterministic and
// keeps the engine free of suspension points. That works for
// telemetry, validation, and rewriting, but rules out cleanly
// running an async policy gate (token refresh, remote AB
// resolution, async permission probe) at the middleware boundary.
//
// `AsyncNavigationMiddleware` is the opt-in slot for those policies.
// It does not change the synchronous engine: callers wire async
// middleware through ``AsyncNavigationMiddlewareExecutor``, which
// runs every async middleware's `willExecute` ahead of the store's
// synchronous execute, and every middleware's `didExecute` after.
// Synchronous middleware on the same store keeps running through
// the existing pipeline regardless of whether an async layer is
// also installed.

import Foundation

/// Opt-in async middleware contract. Conformers run their hooks
/// via ``AsyncNavigationMiddlewareExecutor`` and remain entirely
/// optional — `NavigationStore` keeps the synchronous middleware
/// pipeline intact and never invokes async middleware on its own.
@MainActor
public protocol AsyncNavigationMiddleware<RouteType>: Sendable {
    associatedtype RouteType: Route

    /// Async pre-execution hook. Runs before the synchronous
    /// ``NavigationStore/execute(_:)`` call. Returning
    /// ``NavigationInterception/proceed(_:)`` lets the next async
    /// middleware (or the synchronous engine) see the command;
    /// returning ``NavigationInterception/cancel(_:)`` stops the
    /// chain and surfaces the typed cancellation reason as the
    /// final result.
    func willExecute(
        _ command: NavigationCommand<RouteType>,
        state: RouteStack<RouteType>
    ) async -> NavigationInterception<RouteType>

    /// Async post-execution hook. Runs after the synchronous
    /// engine returns. Conformers can fold or rewrite the result;
    /// the value returned by the last middleware is what the
    /// caller of
    /// ``AsyncNavigationMiddlewareExecutor/execute(_:)`` observes.
    func didExecute(
        _ command: NavigationCommand<RouteType>,
        result: NavigationResult<RouteType>,
        state: RouteStack<RouteType>
    ) async -> NavigationResult<RouteType>
}

public extension AsyncNavigationMiddleware {
    /// Default no-op `didExecute` so a middleware that only needs
    /// an async pre-execution gate does not have to write a
    /// passthrough.
    func didExecute(
        _ command: NavigationCommand<RouteType>,
        result: NavigationResult<RouteType>,
        state: RouteStack<RouteType>
    ) async -> NavigationResult<RouteType> {
        result
    }
}
