// MARK: - NavigationStore+Middleware.swift
// InnoRouterSwiftUI - middleware registry CRUD layered over
// NavigationStore.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// Extracted from NavigationStore.swift in the 4.2.0 cleanup so the
// store core does not have to host the middleware management
// surface alongside command execution. Every method here is a
// thin pass-through to the internal `middlewareRegistry` so the
// audit surface stays small.

import InnoRouterCore

extension NavigationStore {

    @discardableResult
    public func addMiddleware(
        _ middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) -> NavigationMiddlewareHandle {
        middlewareRegistry.add(middleware, debugName: debugName)
    }

    @discardableResult
    public func insertMiddleware(
        _ middleware: AnyNavigationMiddleware<R>,
        at index: Int,
        debugName: String? = nil
    ) -> NavigationMiddlewareHandle {
        middlewareRegistry.insert(middleware, at: index, debugName: debugName)
    }

    @discardableResult
    public func removeMiddleware(_ handle: NavigationMiddlewareHandle) -> AnyNavigationMiddleware<R>? {
        middlewareRegistry.remove(handle)
    }

    @discardableResult
    public func replaceMiddleware(
        _ handle: NavigationMiddlewareHandle,
        with middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) -> Bool {
        middlewareRegistry.replace(handle, with: middleware, debugName: debugName)
    }

    @discardableResult
    public func moveMiddleware(_ handle: NavigationMiddlewareHandle, to index: Int) -> Bool {
        middlewareRegistry.move(handle, to: index)
    }
}
