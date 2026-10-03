# ios-factory

A shared, **public** repo for reusable iOS release tooling. Roompiece is the first consumer; more apps are expected to onboard onto the same tooling over time. This README is a living status doc — kept current as tickets close, so an agent picking this repo up cold (or the human) doesn't have to reconstruct history from the issue tracker.

**Visibility note:** started private, switched to public during Ticket 1's real acceptance run — GitHub only allows a private repo's reusable workflows to be called from repos under the *same* owner/org, and `roompiece/roompiece` is a different owner than `niemax`. No secrets or business logic live here (those stay in each consuming app repo), so the exposure from going public is low; it also better serves reuse across apps that may live under yet other owners in the future.

## What this repo is for right now

**Xcode Cloud owns the binary** — build, sign, test, TestFlight upload — inside the Apple Developer Program's free 25 compute hours/month. **ios-factory owns only what Xcode Cloud can't do**, all on `ubuntu-latest` (no paid macOS minutes, ever — see [#15](https://github.com/niemax/ios-factory/issues/15)):

- Conventional Commits enforcement on PRs (#3)
- Version + changelog inferred from commits/PRs, written to TestFlight via the App Store Connect API (#4, being re-scoped under #15)
- Public App Store metadata: release notes, localizations, screenshots via the App Store Connect API (wayfinder map #5)

The wider "app factory" vision (design system generator, screen generators, Firebase/PostHog scaffolding for new apps) is out of scope here — future work.

## Where the decisions came from

- **Spec:** [Reusable iOS CI/CD + App Store submission](https://github.com/roompiece/roompiece/issues/94) (on `roompiece/roompiece`'s tracker)
- **Original decision trail:** [Wayfinder map #87](https://github.com/roompiece/roompiece/issues/87) and its tickets (#88–#93)
- **Pivot to Xcode Cloud for the binary:** [#15](https://github.com/niemax/ios-factory/issues/15)

## Current status

**Done:**
- `AGENTS.md` + `docs/agents/{issue-tracker,triage-labels,domain}.md` scaffolded
- [#1 — Parameterized Fastlane release pipeline](https://github.com/niemax/ios-factory/issues/1) — proven through the test gate, then **deleted** per #15: a GitHub-hosted macOS runner costs ~$1.30–1.60 per release, and duplicating Xcode Cloud's upload would have clashed on build numbers. Recoverable from git history (last present at `98af124`).
- [#6](https://github.com/niemax/ios-factory/issues/6) — existing ASC API key has App Manager role, sufficient for metadata/screenshot work
- `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_CONTENT` are set on `roompiece/roompiece` (by the human, never handled by an agent)

- [#3 — Commit lint](https://github.com/niemax/ios-factory/issues/3): reusable workflow + check script, wired into `roompiece/roompiece` via `pr-checks.yml` (roompiece#129). **Advisory, not required:** branch protection/rulesets need GitHub Pro/Team on a private repo, and the org is on Free. Don't merge red PRs.

**Not done yet:**
- #15 open questions: how ios-factory learns Xcode Cloud's build finished processing (poll ASC API vs. webhook → `repository_dispatch`)
- #4 (re-scope under #15), #2 (`setup-ios-cicd`, re-scope under #15), wayfinder #5 and its grilling tickets (#7–#14)
- `roompiece/roompiece` branch `ios-cicd-release-workflow` (old tag-triggered Fastlane caller, never merged) can be deleted

## Commit lint (`commit-lint.yml`)

Validates every non-merge commit in a PR against Conventional Commits: `<type>[(scope)][!]: <description>`, types `feat fix perf refactor docs style test build ci chore revert`. Git's default `Revert "..."` subject is also allowed. Merge commits are skipped.

Caller in the app repo (e.g. `.github/workflows/pr-checks.yml`):

```yaml
name: PR checks
on:
  pull_request:
jobs:
  commit-lint:
    uses: niemax/ios-factory/.github/workflows/commit-lint.yml@main
```

If the app repo's plan allows it (public repo, or Pro/Team), require the `commit-lint / Conventional Commits` status check in branch protection for its merge target. Otherwise it's advisory.

Check script self-test: `scripts/test-check-commits.sh`.

## Swift lint (`swift-lint.yml`)

Flags discouraged Swift/SwiftUI APIs on **lines a PR adds**, so legacy code is only flagged once touched. Rules come from Apple's Xcode 27 agent skills (`swiftui-specialist`: soft-deprecated APIs, `ObservableObject` → `@Observable`, `AnyView`, index-based `ForEach` identity), plus the shared concurrency rule (no `MainActor.run` / `DispatchQueue.main`). Soft-deprecated APIs compile without warnings, so nothing else catches them. Findings show as inline PR annotations. For a deliberate exception, put `// swift-lint:allow` on the line.

```yaml
  swift-lint:
    uses: niemax/ios-factory/.github/workflows/swift-lint.yml@main
```

The rule list lives in `scripts/check-swift.sh`. Refresh it from `xcrun agent skills export --output-dir <dir>` → `swiftui-specialist/references/soft-deprecated-apis.md` after each Xcode release. Self-test: `scripts/test-check-swift.sh`.

## `setup-ios-cicd` skill

`skills/setup-ios-cicd/` onboards an app repo: it writes `pr-checks.yml` (commit-lint + swift-lint) and a project-tailored `AGENTS.md` from `AGENTS.template.md`. The template holds only the generic basics (conventions, Apple guidance, concurrency, commits, release). The skill fills in architecture, the load-bearing decision and invariants by exploring the app repo and confirming with you, so domain knowledge never lands in this public repo.

Install once:

```bash
ln -s ~/Desktop/Code/ios-factory/skills/setup-ios-cicd ~/.claude/skills/setup-ios-cicd
```

## Setting secrets on a consuming app repo

Needed for the App Store Connect API work (#4/#5). Never paste key material into an agent session. Run these yourself:

```
gh secret set ASC_KEY_ID --repo <owner>/<repo> --body "<key id>"
gh secret set ASC_ISSUER_ID --repo <owner>/<repo> --body "<issuer id>"
gh secret set ASC_KEY_CONTENT --repo <owner>/<repo> < ~/path/to/AuthKey_XXXXXX.p8
```

## Key decisions already locked

- **No paid CI minutes.** Binary path = Xcode Cloud (free tier). ios-factory workflows run on Linux only (#15).
- Secrets vs config: credentials via `gh secret set` run by the human; non-sensitive config inline as `with:` inputs in the consuming repo's thin workflow file — no separate config file.
- Merge-to-`production` is the release moment; version/changelog inferred from Conventional Commits; App Review submission is a default-off toggle (spec #94 Amendment v2, #4).
- Reuse mechanism: logic lives only in this repo as reusable workflows + scripts; consuming repos hold thin callers.
