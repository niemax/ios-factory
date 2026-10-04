# ios-factory

Reusable tooling that takes an iOS app from repo setup to App Store release with as few clicks as possible. Claude Code skills drive the work interactively; shared GitHub workflows and Fastlane lanes do the repeatable parts.

Consumers: [Roompiece](https://github.com/roompiece/roompiece), [Card Scanner](https://github.com/pokecardscanner/card-scanner).

## What it delivers

```
 /setup-ios-cicd          every PR               merge to main             /release-ios → merge to production
 ───────────────          ────────               ─────────────             ──────────────────────────────────
 AGENTS.md                commit-lint            Xcode Cloud archives      version · What's New · translations
 PR checks                swift-lint             → internal TestFlight     · screenshots, staged in a PR
 App Store Connect app    (Linux, free)          (internal group gets      → Xcode Cloud builds → release.yml
 TestFlight group                                 every build)             uploads + submits for review
```

- **Onboarding in one command.** Wire any app repo (new or existing) onto the shared checks and App Store Connect setup.
- **Every PR checked.** Conventional Commits, plus Apple's SwiftUI guidance on the lines you add.
- **Internal builds on every merge to `main`.** Xcode Cloud uploads, and the internal TestFlight group gets each build automatically.
- **App Store releases on merge to `production`.** You go through the release interactively in the CLI. The upload and submission after the merge is hands-off.
- **€0 per release within the free tiers.** Builds use Xcode Cloud's 25 included compute hours a month (roughly 20–30 min per build). Checks and the release upload run on GitHub Linux runners: free for public repos, and on private repos they count against GitHub's 2,000 free minutes a month (then ~$0.006/min). The upload job mostly waits for Xcode Cloud, 30–90 min per release. No paid macOS runners. The old Fastlane build on those cost about $1.30–1.60 per release.

## Skills

| Skill | What it does | Use when | Status |
|---|---|---|---|
| [`setup-ios-cicd`](skills/setup-ios-cicd/SKILL.md) | Explores the app repo, then writes a project-tailored `AGENTS.md` (from a generic template; domain knowledge stays in the app repo) and `pr-checks.yml`. Sets up App Store Connect: bundle ID, app record, internal TestFlight group, testers. Guides the two Xcode Cloud workflows. | Onboarding a new or existing iOS app, or refreshing its `AGENTS.md` | ✅ Verified on two existing apps; new-app path not yet run |
| [`release-ios`](skills/release-ios/SKILL.md) | Interactive release guide, one step at a time: version bump from commits → What's New → translations into every App Store language → screenshots → submit for review (default yes). Commits the staged release and opens the `main` → `production` PR. | Shipping an update to the App Store | 🟡 Built; first real release pending |
| `new-ios-app` | Scaffolds a new app: project, folder structure, navigation, PostHog, backend (Firebase/Supabase), then calls `setup-ios-cicd`. | Starting a new app | ⏳ Planned |
| `setup-subscriptions` | Creates App Store subscriptions and prices, and wires them to RevenueCat (via its MCP). | Adding or changing paid plans | ⏳ Planned |

Install a skill once (symlink, so `git pull` updates it):

```bash
ln -s ~/Desktop/Code/ios-factory/skills/<skill> ~/.claude/skills/<skill>
```

## Shared workflows

Called from a consuming repo's thin workflow files (the skills write them). All run on `ubuntu-latest`.

| Workflow | Trigger in the app repo | What it does |
|---|---|---|
| [`commit-lint.yml`](.github/workflows/commit-lint.yml) | every PR | Checks every non-merge commit against Conventional Commits (`type(scope)!: description`). Version bumps and release notes depend on it. |
| [`swift-lint.yml`](.github/workflows/swift-lint.yml) | every PR | Flags soft-deprecated SwiftUI APIs, `ObservableObject`, `AnyView`, index-based `ForEach` identity, `MainActor.run` and `DispatchQueue.main`, **only on lines the PR adds**, as inline annotations. Rules come from Apple's Xcode agent skills. Escape hatch: `// swift-lint:allow`. |
| [`release.yml`](.github/workflows/release.yml) | push to `production` touching `fastlane/release.json` | Waits for Xcode Cloud's build of the staged version, then uploads release notes (+ screenshots), attaches the build and submits for review if staged so. |

Checks are advisory unless the app repo's plan allows branch protection (a public repo, or GitHub Pro/Team). Never merge while one is red.

## Fastlane lanes

For App Store Connect work only. **Fastlane never builds:** that's Xcode Cloud's job. Run from this repo's root.

| Lane | What it does |
|---|---|
| `fastlane ios setup bundle_id:… name:… [group:…] [testers:…] [dry_run:true]` | Idempotent app setup: bundle ID + app record via `produce` (Apple ID + 2FA, only for a new app), an internal TestFlight group with access to all builds (an existing one is reused), testers. |
| `fastlane ios release app_dir:… [dry_run:true]` | Ships what `release-ios` staged (CI runs this via `release.yml`). |
| `fastlane ios locales bundle_id:…` | The App Store listing's languages and the latest version's review state. |

## Getting started

1. `brew install fastlane`
2. `cp fastlane/.env.example fastlane/.env` and fill in the App Store Connect Key ID, Issuer ID and the **path** to the `.p8` key. The file is gitignored, and the key itself never goes in it. Keys live in App Store Connect → Users and Access → Integrations → Team Keys (App Manager role is enough).
3. Symlink the skills (above). Then run `/setup-ios-cicd` from an app repo.
4. Export Apple's Xcode agent skills, which the generated `AGENTS.md` and `swift-lint` build on: `xcrun agent skills export --output-dir ~/.claude/skills`

For hands-off releases, each app repo needs the key as GitHub secrets. Run these yourself; never paste key material into an agent session:

```bash
gh secret set ASC_KEY_ID --repo <owner>/<repo> --body "<key id>"
gh secret set ASC_ISSUER_ID --repo <owner>/<repo> --body "<issuer id>"
gh secret set ASC_KEY_CONTENT --repo <owner>/<repo> < ~/path/to/AuthKey_XXXXXX.p8
```

## What stays manual (Apple offers no API)

- **Creating the app record** for a brand-new app. `produce` handles it, but it needs your Apple ID login with 2FA.
- **Connecting an app to Xcode Cloud** and creating its two workflows in Xcode. `setup-ios-cicd` guides you through it.
- **The App Privacy questionnaire**, agreements, tax and banking in App Store Connect.

## Principles

- **No paid CI minutes.** Builds go through Xcode Cloud; everything here runs on Linux or locally ([#15](https://github.com/niemax/ios-factory/issues/15)).
- **`main` = internal, `production` = public.** A merge to `main` produces an internal TestFlight build. Anything that submits to the App Store happens only on a merge to `production`.
- **Logic lives here; app repos hold thin callers.** Fix it once and every app gets it.
- **Public repo, no domain knowledge.** No secrets or product decisions live here. Templates hold only generic basics; each app's specifics go into that app's own repo.
- **Dry run before every write** to an Apple account. Every lane checks before it changes anything, so re-running is safe.

## Status and history

- Decision trail: spec [roompiece#94](https://github.com/roompiece/roompiece/issues/94), map [roompiece#87](https://github.com/roompiece/roompiece/issues/87), and the move to Xcode Cloud in [#15](https://github.com/niemax/ios-factory/issues/15).
- Open work: [#4](https://github.com/niemax/ios-factory/issues/4) (release automation, now `release-ios`), [#5](https://github.com/niemax/ios-factory/issues/5) and its design questions #7–#14 (metadata, screenshots, localization).
- Self-tests: `scripts/test-check-commits.sh`, `scripts/test-check-swift.sh`. Refresh `swift-lint`'s rules from Apple's `soft-deprecated-apis.md` after each Xcode release.
