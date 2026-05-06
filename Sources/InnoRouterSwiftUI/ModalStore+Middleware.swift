// MARK: - ModalStore+Middleware.swift
// InnoRouterSwiftUI - middleware registry CRUD layered over
// ModalStore.
// Copyright © 2026 Inno Squad. All rights reserved.
//
// Extracted from ModalStore.swift in the 4.2.0 cleanup so the
// store core does not have to host the middleware management
// surface alongside command execution.

import InnoRouterCore

extension ModalStore {

    @discardableResult
    public func addMiddleware(
        _ middleware: AnyModalMiddleware<M>,
        debugName: String? = nil
    ) -> ModalMiddlewareHandle {
        middlewareRegistry.add(middleware, debugName: debugName)
    }

    @discardableResult
    public func insertMiddleware(
        _ middleware: AnyModalMiddleware<M>,
        at index: Int,
        debugName: String? = nil
    ) -> ModalMiddlewareHandle {
        middlewareRegistry.insert(middleware, at: index, debugName: debugName)
    }

    @discardableResult
    public func removeMiddleware(_ handle: ModalMiddlewareHandle) -> AnyModalMiddleware<M>? {
        middlewareRegistry.remove(handle)
    }

    @discardableResult
    public func replaceMiddleware(
        _ handle: ModalMiddlewareHandle,
        with middleware: AnyModalMiddleware<M>,
        debugName: String? = nil
    ) -> Bool {
        middlewareRegistry.replace(handle, with: middleware, debugName: debugName)
    }

    @discardableResult
    public func moveMiddleware(_ handle: ModalMiddlewareHandle, to index: Int) -> Bool {
        middlewareRegistry.move(handle, to: index)
    }
}
