---
name: setup-ios-cicd
description: Onboards an iOS app repo onto niemax/ios-factory. Writes the shared PR checks caller (commit-lint + swift-lint) and a project-tailored AGENTS.md from a generic template, filling in architecture, the load-bearing decision and invariants by exploring the repo. Use when setting up a new or existing iOS app repo, adding ios-factory's PR checks, or creating/refreshing an iOS project's AGENTS.md.
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

## 4. Done: tell the user

- Run `xcrun agent skills export --output-dir ~/.claude/skills` (Apple's Xcode skills; re-run after Xcode updates).
- Both checks are advisory unless the repo's plan allows branch protection (public repo or GitHub Pro/Team). If it does, require `commit-lint / Conventional Commits` and `swift-lint / Apple SwiftUI guidance`.
- Builds go through Xcode Cloud (set up in App Store Connect). The skill doesn't configure it.
