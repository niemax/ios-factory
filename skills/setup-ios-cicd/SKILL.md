---
name: setup-ios-cicd
description: Onboards an iOS app repo onto niemax/ios-factory. Writes the shared PR checks caller (commit-lint + swift-lint), sets up App Store Connect (bundle ID, app record, internal TestFlight group, testers) and writes a project-tailored AGENTS.md from a generic template, filling in architecture, the load-bearing decision and invariants by exploring the repo. Use when setting up a new or existing iOS app repo, adding ios-factory's PR checks, or creating/refreshing an iOS project's AGENTS.md.
---

# setup-ios-cicd

Explore → present → confirm → write. Run from the app repo's root.

**Hard rule:** domain knowledge (product decisions, invariants, glossary terms) goes into the app repo only. Never write it back into ios-factory or its template; ios-factory is public.

## 1. Explore (read-only)

- **Project:** `project.yml` (XcodeGen) or `*.xcodeproj`; scheme, bundle id, deployment target, devices/orientation, SPM packages. Is the generated `.xcodeproj` committed? (`git ls-files`)
- **Code shape:** top-level source folders; 2–3 feature folders to learn the folder convention the code *already* uses; heavy work (Vision, image processing, encoding) and where it runs; test targets.
- **Backend:** any `backend/`, `functions/`, server dir; its manifest's build/test scripts.
- **Domain sources:** `CONTEXT.md`, `docs/adr/`, PRDs/specs, `NEVER`/`always` comments, limits/config files.
- **Existing setup:** `AGENTS.md` / `CLAUDE.md` (keep their project-specific sections), `.github/workflows/` (an existing `pr-checks.yml` gets updated, not duplicated), `ci_scripts/`.

## 2. Present and confirm, one at a time

1. Detected facts (scheme, paths, target, stack): confirm or correct as a batch.
2. **The load-bearing decision:** propose one from ADRs/PRD (the differentiator or the cost model everything follows from). The user must confirm or rewrite it. Never guess silently.
3. **Invariants:** propose bullets grouped by area, each traced to an ADR, code comment or config file. Drop anything the user rejects. Don't invent rules the repo doesn't hold.
4. If an `AGENTS.md` exists: show what will be added, changed and kept.

## 3. Write

1. `AGENTS.md`: fill [AGENTS.template.md](AGENTS.template.md). Replace every `{{…}}`, follow and then delete every "tailor" comment, and remove sections that don't apply (e.g. Project generation without XcodeGen). Before writing, check that `grep -n '{{\|tailor' AGENTS.md` returns nothing.
2. `.github/workflows/pr-checks.yml`:

```yaml
name: PR checks

# Shared PR checks from niemax/ios-factory: Conventional Commits on every PR
# commit, and Apple SwiftUI guidance on added Swift lines.
on:
  pull_request:

jobs:
  commit-lint:
    uses: niemax/ios-factory/.github/workflows/commit-lint.yml@main

  swift-lint:
    uses: niemax/ios-factory/.github/workflows/swift-lint.yml@main
```

3. Show the full diff. Commit only after the user agrees, on a branch, with a Conventional Commit message (e.g. `docs: add AGENTS.md and shared PR checks`). Opening the PR is the user's call.

## 4. App Store Connect

Uses the `setup` lane in `<ios-factory>/fastlane/Fastfile` (this skill's folder is `<ios-factory>/skills/setup-ios-cicd`). Needs `fastlane` (`brew install fastlane`). Idempotent: re-running only fills gaps.

1. Ask for the App Store Connect key: Key ID, Issuer ID, and the **path** to the `.p8` file. Never open, print or copy the key file. Only pass the path in `ASC_KEY_PATH`.
2. Confirm the app name, the internal TestFlight group name (default `Internal Testers`) and tester emails. Testers must already be users on the team.
3. Dry run first, from the ios-factory root, and show the output:
   ```bash
   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=… fastlane ios setup \
     bundle_id:<id> name:"<App>" group:"Internal Testers" testers:a@b.com,c@d.com dry_run:true
   ```
4. After the user agrees, run it without `dry_run`.
   - **App already exists:** runs non-interactively with the API key, so run it yourself.
   - **New app:** `produce` creates the bundle ID and app record, which needs an Apple ID login with a password and 2FA prompt. Hand the user the exact command to run with `! FASTLANE_USER=<apple id> …`, then re-run the lane yourself to confirm.

## 5. Xcode Cloud workflows (manual, guide the user)

Apple's API can't connect an app and repo to Xcode Cloud, so the user does it in Xcode: Product → Xcode Cloud → Create Workflow, granting repo access. Walk them through two workflows:
- **TestFlight Internal**: start condition is branch changes on `main` (exact match, auto-cancel on). Action: Archive (iOS, scheme `<Scheme>`), distribution **TestFlight (Internal Testing Only)**.
- **Production**: start condition is branch changes on `production`. Action: Archive, distribution **TestFlight and App Store**.

The internal group from step 4 has access to all builds, so no post-action is needed for testers. Delete the default workflow Xcode creates if it starts on every branch.

## 6. Done: tell the user

- Run `xcrun agent skills export --output-dir ~/.claude/skills` (Apple's Xcode skills; re-run after Xcode updates).
- Both checks are advisory unless the repo's plan allows branch protection (public repo or GitHub Pro/Team). If it does, require `commit-lint / Conventional Commits` and `swift-lint / Apple SwiftUI guidance`.
