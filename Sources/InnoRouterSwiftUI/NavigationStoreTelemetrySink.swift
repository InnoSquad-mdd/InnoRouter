import OSLog

import InnoRouterCore

@MainActor
final class NavigationStoreTelemetrySink<R: Route> {
    private let logger: Logger?
    private let recorder: NavigationStoreTelemetryRecorder<R>?

    init(
        logger: Logger?,
        recorder: NavigationStoreTelemetryRecorder<R>? = nil
    ) {
        self.logger = logger
        self.recorder = recorder
    }

    func recordPathMismatch(
        policy: NavigationStoreTelemetryEvent<R>.PathMismatchPolicy,
        resolution: NavigationPathMismatchResolution<R>,
        oldPath: [R],
        newPath: [R]
    ) {
        let eventResolution = Self.makeTelemetryResolution(from: resolution)
        recorder?(
            .pathMismatch(
                policy: policy,
                resolution: eventResolution,
                oldPath: oldPath,
                newPath: newPath
            )
        )

        guard let logger else { return }
        logger.notice(
            """
            navigation path mismatch \
            policy=\(policy.rawValue, privacy: .public) \
            resolution=\(eventResolution.kind, privacy: .public) \
            oldPathCount=\(oldPath.count, privacy: .public) \
            oldPathSummary=\(Self.pathSummary(for: oldPath), privacy: .public) \
            newPathCount=\(newPath.count, privacy: .public) \
            newPathSummary=\(Self.pathSummary(for: newPath), privacy: .public)
            """
        )
    }

    func recordMiddlewareMutation(
        _ action: NavigationStoreTelemetryEvent<R>.MiddlewareMutation,
        metadata: NavigationMiddlewareMetadata,
        index: Int?
    ) {
        recorder?(
            .middlewareMutation(action: action, metadata: metadata, index: index)
        )

        guard let logger else { return }
        logger.notice(
            """
            middleware mutation \
            action=\(action.rawValue, privacy: .public) \
            handle=\(metadata.handle.logValue, privacy: .public) \
            debugName=\(metadata.debugName ?? "nil", privacy: .public) \
            index=\(String(index ?? -1), privacy: .public)
            """
        )
    }

    private static func makeTelemetryResolution(
        from resolution: NavigationPathMismatchResolution<R>
    ) -> NavigationStoreTelemetryEvent<R>.PathMismatchResolution {
        switch resolution {
        case .single(let command):
            return .single(command)
        case .batch(let commands):
            return .batch(commands)
        case .ignore:
            return .ignore
        }
    }

    private static func pathSummary(for path: [R]) -> String {
        path.map(routeSummary(for:)).joined(separator: " -> ")
    }

    private static func routeSummary(for route: R) -> String {
        let description = String(describing: route)
        return description
            .split(separator: "(", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? description
    }
}
