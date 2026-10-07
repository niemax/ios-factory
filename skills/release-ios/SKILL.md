---
name: release-ios
description: Interactive App Store release guide for an iOS app on niemax/ios-factory. Walks the user through version bump, What's New changelog, translations into every App Store language and screenshots, one step at a time. Then commits the staged release and opens the main → production PR; a merge to production ships it automatically. Use when the user wants to release, publish, ship or submit an iOS app update, or prepare a production release.
---

# release-ios

Interactive: one step at a time. Ask, show a draft, let the user edit, move on. Run from the app repo. Ships nothing itself: it **stages** a release. Merging the PR to `production` ships it via ios-factory's `release.yml` (it waits for Xcode Cloud's build, uploads, and submits).

**Running lanes.** Every `fastlane ios <lane> …` below means:
```bash
(cd "${CLAUDE_PLUGIN_ROOT}" && ASC_KEY_ID="${user_config.asc_key_id}" ASC_ISSUER_ID="${user_config.asc_issuer_id}" \
  ASC_KEY_PATH="${user_config.asc_key_path}" FASTLANE_SKIP_DOCS=1 SKIP_SLOW_FASTLANE_WARNING=1 fastlane ios <lane> …)
```
If any of those values is empty, or `fastlane` is missing, stop and have the user run `/ios-factory:setup` first. Never open, print or copy the `.p8` key file.

## 0. Preflight (silent unless something's wrong)

- `git fetch`. `main` must be clean and up to date, since the release commit goes on `main`. If not, stop and say why.
- Bundle ID and current `MARKETING_VERSION` from `project.yml` (or the `.xcodeproj`).
- `git log origin/production..origin/main --no-merges --format='%H%n%s%n%b%n--'` gives exactly what this release ships. If it's empty, there's nothing to release; stop.
- `fastlane ios locales bundle_id:<id>` gives the listing's languages and the latest version's state.
- **Pick the mode.** Compare that latest App Store version with `git show origin/production:fastlane/release.json`:
  - Same version, and it's **not live** (`PREPARE_FOR_SUBMISSION`, `DEVELOPER_REJECTED`, `REJECTED`, `METADATA_REJECTED`, `INVALID_BINARY`): **resubmit mode**. The release was staged and shipped once, then pulled or rejected. Go to [Resubmit](#resubmit) instead of steps 1–5.
  - Same version, still `WAITING_FOR_REVIEW` or `IN_REVIEW`: stop. The user removes it from review in App Store Connect first (App Store tab → the version → Remove from Review), then re-runs this.
  - Otherwise (the latest version is live, or this is the first release): a **new release**, steps 1–7.
- An open `main` → `production` PR (`gh pr list --base production --head main`) means a release is staged but not merged. Offer to update it (re-run only the steps the user wants to change) instead of staging a second one.
- One-time wiring: if `.github/workflows/release.yml` is missing in the app repo, it gets added in step 6 (caller below). Check `gh secret list` for `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`. If any is missing, give the user the `gh secret set` commands (`ASC_KEY_CONTENT` via `< path/to/key.p8`) to run themselves.

## 1. Version

Propose the bump from the commits: any `!` / `BREAKING CHANGE:` → major, any `feat` → minor, else patch. Show the commit list grouped by type, then the proposal. The user confirms or picks another.

## 2. What's New (en-US)

Draft from `feat:` / `fix:` subjects only (skip chore/docs/ci/refactor/test/build/style). A commit's `Release-note: <text>` trailer replaces its line. Write for users: plain, benefit-first, no internal jargon or ticket numbers, max ~4000 chars. Show it and iterate until the user approves.

## 3. Translations

Translate the approved notes into every listing locale from preflight. Match each market's tone; keep product and glossary names (`CONTEXT.md`) untranslated where the app does. Show them all in one table (locale | text). The user approves or names the ones to change.

## 4. Screenshots

Ask: **keep the current ones** (default) or **replace**. To replace, the user points at the new images, or runs the screenshot skill first. Stage them under `fastlane/screenshots/<locale>/` using App Store locale codes (`en-US`, not `en_US`). Name a check you can't do (e.g. pixel sizes) rather than skipping it silently.

## 5. Submit for review?

"Submit for App Review automatically once the build is ready?" **Default: yes.** No means it's staged in App Store Connect for a manual submit.

## 6. Stage + PR

Show the full diff first, and commit only after the user agrees.
1. Bump `MARKETING_VERSION` in `project.yml`. If it's XcodeGen, run `xcodegen generate` and include the `.xcodeproj` change.
2. `fastlane/release.json`: `{"bundle_id": "<id>", "version": "<x.y.z>", "submit_for_review": true|false, "attempt": 1}`.
3. `fastlane/metadata/<locale>/release_notes.txt` for every locale (overwrite the previous release's).
4. If missing, `.github/workflows/release.yml`:
   ```yaml
   name: App Store release
   on:
     push:
       branches: [production]
       paths: [fastlane/release.json]
   jobs:
     release:
       uses: niemax/ios-factory/.github/workflows/release.yml@main
       secrets:
         ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
         ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
         ASC_KEY_CONTENT: ${{ secrets.ASC_KEY_CONTENT }}
   ```
5. Commit on `main` as `chore(release): <x.y.z>`, push, then `gh pr create --base production --head main` titled `Release <x.y.z>` with the en-US notes and the shipped commit list in the body.

## Resubmit

Same version, new build. Keep everything already approved; redo only what changed.
1. **What changed:** show `origin/production..origin/main` (the fixes since the pulled attempt), grouped by type.
2. **Version:** unchanged. Never bump it: App Store Connect already holds this version.
3. **What's New:** show the current `fastlane/metadata/en-US/release_notes.txt`. Default: **keep it**. If the new commits add something user-facing, the user can edit it; then retranslate only if en-US changed (step 3 rules).
4. **Screenshots:** keep, unless the user names ones to replace.
5. **Submit for review?** Default yes, as in step 5.
6. **Stage:** increment `attempt` in `fastlane/release.json` (a missing `attempt` counts as 1; it's what triggers `release.yml` on `production`, since nothing else in that file changed), plus any edited notes. Show the diff, commit on `main` as `chore(release): resubmit <x.y.z>`, push, and open the PR titled `Release <x.y.z> (resubmit)` with the new commits in the body.

The release lane only ships a build uploaded after the merge commit, so the pulled attempt's build can't be picked up by mistake. It waits for Xcode Cloud's new one.

## 7. Done: tell the user

- Merging the PR → Xcode Cloud builds → `release.yml` waits for processing (up to 90 min), uploads, and submits (if chosen). Watch it under the app repo's Actions tab.
- Optional dry run first: `fastlane ios release app_dir:<absolute app repo path> dry_run:true` checks the staged files and whether the build exists.
