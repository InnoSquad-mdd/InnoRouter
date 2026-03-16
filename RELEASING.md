# Releasing InnoRouter

This repository ships a Swift Package, versioned DocC documentation, and GitHub Releases from the same semver tag event.

## Release tag contract

Allowed tag format:

- `1.0.0`
- `2.1.3`

Disallowed tag format:

- any tag with a leading `v`
- `release-1.0.0`

The release workflow validates `GITHUB_REF_NAME` with `^[0-9]+\.[0-9]+\.[0-9]+$` and fails on anything else.

## What a release publishes

A release tag triggers:

1. code and documentation gates
2. versioned DocC build
3. `/latest/` DocC refresh
4. GitHub Pages deployment
5. GitHub Release creation

The library release and the documentation release are the same event.

## Pages structure

Published documentation lives at:

- `https://innosquadcorp.github.io/InnoRouter/`
- `https://innosquadcorp.github.io/InnoRouter/latest/`
- `https://innosquadcorp.github.io/InnoRouter/<version>/`

Each release version keeps its own documentation subtree. `latest` is updated to the newest released version.

## Required local checks

Run these before tagging:

```bash
swift test
./scripts/principle-gates.sh
./scripts/build-docc-site.sh --version preview
```

## CI and CD responsibilities

### CI

`principle-gates.yml`

- runs on pull requests and pushes to `main` and `develop`
- validates runtime tests, smoke builds, fail-fast behavior, and documentation gates

`docs-ci.yml`

- runs on pull requests and pushes to `main` and `develop`
- builds a preview DocC site with `--version preview`
- uploads the generated static site as an artifact

### CD

`release.yml`

- runs on semver tag pushes
- rebuilds and revalidates the package
- builds versioned DocC output
- merges new docs with existing released docs
- updates `/latest/`
- deploys GitHub Pages
- publishes a GitHub Release named `InnoRouter <version>`

## Documentation source of truth

The repository uses `README + DocC` together.

- `README.md`: overview, quick start, module map, release and CI entry points
- DocC: detailed module guides and API-oriented documentation
- `CLAUDE.md`: maintainer/agent quick reference
- `Docs/v2-principle-scorecard.md`: architecture and quality mapping

Migration guides are intentionally not part of this release process.

## Release checklist

- Public APIs match current README and DocC examples.
- All `.md` files use bare semver tags, not `v`-prefixed tags.
- `Examples/` still match current human-facing API usage.
- `ExamplesSmoke/` still compile and cover the same surface.
- All `.docc` catalogs build locally.
- `NavigationStore`, `ModalStore`, deep-link, effect, and macro docs reflect current symbols.
- Release notes links point to the current README, RELEASING guide, and DocC portal.

## GitHub Pages note

The workflow publishes the generated site to GitHub Pages and also keeps the rendered output mirrored in the `gh-pages` branch so versioned documentation can be preserved between releases.
