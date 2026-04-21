@_spi(NavigationStoreInternals) import InnoRouterCore

@MainActor
final class NavigationMiddlewareRegistry<R: Route> {
    struct InterceptionOutcome {
        let command: NavigationCommand<R>
        let interception: NavigationInterception<R>
        let participantCount: Int
    }

    private struct Entry {
        let handle: NavigationMiddlewareHandle
        let debugName: String?
        let middleware: AnyNavigationMiddleware<R>

        init(registration: NavigationMiddlewareRegistration<R>) {
            self.handle = NavigationMiddlewareHandle()
            self.debugName = registration.debugName
            self.middleware = registration.middleware
        }

        init(middleware: AnyNavigationMiddleware<R>, debugName: String?) {
            self.handle = NavigationMiddlewareHandle()
            self.debugName = debugName
            self.middleware = middleware
        }

        var metadata: NavigationMiddlewareMetadata {
            NavigationMiddlewareMetadata(handle: handle, debugName: debugName)
        }

        func replacing(with middleware: AnyNavigationMiddleware<R>, debugName: String?) -> Self {
            Self(handle: handle, debugName: debugName, middleware: middleware)
        }

        private init(
            handle: NavigationMiddlewareHandle,
            debugName: String?,
            middleware: AnyNavigationMiddleware<R>
        ) {
            self.handle = handle
            self.debugName = debugName
            self.middleware = middleware
        }
    }

    private var entries: [Entry]
    private let telemetrySink: NavigationStoreTelemetrySink<R>

    init(
        registrations: [NavigationMiddlewareRegistration<R>],
        telemetrySink: NavigationStoreTelemetrySink<R>
    ) {
        self.entries = registrations.map(Entry.init)
        self.telemetrySink = telemetrySink
    }

    var handles: [NavigationMiddlewareHandle] {
        entries.map(\.handle)
    }

    var metadata: [NavigationMiddlewareMetadata] {
        entries.map(\.metadata)
    }

    @discardableResult
    func add(
        _ middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) -> NavigationMiddlewareHandle {
        let entry = Entry(middleware: middleware, debugName: debugName)
        entries.append(entry)
        telemetrySink.recordMiddlewareMutation(.added, metadata: entry.metadata, index: entries.count - 1)
        return entry.handle
    }

    @discardableResult
    func insert(
        _ middleware: AnyNavigationMiddleware<R>,
        at index: Int,
        debugName: String? = nil
    ) -> NavigationMiddlewareHandle {
        let entry = Entry(middleware: middleware, debugName: debugName)
        let insertionIndex = min(max(index, 0), entries.count)
        entries.insert(entry, at: insertionIndex)
        telemetrySink.recordMiddlewareMutation(.inserted, metadata: entry.metadata, index: insertionIndex)
        return entry.handle
    }

    @discardableResult
    func remove(_ handle: NavigationMiddlewareHandle) -> AnyNavigationMiddleware<R>? {
        guard let index = entries.firstIndex(where: { $0.handle == handle }) else {
            return nil
        }
        let removed = entries.remove(at: index)
        telemetrySink.recordMiddlewareMutation(.removed, metadata: removed.metadata, index: index)
        return removed.middleware
    }

    @discardableResult
    func replace(
        _ handle: NavigationMiddlewareHandle,
        with middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) -> Bool {
        guard let index = entries.firstIndex(where: { $0.handle == handle }) else {
            return false
        }
        entries[index] = entries[index].replacing(with: middleware, debugName: debugName)
        telemetrySink.recordMiddlewareMutation(.replaced, metadata: entries[index].metadata, index: index)
        return true
    }

    @discardableResult
    func move(_ handle: NavigationMiddlewareHandle, to index: Int) -> Bool {
        guard let currentIndex = entries.firstIndex(where: { $0.handle == handle }) else {
            return false
        }
        let targetIndex = min(max(index, 0), entries.count - 1)
        let entry = entries.remove(at: currentIndex)
        entries.insert(entry, at: targetIndex)
        telemetrySink.recordMiddlewareMutation(.moved, metadata: entry.metadata, index: targetIndex)
        return true
    }

    func intercept(
        _ command: NavigationCommand<R>,
        state: RouteStack<R>
    ) -> InterceptionOutcome {
        var currentCommand = command
        var participantCount = 0

        for entry in entries {
            let interception = entry.middleware.willExecute(currentCommand, state: state)
            participantCount += 1

            switch interception {
            case .proceed(let updatedCommand):
                currentCommand = updatedCommand
            case .cancel(let reason):
                let resolvedReason = resolveCancellationReason(reason, entry: entry)
                return InterceptionOutcome(
                    command: currentCommand,
                    interception: .cancel(resolvedReason),
                    participantCount: participantCount
                )
            }
        }

        return InterceptionOutcome(
            command: currentCommand,
            interception: .proceed(currentCommand),
            participantCount: participantCount
        )
    }

    func didExecute(
        _ command: NavigationCommand<R>,
        result: NavigationResult<R>,
        state: RouteStack<R>,
        participantCount: Int
    ) -> NavigationResult<R> {
        var currentResult = result
        for entry in entries.prefix(participantCount) {
            currentResult = entry.middleware.didExecute(command, result: currentResult, state: state)
        }
        return currentResult
    }

    func discardExecution(
        _ command: NavigationCommand<R>,
        result: NavigationResult<R>,
        state: RouteStack<R>,
        participantCount: Int
    ) {
        for entry in entries.prefix(participantCount) {
            entry.middleware.discardExecution(command, result: result, state: state)
        }
    }

    private func resolveCancellationReason(
        _ reason: NavigationCancellationReason<R>,
        entry: Entry
    ) -> NavigationCancellationReason<R> {
        switch reason {
        case .middleware(let debugName, let originalCommand):
            let resolvedName = debugName ?? entry.debugName
            return .middleware(debugName: resolvedName, command: originalCommand)
        case .conditionFailed:
            return .conditionFailed
        case .custom(let message):
            return .custom(message)
        }
    }
}
