/// A declarative description of a `FlowStore` path suitable for value-level
/// serialization, deep-link plans, or state restoration.
///
/// `FlowStore.apply(_:)` is the canonical entry point that transforms a
/// `FlowPlan` into a sequence of navigation + modal commands, observing the
/// same invariants as `FlowStore.send(.reset(_:))`:
///
/// - At most one modal step is permitted.
/// - A modal step must be the final element of `steps`.
/// - All other steps must be `.push`.
///
/// Use ``init(validating:)`` (or ``validate(_:)``) to surface invariant
/// violations up front instead of waiting for `apply(_:)` to reject. The
/// permissive ``init(steps:)`` stays for callers that already trust the
/// origin of `steps` (e.g. an internal builder that constructed them).
public struct FlowPlan<R: Route>: Sendable, Equatable {
    /// Ordered steps describing the desired flow stack state.
    public var steps: [RouteStep<R>]

    /// Creates a new flow plan without validating the supplied steps.
    ///
    /// Equivalent to assigning ``steps`` directly. Prefer
    /// ``init(validating:)`` when `steps` originates from an external
    /// source (deep link, persisted state, network payload).
    public init(steps: [RouteStep<R>] = []) {
        self.steps = steps
    }

    /// Creates a new flow plan, throwing if `steps` violates the
    /// FlowStore invariants.
    ///
    /// - Throws: ``FlowPlanValidationError`` describing the first
    ///   violation encountered.
    public init(validating steps: [RouteStep<R>]) throws {
        try Self.validate(steps)
        self.steps = steps
    }

    /// Validates that `steps` satisfies the FlowStore invariants
    /// (at most one modal step, and only at the tail).
    ///
    /// Lives on ``FlowPlan`` so deep-link planners, state-restoration
    /// drivers, and tests can validate a candidate sequence without
    /// constructing a plan or hitting an authority.
    ///
    /// - Throws: ``FlowPlanValidationError`` describing the first
    ///   violation encountered. Returns normally on a valid
    ///   sequence (including the empty sequence).
    public static func validate(_ steps: [RouteStep<R>]) throws {
        let modalIndices = steps.enumerated()
            .filter { $0.element.isModal }
            .map(\.offset)
        if modalIndices.count > 1 {
            throw FlowPlanValidationError.tooManyModals
        }
        if let firstModal = modalIndices.first, firstModal != steps.count - 1 {
            throw FlowPlanValidationError.modalNotAtTail
        }
    }
}

/// Reason a candidate `[RouteStep]` sequence cannot become a
/// ``FlowPlan``.
///
/// Sits next to ``FlowRejectionReason`` but is distinct from it:
/// ``FlowRejectionReason`` describes runtime store-level rejections,
/// while ``FlowPlanValidationError`` is the up-front, throwing
/// counterpart used by validating constructors and Codable decode.
public enum FlowPlanValidationError: Error, Sendable, Equatable {
    /// More than one modal step appeared in the sequence.
    case tooManyModals
    /// A modal step appeared in a non-tail position.
    case modalNotAtTail
}

// MARK: - Codable (opt-in when the underlying route is Codable)

extension FlowPlan: Encodable where R: Encodable {}

extension FlowPlan: Decodable where R: Decodable {
    /// Decodes a ``FlowPlan`` and rejects sequences that violate the
    /// FlowStore invariants. Restoring a `FlowPlan` from disk or
    /// network now fails up front instead of producing a value that
    /// `apply(_:)` will silently reject later.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: FlowPlanCodingKeys.self)
        let decodedSteps = try container.decode([RouteStep<R>].self, forKey: .steps)
        do {
            try Self.validate(decodedSteps)
        } catch let error as FlowPlanValidationError {
            throw DecodingError.dataCorruptedError(
                forKey: FlowPlanCodingKeys.steps,
                in: container,
                debugDescription: "Decoded FlowPlan violates invariants: \(error)"
            )
        }
        self.steps = decodedSteps
    }
}

// File-private keys: kept out of the public surface and stable
// against synthesised-Encodable's choice (single property `steps`).
private enum FlowPlanCodingKeys: String, CodingKey {
    case steps
}
