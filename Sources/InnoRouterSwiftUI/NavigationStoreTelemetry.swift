import InnoRouterCore

enum NavigationStoreTelemetryEvent<R: Route>: Equatable {
    enum PathMismatchPolicy: String, Equatable {
        case replace
        case assertAndReplace
        case ignore
        case custom
    }

    enum PathMismatchResolution: Equatable {
        case single(NavigationCommand<R>)
        case batch([NavigationCommand<R>])
        case ignore

        var kind: String {
            switch self {
            case .single:
                return "single"
            case .batch:
                return "batch"
            case .ignore:
                return "ignore"
            }
        }
    }

    enum MiddlewareMutation: String, Equatable {
        case added
        case inserted
        case removed
        case replaced
        case moved
    }

    case pathMismatch(
        policy: PathMismatchPolicy,
        resolution: PathMismatchResolution,
        oldPath: [R],
        newPath: [R]
    )
    case middlewareMutation(
        action: MiddlewareMutation,
        metadata: NavigationMiddlewareMetadata,
        index: Int?
    )
}

typealias NavigationStoreTelemetryRecorder<R: Route> =
    @MainActor @Sendable (NavigationStoreTelemetryEvent<R>) -> Void
