import InnoRouterCore

struct FlowMutationPlan<R: Route> {
    let oldPath: [RouteStep<R>]
    let rejectionReason: FlowRejectionReason?
    let queueCoalescePolicyEligible: Bool
    let navigationJournal: NavigationExecutionJournal<R>?
    let modalJournals: [ModalExecutionJournal<R>]

    static func rejected(
        oldPath: [RouteStep<R>],
        reason: FlowRejectionReason,
        queueCoalescePolicyEligible: Bool = false
    ) -> Self {
        Self(
            oldPath: oldPath,
            rejectionReason: reason,
            queueCoalescePolicyEligible: queueCoalescePolicyEligible,
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
            queueCoalescePolicyEligible: false,
            navigationJournal: navigationJournal,
            modalJournals: modalJournals
        )
    }
}
