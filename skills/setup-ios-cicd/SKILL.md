---
name: setup-ios-cicd
description: Onboards an iOS app repo onto niemax/ios-factory. Writes the shared PR checks caller (commit-lint + swift-lint), sets up App Store Connect (bundle ID, app record, internal TestFlight group, testers) and Xcode Cloud workflows (main → internal TestFlight, production → App Store) and writes a project-tailored AGENTS.md from a generic template, filling in architecture, the load-bearing decision and invariants by exploring the repo. Use when setting up a new or existing iOS app repo, adding ios-factory's PR checks, or creating/refreshing an iOS project's AGENTS.md.
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

## 5. Xcode Cloud workflows

`fastlane ios xcode_cloud` (same key env vars) makes sure there are two workflows:
- `main`: archive, then upload as an internal TestFlight build;
- `production`: archive, then upload as App Store eligible.

It leaves alone any branch that already has a workflow starting on it.

1. **Prerequisite, with no API for it:** the app must be connected to Xcode Cloud once in Xcode (Product → Xcode Cloud → Create Workflow, granting repo access). If the lane says it isn't connected, walk the user through that, then re-run.
2. Dry run, show the output, then run for real after the user agrees:
   ```bash
   fastlane ios xcode_cloud bundle_id:<id> scheme:<Scheme> container:<repo-relative .xcodeproj> dry_run:true
   ```
3. The workflow Xcode creates during that first connection usually starts on every branch. Mention it so the user can delete it in App Store Connect if it's not wanted.

## 6. Done: tell the user

- Run `xcrun agent skills export --output-dir ~/.claude/skills` (Apple's Xcode skills; re-run after Xcode updates).
- Both checks are advisory unless the repo's plan allows branch protection (public repo or GitHub Pro/Team). If it does, require `commit-lint / Conventional Commits` and `swift-lint / Apple SwiftUI guidance`.
