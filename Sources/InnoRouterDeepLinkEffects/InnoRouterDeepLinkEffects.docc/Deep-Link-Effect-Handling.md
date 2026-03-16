# Deep-link effect handling

@Metadata {
  @PageKind(article)
}

`DeepLinkEffectHandler` turns a `DeepLinkDecision` into a typed execution result.

Important result shapes include:

- `.executed`
- `.pending`
- `.rejected`
- `.unhandled`
- `.invalidURL`
- `.missingDeepLinkURL`
- `.noPendingDeepLink`

The handler keeps deep-link execution explicit:

- it does not hide pending replay
- it does not collapse rejection into generic failure
- it keeps batch execution payloads visible to the caller

Use `resumePendingDeepLinkIfAllowed` when auth state must be checked asynchronously before replaying a stored plan.
