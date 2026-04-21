import Foundation

@_spi(InternalTrace)
public enum InternalExecutionTraceDomain: String, Sendable, Equatable {
    case navigation
    case modal
    case flow
    case deepLink
}

@_spi(InternalTrace)
public struct InternalExecutionTraceContext: Sendable, Equatable {
    public let rootID: String
    public let spanID: String
    public let parentSpanID: String?
    public let domain: InternalExecutionTraceDomain

    public init(
        rootID: String,
        spanID: String,
        parentSpanID: String?,
        domain: InternalExecutionTraceDomain
    ) {
        self.rootID = rootID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.domain = domain
    }
}

@_spi(InternalTrace)
public enum InternalExecutionTraceRecord: Sendable, Equatable {
    case start(
        context: InternalExecutionTraceContext,
        operation: String,
        metadata: [String: String]
    )
    case finish(
        context: InternalExecutionTraceContext,
        operation: String,
        outcome: String
    )
}

@_spi(InternalTrace)
public typealias InternalExecutionTraceRecorder =
    @MainActor @Sendable (InternalExecutionTraceRecord) -> Void

@_spi(InternalTrace)
public enum InternalExecutionTrace {
    @TaskLocal public static var currentRootID: String?
    @TaskLocal public static var currentSpanID: String?

    @MainActor
    public static func withSpan<T>(
        domain: InternalExecutionTraceDomain,
        operation: String,
        recorder: InternalExecutionTraceRecorder?,
        metadata: [String: String] = [:],
        _ body: () -> T,
        outcome: (T) -> String
    ) -> T {
        let rootID = currentRootID ?? UUID().uuidString
        let parentSpanID = currentSpanID
        let spanID = UUID().uuidString
        let context = InternalExecutionTraceContext(
            rootID: rootID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            domain: domain
        )

        recorder?(.start(context: context, operation: operation, metadata: metadata))
        return $currentRootID.withValue(rootID) {
            $currentSpanID.withValue(spanID) {
                let value = body()
                recorder?(.finish(context: context, operation: operation, outcome: outcome(value)))
                return value
            }
        }
    }

    @MainActor
    public static func withSpan<T>(
        domain: InternalExecutionTraceDomain,
        operation: String,
        recorder: InternalExecutionTraceRecorder?,
        metadata: [String: String] = [:],
        _ body: () async -> T,
        outcome: @escaping (T) -> String
    ) async -> T {
        let rootID = currentRootID ?? UUID().uuidString
        let parentSpanID = currentSpanID
        let spanID = UUID().uuidString
        let context = InternalExecutionTraceContext(
            rootID: rootID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            domain: domain
        )

        recorder?(.start(context: context, operation: operation, metadata: metadata))
        return await $currentRootID.withValue(rootID) {
            await $currentSpanID.withValue(spanID) {
                let value = await body()
                recorder?(.finish(context: context, operation: operation, outcome: outcome(value)))
                return value
            }
        }
    }
}
