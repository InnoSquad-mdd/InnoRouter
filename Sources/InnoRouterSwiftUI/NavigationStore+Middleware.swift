// MARK: - NavigationStore+Middleware.swift
// InnoRouterSwiftUI - middleware registry CRUD layered over
// NavigationStore.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// Extracted from NavigationStore.swift in the 4.1.0 cleanup so the
// store core does not have to host the middleware management
// surface alongside command execution. Every method here is a
// thin pass-through to the internal `middlewareRegistry` so the
// audit surface stays small.

import InnoRouterCore

extension NavigationStore {

    /// Adds `middleware` to the end of this store's middleware chain.
    ///
    /// - Parameters:
    ///   - middleware: Type-erased navigation middleware that can observe,
    ///     rewrite, or cancel commands before they reach the engine.
    ///   - debugName: Optional label surfaced in middleware mutation
    ///     observations and cancellation diagnostics.
    /// - Returns: A handle that can later remove, replace, or move the
    ///   registered middleware.
    @discardableResult
    public func addMiddleware(
        _ middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) -> NavigationMiddlewareHandle {
        middlewareRegistry.add(middleware, debugName: debugName)
    }

    /// Inserts `middleware` at the requested zero-based position.
    ///
    /// - Parameters:
    ///   - middleware: Type-erased navigation middleware to install.
    ///   - index: Zero-based insertion position. Values below zero insert at
    ///     the front; values past the current count append to the end.
    ///   - debugName: Optional label surfaced in middleware mutation
    ///     observations and cancellation diagnostics.
    /// - Returns: A handle that can later remove, replace, or move the
    ///   registered middleware.
    @discardableResult
    public func insertMiddleware(
        _ middleware: AnyNavigationMiddleware<R>,
        at index: Int,
        debugName: String? = nil
    ) -> NavigationMiddlewareHandle {
        middlewareRegistry.insert(middleware, at: index, debugName: debugName)
    }

    /// Removes the middleware registered with `handle`.
    ///
    /// - Parameter handle: Handle returned from `addMiddleware` or
    ///   `insertMiddleware`.
    /// - Returns: The removed middleware when the handle was still registered,
    ///   otherwise `nil`.
    @discardableResult
    public func removeMiddleware(_ handle: NavigationMiddlewareHandle) -> AnyNavigationMiddleware<R>? {
        middlewareRegistry.remove(handle)
    }

    /// Replaces the middleware registered with `handle`.
    ///
    /// - Parameters:
    ///   - handle: Handle identifying the existing registration.
    ///   - middleware: Replacement middleware to install in the same slot.
    ///   - debugName: Optional replacement label surfaced in middleware
    ///     mutation observations and cancellation diagnostics.
    /// - Returns: `true` when the handle was registered and the replacement
    ///   succeeded, otherwise `false`.
    @discardableResult
    public func replaceMiddleware(
        _ handle: NavigationMiddlewareHandle,
        with middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) -> Bool {
        middlewareRegistry.replace(handle, with: middleware, debugName: debugName)
    }

    /// Moves the middleware registered with `handle` to `index`.
    ///
    /// - Parameters:
    ///   - handle: Handle identifying the existing registration.
    ///   - index: Zero-based destination position. Values below zero move to
    ///     the front; values past the current count move to the end.
    /// - Returns: `true` when the handle was registered and the move
    ///   succeeded, otherwise `false`.
    @discardableResult
    public func moveMiddleware(_ handle: NavigationMiddlewareHandle, to index: Int) -> Bool {
        middlewareRegistry.move(handle, to: index)
    }
}
