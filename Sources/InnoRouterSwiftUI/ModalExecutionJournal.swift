import InnoRouterCore

struct ModalExecutionState<M: Route>: Equatable {
    let currentPresentation: ModalPresentation<M>?
    let queuedPresentations: [ModalPresentation<M>]
}

struct ModalExecutionJournal<M: Route> {
    let requestedCommand: ModalCommand<M>
    let effectiveCommand: ModalCommand<M>
    let result: ModalExecutionResult<M>
    let participantCount: Int
    let stateBefore: ModalExecutionState<M>
    let stateAfter: ModalExecutionState<M>
}
