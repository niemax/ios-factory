---
name: setup
description: First-run setup for the ios-factory plugin on this machine. Installs fastlane if missing, exports Apple's Xcode agent skills, checks the App Store Connect key settings and verifies they work. Use right after installing the plugin, on a new computer, or when an ios-factory skill says setup is incomplete.
---

# ios-factory setup

One-time, per machine. Each step checks first and only acts if something's missing. Report one line per step.

## 1. fastlane

`command -v fastlane`. If it's missing, ask, then run `brew install fastlane`. (No Homebrew? Point the user to https://brew.sh and stop.)

## 2. Apple's Xcode agent skills

`xcrun agent skills export --output-dir ~/.claude/skills` (needs Xcode 27+). Re-running refreshes them; mention re-running it after Xcode updates.

## 3. App Store Connect key

Plugin settings hold three values:
- Key ID: `${user_config.asc_key_id}`
- Issuer ID: `${user_config.asc_issuer_id}`
- Key file path: `${user_config.asc_key_path}`

- **Any empty:** tell the user to run `/plugin`, open **ios-factory → Configure**, and fill them in. Keys are under App Store Connect → Users and Access → Integrations → Team Keys, with the App Manager role or higher; the `.p8` can only be downloaded once, so create a new key if it's lost. Then `/reload-plugins` and re-run this skill.
- **Key file:** check the path exists (`test -f`) without reading it. Never open, print or copy the `.p8`. If it lives somewhere fragile like `~/Downloads`, offer to move it to `~/.appstoreconnect/private_keys/AuthKey_<KeyID>.p8` (`mkdir -p`, `mv`, `chmod 600`), then have the user update the path in the plugin settings.

## 4. Verify

```bash
(cd "${CLAUDE_PLUGIN_ROOT}" && ASC_KEY_ID="${user_config.asc_key_id}" ASC_ISSUER_ID="${user_config.asc_issuer_id}" \
  ASC_KEY_PATH="${user_config.asc_key_path}" FASTLANE_SKIP_DOCS=1 SKIP_SLOW_FASTLANE_WARNING=1 fastlane ios apps)
```

Lists the team's apps. A 401 means the Key ID, Issuer ID and key file don't belong together.

## 5. Done: tell the user what's next

- `/ios-factory:setup-ios-cicd` in an app repo onboards it (PR checks, App Store Connect, `AGENTS.md`).
- `/ios-factory:release-ios` ships an App Store release.
- For hands-off releases, each app repo also needs the key as GitHub secrets. `release-ios` checks this and prints the commands.
