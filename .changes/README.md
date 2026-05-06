# Changelog fragments

Each PR that touches the public API, observable behaviour, or
contributor experience drops a small `.md` file under `.changes/`
describing the change in CHANGELOG-ready prose. The release
process collates the fragments under a `## <version>` heading at
release-cut time, deletes the fragment files, and commits the
updated `CHANGELOG.md`.

This avoids the perennial merge conflicts on `CHANGELOG.md` itself
(every concurrent PR otherwise contends for the same line) and
keeps the changelog narrative human-curated rather than
machine-generated.

## File format

```
.changes/<short-slug>.<category>.md
```

Where `<category>` is one of: `added`, `changed`, `fixed`,
`deprecated`, `removed`, `security`. The slug should describe
the change (kebab-case, ~3–6 words):

```
.changes/async-middleware-slot.added.md
.changes/flow-reentrancy-counter.changed.md
.changes/legacy-effect-products.deprecated.md
```

The body of the fragment is one or two sentences in the same
voice as the existing `CHANGELOG.md` entries — past tense,
imperative-ish, focused on what the user observes.

## Categories

- `added` — new public types, methods, properties, enum cases.
- `changed` — observable behavior change in an existing public
  surface (still compatible — breaking changes are 5.0 territory).
- `fixed` — bug whose previous behavior was documented as
  incorrect.
- `deprecated` — public surface marked `@available(*, deprecated)`
  in this minor; will be removed in a future major.
- `removed` — public surface dropped (5.0 only).
- `security` — security-sensitive change. See `SECURITY.md`.

## When a PR does NOT need a fragment

- Doc-only changes (`README`, `Docs/`, `.docc` articles only).
- Internal refactor with no observable change (file moves,
  extension splits, tightened internal types).
- Test-only changes.
- CI / tooling changes.

If unsure, add one — small fragments cost almost nothing and the
release-cut script can drop empty categories.

## Release-cut workflow (maintainer-side)

Until the automated collation script lands:

1. `cat .changes/*.added.md` — paste under `### Added`
2. `cat .changes/*.changed.md` — paste under `### Changed`
3. `cat .changes/*.fixed.md` — paste under `### Fixed`
4. `cat .changes/*.deprecated.md` — paste under `### Deprecated`
5. `rm .changes/*.{added,changed,fixed,deprecated,removed,security}.md`
6. Commit on the release branch with message
   `chore(changelog): collate fragments for <version>`.

A `towncrier`-style automation can replace this manual step in a
future commit; the directory layout above is already shaped for it.
