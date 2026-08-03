# ios-factory

A shared, **public** repo for reusable iOS release tooling. Roompiece is the first consumer; more apps are expected to onboard onto the same pipeline over time. This README is a living status doc — kept current as tickets close, so an agent picking this repo up cold (or the human) doesn't have to reconstruct history from the issue tracker.

**Visibility note:** started private, switched to public during Ticket 1's real acceptance run — GitHub only allows a private repo's reusable workflows to be called from repos under the *same* owner/org, and `roompiece/roompiece` is a different owner than `niemax`. No secrets or business logic live here (those stay in each consuming app repo), so the exposure from going public is low; it also better serves reuse across apps that may live under yet other owners in the future.

## What this repo is for right now

CI/CD + App Store submission only: a reusable GitHub Actions workflow + Fastlane release lane that any app repo can call to go from a pushed version tag to a TestFlight build, plus `setup-ios-cicd` — a Claude Code skill that wires a new app repo onto it.

The wider "app factory" vision (design system generator, screen generators, ASO screenshot reuse, Firebase/PostHog scaffolding for new apps) is out of scope here — future work, tracked separately once this slice ships. See the spec's Further Notes for the full picture.

## Where the decisions came from

- **Spec:** [Reusable iOS CI/CD + App Store submission](https://github.com/roompiece/roompiece/issues/94) (lives on `roompiece/roompiece`'s tracker — that's where this effort was scoped and speced from)
- **Full decision trail:** [Wayfinder map #87](https://github.com/roompiece/roompiece/issues/87) and its six resolved tickets (#88–#93) — signing strategy, secrets/config split, test gate, version derivation, and the scaffolding-skill design

## Current status

**Done:**
- Repo created, public (see Visibility note above), `main` default branch
- `AGENTS.md` + `docs/agents/{issue-tracker,triage-labels,domain}.md` scaffolded — GitHub tracker (this repo), default triage labels, single-context domain docs
- **[#1 — Parameterized release pipeline](https://github.com/niemax/ios-factory/issues/1) — closed, mechanically proven.** Real `v0.0.1-test` tag pushes against `roompiece/roompiece` surfaced and fixed 5 real bugs: cross-owner private-repo workflow access (→ made this repo public), `secrets: inherit` unreliable cross-repo (→ explicit secret passing), a `Gemfile.lock` locked to an ancient local toolchain (→ dropped from version control), a `project_dir` path-depth bug (→ fixed, then hardened via `File.expand_path`), and `xcodegen` missing on the runner (→ install step added). Proven through a real 205-test XCTest run on the iPhone 17 simulator, correctly hard-blocking on one genuine (pre-existing, unrelated) failing test. `gym`/`pilot` on a clean run weren't directly observed — accepted as sufficient since the test-gate plumbing (the part that actually had bugs) is now proven.
- `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_CONTENT` **are set** on `roompiece/roompiece` (set by the human directly, never handled by an agent)
- Amendment (v2) decided and speced: merge-to-`production` replaces the manual tag, version/changelog inferred from Conventional Commits, App Review submission becomes a default-off toggle. Two new tickets:
  - [#3 — Commit message enforcement (Conventional Commits CI check)](https://github.com/niemax/ios-factory/issues/3) — unblocked
  - [#4 — Merge-triggered release, inferred version, generated changelog, auto-submit toggle](https://github.com/niemax/ios-factory/issues/4) — blocked by #1 (now satisfied) and #3
- `fastlane/Fastfile` — the `release` lane: XcodeGen detection, `scan` on iPhone 17 (hard gate), API-key automatic signing via `gym`, tag/run-number version injection, `pilot` upload to TestFlight. Parameterized (`project_dir`/`scheme`/`bundle_id`/`team_id`/`marketing_version`/`build_number`) — no app-specific values in this repo.
- `Gemfile` — `fastlane` pinned to `~> 2.226`, no committed lockfile (see #1's resolution above for why).
- `.github/workflows/ios-release.yml` — the reusable `workflow_call` workflow, proven end-to-end through the test gate.
- `roompiece/roompiece`'s thin caller (`.github/workflows/release.yml`) — currently tag-triggered; will be updated to merge-triggered by #4.

**Not done yet:**
- `setup-ios-cicd` skill (#2, now unblocked)
- Commit message enforcement (#3)
- Merge-triggered release + inferred version/changelog + auto-submit toggle (#4)
- A fully clean run through `gym`/`pilot` (deferred, see #1's resolution)

## Reusable workflow contract (`ios-release.yml`)

**Inputs** (`with:` in the caller):
- `project_dir` — directory containing `project.yml` / the `.xcodeproj`, relative to the calling repo's root (`"."` if at the root)
- `scheme` — Xcode scheme to test and build
- `bundle_id` — app's bundle identifier
- `team_id` — Apple Developer Team ID

**Secrets** (pass explicitly in the caller — `secrets: inherit` is unreliable across repository boundaries, confirmed by a real failed run: `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_CONTENT` existed on the caller repo but weren't seen by the called workflow):
```yaml
secrets:
  ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
  ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
  ASC_KEY_CONTENT: ${{ secrets.ASC_KEY_CONTENT }}
```
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` — App Store Connect API key (Key ID, Issuer ID, raw `.p8` contents). Same key used for signing (`-allowProvisioningUpdates`) and the TestFlight upload.

## Setting secrets on a consuming app repo

Never paste key material into an agent session. Run these yourself:

```
gh secret set ASC_KEY_ID --repo <owner>/<repo> --body "<key id>"
gh secret set ASC_ISSUER_ID --repo <owner>/<repo> --body "<issuer id>"
gh secret set ASC_KEY_CONTENT --repo <owner>/<repo> < ~/path/to/AuthKey_XXXXXX.p8
```

## Key decisions already locked (see the map for full reasoning)

- Signing: App Store Connect API key + Xcode-managed automatic signing. No Fastlane `match`, no certs in git.
- Secrets vs config: `setup-ios-cicd` prints `gh secret set` commands for credentials (never handles the values itself); non-sensitive config (`bundle_id`/`scheme`/`team_id`) goes straight into the consuming repo's thin workflow file as `with:` inputs — no separate config file.
- Test gate: `fastlane scan` on the iPhone 17 simulator, hard-blocking.
- Version/build number: overridden at build time via `gym xcargs` (`MARKETING_VERSION` from the tag) and `github.run_number` (build number) — no repo edits, no commits back.
- Trigger/endpoint: ~~`vX.Y.Z` tag push triggers the pipeline; it stops at TestFlight. App Review submission is always a manual step.~~ **Superseded (Amendment v2, spec #94):** merge-to-`production` triggers the pipeline (no tag); App Review submission is a default-off `auto_submit_review` toggle, not hardcoded-always-manual. See #4.
- Reuse mechanism: the Fastlane release lane lives only in this repo, parameterized — no per-app `Fastfile`.
