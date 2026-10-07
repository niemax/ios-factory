# ios-factory

Reusable tooling that takes an iOS app from repo setup to App Store release with as few clicks as possible. Claude Code skills drive the work interactively; shared GitHub workflows and Fastlane lanes do the repeatable parts.

Consumers: [Roompiece](https://github.com/roompiece/roompiece), [Card Scanner](https://github.com/pokecardscanner/card-scanner).

## What it delivers

```
 /new-ios-app          /setup-ios-cicd        every PR           merge to main           /release-ios → merge to production
 ────────────          ───────────────        ────────           ─────────────           ──────────────────────────────────
 XcodeGen project      AGENTS.md              commit-lint        Xcode Cloud archives    version · What's New · translations
 Coordinator, folders  PR checks              swift-lint         → internal TestFlight   · screenshots, staged in a PR
 Firebase · PostHog    App Store Connect app  (Linux, free)      (internal group gets    → Xcode Cloud builds → release.yml
 GitHub repo  ───────→ TestFlight group                           every build)           uploads + submits for review
```

- **A new app in one command.** Project, navigation, folder structure, Firebase and PostHog provisioned through their MCPs, a private GitHub repo, then straight into onboarding.
- **Onboarding in one command.** Wire any app repo (new or existing) onto the shared checks and App Store Connect setup.
- **Every PR checked.** Conventional Commits, plus Apple's SwiftUI guidance on the lines you add.
- **Internal builds on every merge to `main`.** Xcode Cloud uploads, and the internal TestFlight group gets each build automatically.
- **App Store releases on merge to `production`.** You go through the release interactively in the CLI. The upload and submission after the merge is hands-off.
- **€0 per release within the free tiers.** Builds use Xcode Cloud's 25 included compute hours a month (roughly 20–30 min per build). Checks and the release upload run on GitHub Linux runners: free for public repos, and on private repos they count against GitHub's 2,000 free minutes a month (then ~$0.006/min). The upload job mostly waits for Xcode Cloud, 30–90 min per release. No paid macOS runners. The old Fastlane build on those cost about $1.30–1.60 per release.

## Skills

| Skill | What it does | Use when | Status |
|---|---|---|---|
| [`setup`](skills/setup/SKILL.md) | First-run machine setup: installs fastlane and xcodegen, checks the Firebase, PostHog and RevenueCat MCPs, exports Apple's Xcode agent skills, verifies the App Store Connect key from the plugin settings. | Right after installing the plugin, or on a new computer | ✅ |
| [`setup-ios-cicd`](skills/setup-ios-cicd/SKILL.md) | Explores the app repo, then writes a project-tailored `AGENTS.md` (from a generic template; domain knowledge stays in the app repo) and `pr-checks.yml`. Sets up App Store Connect: bundle ID, app record, internal TestFlight group, testers. Guides the two Xcode Cloud workflows. | Onboarding a new or existing iOS app, or refreshing its `AGENTS.md` | ✅ Verified on two existing apps and a fresh scaffold; creating a new App Store Connect app via `produce` not yet run |
| [`release-ios`](skills/release-ios/SKILL.md) | Interactive release guide, one step at a time: version bump from commits → What's New → translations into every App Store language → screenshots → submit for review (default yes). Commits the staged release and opens the `main` → `production` PR. | Shipping an update to the App Store | ✅ Shipped Roompiece 1.4.0 end to end |
| [`new-ios-app`](skills/new-ios-app/SKILL.md) | Scaffolds a new app from [a template](skills/new-ios-app/template): XcodeGen with buildable folders, iOS 26, Swift 6, a generic `Coordinator<Route>`, nested feature folders, SwiftLint, Swift Testing. Creates the Firebase project and app (plus Auth and Firestore with locked rules, both optional and on by default) and the PostHog project through their MCPs and wires both in. Creates the GitHub repo, then calls `setup-ios-cicd`. | Starting a new app | ✅ Verified end to end on a throwaway app (Firebase, PostHog, GitHub, PR checks green); App Store Connect stopped at the dry run |
| [`setup-subscriptions`](skills/setup-subscriptions/SKILL.md) | A thin layer over RevenueCat's plugin. Creates the RevenueCat project, products, entitlement and offering, pushes prices (from a USD base, equalized by Apple), availability and localizations into App Store Connect through a store-state plan you review before it's applied, sets up a RevenueCat or custom paywall, and wires the SDK, per-build keys and a `SubscriptionManager` into the app. | Adding or changing paid plans | 🟡 Built; `SubscriptionManager` compiles; not yet run against RevenueCat |

Skills install as one Claude Code plugin; see [Getting started](#getting-started). Invoke them as `/ios-factory:<skill>`.

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
| `fastlane ios apps` | The team's apps (name, bundle ID). Also checks that the API key works. |

## Getting started

ios-factory is a Claude Code plugin. On any machine:

1. In Claude Code, add the marketplace and install the plugin:
   ```
   /plugin marketplace add niemax/ios-factory
   /plugin install ios-factory@niemax
   ```
   Enabling it asks once for:
   - your App Store Connect **Key ID**, **Issuer ID** and the **path** to the `.p8` key file (only the path is stored, never the key);
   - your **Team ID**, **bundle ID prefix** and **projects folder**, so new apps never ask for them.

   Keys live in App Store Connect → Users and Access → Integrations → Team Keys (App Manager role is enough). Change them later under `/plugin` → ios-factory → Configure.
2. Run `/ios-factory:setup`. It installs fastlane if missing, exports Apple's Xcode agent skills, and checks the key works by listing your apps.
3. Done. Run `/ios-factory:setup-ios-cicd` in an app repo, and `/ios-factory:release-ios` to ship.

Updates arrive with `/plugin update ios-factory` (the plugin follows `main`).

Running lanes by hand, outside Claude: clone the repo, `brew install fastlane`, copy `fastlane/.env.example` to `fastlane/.env` and fill it in, then run `fastlane ios <lane>` from the repo root.

For hands-off releases, each app repo needs the key as GitHub secrets. Run these yourself; never paste key material into an agent session:

```bash
gh secret set ASC_KEY_ID --repo <owner>/<repo> --body "<key id>"
gh secret set ASC_ISSUER_ID --repo <owner>/<repo> --body "<issuer id>"
gh secret set ASC_KEY_CONTENT --repo <owner>/<repo> < ~/path/to/AuthKey_XXXXXX.p8
```

## What stays manual (no API for it)

- **Sign in with Apple** in Firebase Auth: one toggle in the Firebase console (the MCP can't enable it). `new-ios-app` gives you the link.
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
- Open work: map [#5](https://github.com/niemax/ios-factory/issues/5); first-submission prep #17; ASO via Astro #18; skill orchestration #19; screenshots #8, #10, #11, #12.
- Self-tests: `scripts/test-check-commits.sh`, `scripts/test-check-swift.sh`; for the template, scaffold into a temp dir and build and test it. Refresh `swift-lint`'s rules from Apple's `soft-deprecated-apis.md` after each Xcode release.
