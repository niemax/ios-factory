---
name: setup
description: First-run setup for the ios-factory plugin on this machine. Installs fastlane and xcodegen if missing, checks the Firebase, PostHog and RevenueCat MCPs, exports Apple's Xcode agent skills, checks the App Store Connect key settings and verifies they work. Use right after installing the plugin, on a new computer, or when an ios-factory skill says setup is incomplete.
---

# ios-factory setup

One-time, per machine. Each step checks first and only acts if something's missing. Report one line per step.

## 1. fastlane, xcodegen

`command -v fastlane xcodegen`. Ask, then `brew install` whichever is missing. (No Homebrew? Point the user to https://brew.sh and stop.)

## 2. Apple's Xcode agent skills

`xcrun agent skills export --output-dir ~/.claude/skills` (needs Xcode 27+). Re-running refreshes them; mention re-running it after Xcode updates.

## 3. App Store Connect key

Plugin settings hold the App Store Connect key (three values):
- Key ID: `${user_config.asc_key_id}`
- Issuer ID: `${user_config.asc_issuer_id}`
- Key file path: `${user_config.asc_key_path}`

- **Any empty:** tell the user to run `/plugin`, open **ios-factory → Configure**, and fill them in. Keys are under App Store Connect → Users and Access → Integrations → Team Keys, with the App Manager role or higher; the `.p8` can only be downloaded once, so create a new key if it's lost. Then `/reload-plugins` and re-run this skill.
- **Key file:** check the path exists (`test -f`) without reading it. Never open, print or copy the `.p8`. If it lives somewhere fragile like `~/Downloads`, offer to move it to `~/.appstoreconnect/private_keys/AuthKey_<KeyID>.p8` (`mkdir -p`, `mv`, `chmod 600`), then have the user update the path in the plugin settings.

## 3b. New-app defaults

- Team ID: `${user_config.team_id}`
- Bundle ID prefix: `${user_config.bundle_id_prefix}`
- Projects folder: `${user_config.projects_dir}`

If any is empty, propose a value, then have the user save it under `/plugin` → ios-factory → Configure:
- Team ID: the most common `DEVELOPMENT_TEAM` in existing `project.yml` and `project.pbxproj` files.
- Bundle ID prefix: the shared prefix of their bundle IDs.
- Projects folder: the parent folder of their repos.

## 4. Verify

```bash
(cd "${CLAUDE_PLUGIN_ROOT}" && ASC_KEY_ID="${user_config.asc_key_id}" ASC_ISSUER_ID="${user_config.asc_issuer_id}" \
  ASC_KEY_PATH="${user_config.asc_key_path}" FASTLANE_SKIP_DOCS=1 SKIP_SLOW_FASTLANE_WARNING=1 fastlane ios apps)
```

Lists the team's apps. A 401 means the Key ID, Issuer ID and key file don't belong together.

## 5. Firebase, PostHog and RevenueCat MCPs (used by `new-ios-app` and `setup-subscriptions`)

- `mcp__plugin_firebase_firebase__*` tools missing: the user runs `/plugin marketplace add firebase/firebase-tools`, then `/plugin install firebase@firebase`.
- `mcp__plugin_posthog_posthog__exec` missing: the user runs `/plugin install posthog@claude-plugins-official`.
- RevenueCat tools (`list-projects`…) missing: the user runs `/plugin marketplace add RevenueCat/ai-toolkit`, then `/plugin install revenuecat@RevenueCat` (not `revenuecat-play-billing`, which is Android only). OAuth on first use.
- Then `/reload-plugins`, or restart Claude Code if the tools still don't show. Firebase login: `firebase_get_environment`, then `firebase_login` if no user. PostHog asks for OAuth on first use.

## 6. Done: tell the user what's next

- `/ios-factory:new-ios-app` scaffolds a new app.
- `/ios-factory:setup-ios-cicd` in an app repo onboards it (PR checks, App Store Connect, `AGENTS.md`).
- `/ios-factory:release-ios` ships an App Store release.
- For hands-off releases, each app repo also needs the key as GitHub secrets. `release-ios` checks this and prints the commands.
