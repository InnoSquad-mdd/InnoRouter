# Security policy

## Supported versions

| Version | Status | Security fixes |
|---|---|---|
| 3.x | active | yes |
| <= 2.x | not supported (internal milestone) | no |

The 3.x line is the first publicly supported release line. Earlier
tagged versions (`1.0.0`, `2.0.0`) were internal milestones and do
not receive security updates.

## Reporting a vulnerability

Please **do not file a public GitHub issue** for security findings.

Send a report to the maintainers using GitHub's [private
vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
flow:

1. Go to the InnoRouter repository on GitHub.
2. Open the **Security** tab.
3. Click **Report a vulnerability**.
4. Describe the issue, an estimate of impact, and a reproduction.

A maintainer will acknowledge your report within 5 business days and
follow up with a remediation timeline. For high-severity issues
affecting deep-link routing, modal authority, or middleware
cancellation, expect a same-week patch on the latest 3.x line.

## Scope

- Issues in `Sources/*` that compromise navigation or modal
  correctness, deep-link authentication enforcement, or runtime
  isolation guarantees.
- Issues in `Sources/InnoRouterMacrosPlugin/*` that produce code
  the compiler would reject *or* code that silently bypasses
  correctness contracts (for example, a generated `CasePath` that
  embeds the wrong case).

## Out of scope

- Issues in example apps under `Examples/` or `ExamplesSmoke/`.
  These exist as fixtures and are not deployed as products.
- Issues in third-party dependencies (`swift-syntax`). Report those
  upstream and link the upstream advisory in your InnoRouter report.

## Disclosure

After a fix lands, the corresponding GitHub Security Advisory will
list affected versions, the patched version, the credit line for
the reporter (with the reporter's consent), and any required call-
site migrations.
