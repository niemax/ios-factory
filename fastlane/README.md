fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios setup

```sh
[bundle exec] fastlane ios setup
```

Idempotent App Store Connect setup for one app. Safe to re-run.

  1. Bundle ID + app record: if the app doesn't exist, `produce` creates
     both. The App Store Connect API can't create apps, so that step logs
     in with your Apple ID (FASTLANE_USER, password + 2FA prompt) — run it
     yourself in a terminal. Skipped entirely when the app exists.
  2. Internal TestFlight group with access to all builds (reuses any
     existing internal all-builds group, whatever it's called).
  3. Testers, comma-separated (must already be users on the team).

Options: bundle_id:, name:, [sku:], [language:], [group:], [testers:], [dry_run:true]


----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
