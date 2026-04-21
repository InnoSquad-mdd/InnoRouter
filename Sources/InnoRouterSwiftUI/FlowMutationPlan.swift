import InnoRouterCore

struct FlowMutationPlan<R: Route> {
    let oldPath: [RouteStep<R>]
    let rejectionReason: FlowRejectionReason?
    let navigationJournal: NavigationExecutionJournal<R>?
    let modalJournals: [ModalExecutionJournal<R>]

    static func rejected(
        oldPath: [RouteStep<R>],
        reason: FlowRejectionReason
    ) -> Self {
        Self(
            oldPath: oldPath,
            rejectionReason: reason,
            navigationJournal: nil,
            modalJournals: []
        )
    }

    static func commit(
        oldPath: [RouteStep<R>],
        navigationJournal: NavigationExecutionJournal<R>? = nil,
        modalJournals: [ModalExecutionJournal<R>] = []
    ) -> Self {
        Self(
            oldPath: oldPath,
            rejectionReason: nil,
            navigationJournal: navigationJournal,
            modalJournals: modalJournals
        )
    }
}
