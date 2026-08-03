# ios-factory

A shared, private repo for reusable iOS release tooling. Roompiece is the first consumer; more apps are expected to onboard onto the same pipeline over time. This README is a living status doc — kept current as tickets close, so an agent picking this repo up cold (or the human) doesn't have to reconstruct history from the issue tracker.

## What this repo is for right now

CI/CD + App Store submission only: a reusable GitHub Actions workflow + Fastlane release lane that any app repo can call to go from a pushed version tag to a TestFlight build, plus `setup-ios-cicd` — a Claude Code skill that wires a new app repo onto it.

The wider "app factory" vision (design system generator, screen generators, ASO screenshot reuse, Firebase/PostHog scaffolding for new apps) is out of scope here — future work, tracked separately once this slice ships. See the spec's Further Notes for the full picture.

## Where the decisions came from

- **Spec:** [Reusable iOS CI/CD + App Store submission](https://github.com/roompiece/roompiece/issues/94) (lives on `roompiece/roompiece`'s tracker — that's where this effort was scoped and speced from)
- **Full decision trail:** [Wayfinder map #87](https://github.com/roompiece/roompiece/issues/87) and its six resolved tickets (#88–#93) — signing strategy, secrets/config split, test gate, version derivation, and the scaffolding-skill design

## Current status

**Done:**
- Repo created (private, `main` default branch)
- `AGENTS.md` + `docs/agents/{issue-tracker,triage-labels,domain}.md` scaffolded — GitHub tracker (this repo), default triage labels, single-context domain docs
- Implementation broken into 2 tracer-bullet tickets, published to this repo's tracker:
  - [#1 — Parameterized release pipeline: tag push on Roompiece reaches TestFlight](https://github.com/niemax/ios-factory/issues/1) (unblocked, not yet started)
  - [#2 — setup-ios-cicd skill scaffolds any app repo onto the pipeline](https://github.com/niemax/ios-factory/issues/2) (blocked by #1)

**Not done yet:**
- No `fastlane/Fastfile`, no `.github/workflows/ios-release.yml` — the actual pipeline doesn't exist as code yet
- No `setup-ios-cicd` skill
- Roompiece has no thin caller workflow pointing at this repo yet
- No real tag has been pushed through any of this — nothing has been proven end-to-end

## Key decisions already locked (see the map for full reasoning)

- Signing: App Store Connect API key + Xcode-managed automatic signing. No Fastlane `match`, no certs in git.
- Secrets vs config: `setup-ios-cicd` prints `gh secret set` commands for credentials (never handles the values itself); non-sensitive config (`bundle_id`/`scheme`/`team_id`) goes straight into the consuming repo's thin workflow file as `with:` inputs — no separate config file.
- Test gate: `fastlane scan` on the iPhone 17 simulator, hard-blocking.
- Version/build number: overridden at build time via `gym xcargs` (`MARKETING_VERSION` from the tag) and `github.run_number` (build number) — no repo edits, no commits back.
- Trigger/endpoint: `vX.Y.Z` tag push triggers the pipeline; it stops at TestFlight. App Review submission is always a manual step.
- Reuse mechanism: the Fastlane release lane lives only in this repo, parameterized — no per-app `Fastfile`.
