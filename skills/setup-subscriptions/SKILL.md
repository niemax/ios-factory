---
name: setup-subscriptions
description: Adds auto-renewable subscriptions to an iOS app on niemax/ios-factory. Creates the RevenueCat project, app, products, entitlement and offering, pushes prices, availability and localizations into App Store Connect through RevenueCat store-state plans (diff reviewed before apply), and wires the RevenueCat SDK, keys and a SubscriptionManager into the app. Use when adding subscriptions, a paywall or in-app purchases to an iOS app, or setting up RevenueCat.
---

# setup-subscriptions

A thin layer over RevenueCat's own plugin: it supplies the factory defaults and the app wiring, and their skills do the rest. Run from the app repo. Ask one batch at a time. Nothing writes to RevenueCat or App Store Connect without a confirmed preview.

## 0. Tools and prerequisites

- **RevenueCat MCP:** are the tools available (`list-projects`, `create-product-store-state-plan`…)? If not, the user runs `/plugin marketplace add RevenueCat/ai-toolkit`, `/plugin install revenuecat@RevenueCat` and `/reload-plugins`. It signs in with OAuth on first use. Their skills `revenuecat:create-revenuecat-project` and `revenuecat:revenuecat-store-state` hold the call order and rules; load them before steps 3 and 4.
- Read from the repo:
  - bundle ID, app name and `project.yml`;
  - the App Store listing languages: `fastlane ios locales bundle_id:<id>`, run as described under "Running lanes" in `release-ios`;
  - whether the app has Firebase Auth.
- **Manual, one-time per app, no API for either.** Check each one, then give the user the link:
  - **Paid Apps agreement** active in App Store Connect → Business.
  - **App Store Connect API key uploaded to RevenueCat:** app settings in the RevenueCat dashboard (the same `.p8` as the plugin's key works; the user uploads it, never the agent). Store-state writes fail without it. Check with `validate-app-credentials`.

## 1. Ask (one batch)

- **Plans:** which durations (weekly, monthly, annual…) and the USD price of each. **Prices start from the USA (USD)**; Apple's equalization fills in every other territory. Is there an introductory offer (free trial or discount) on any plan?
- **Entitlement:** default `pro`. Subscription group: default `<App Name> Pro`.
- **Product IDs:** default `<bundle_id>.<entitlement>.<duration>` (e.g. `com.niemax.cardscanner.pro.annual`). They're permanent: Apple never frees a product ID.
- **Paywall:** RevenueCat Paywalls (RevenueCatUI, changed remotely, A/B testable) or a custom SwiftUI view?

## 2. Show the plan, wait for a yes

Show one table: product ID, duration, USD price, trial, entitlement, package (`$rc_monthly`, `$rc_annual`…). Below it, the display name and description in en-US, then the translations into every listing language (as in `release-ios`). The user approves or edits.

## 3. RevenueCat catalog

Follow `revenuecat:create-revenuecat-project`:
- list projects, then reuse the app's or create one named after the app;
- an `app_store` app with the bundle ID;
- entitlement, the `default` offering, packages.

The products themselves come from the store-state plan in step 4 (`create_revenuecat_product`). Attach them to the entitlement and packages after it applies.

## 4. App Store Connect via store-state plan

Follow `revenuecat:revenuecat-store-state` exactly. In short:
1. `create-product-store-state-plan` with one desired state per product:
   - `store: app_store`;
   - the subscription group, duration and the US price in `territory_prices`;
   - `common.pricing.equalize_missing_subscription_prices` with `base_territory: USA`;
   - availability in all territories;
   - the localizations from step 2;
   - the trial, if any;
   - no screenshot (apply uploads a placeholder).
   - Check the tool schema for the subscription group field. If the plan can't create a group, say so and stop. Don't guess.
2. Plan, then poll until it's planned. Show the user the diff and every warning. Never apply with an item-level blocker.
3. Apply only after an explicit yes. Poll until it's applied, and report each product's status.
4. Attach the products to the entitlement and packages (step 3).
5. Ask about submitting for review (`submit-products-to-store`). Default: **no**. The first subscription has to be submitted together with an app version: Apple reviews them together. Tell the user that.

## 5. Paywall

- **RevenueCat Paywalls:** `create-paywall-ai` from the offering. Poll `get-paywall-ai-task`, then show `render-paywall-screenshot` and iterate. `attach-offering-to-paywall`. Publish only after a yes.
- **Custom:** build it as a feature (`Features/Paywall/`) following `AGENTS.md`, reading `SubscriptionManager.packages`.

## 6. App wiring

Read `AGENTS.md` first and follow it.
1. **`project.yml`:**
   - the package `RevenueCat` (`https://github.com/RevenueCat/purchases-ios-spm`, `from: 5.0.0`), product `RevenueCat`, plus `RevenueCatUI` for RevenueCat Paywalls;
   - keys from `list-app-public-api-keys`: in `configs:`, **Debug** gets the Test Store key (`test_…`) and **Release** the App Store key (`appl_…`), as `REVENUECAT_API_KEY`;
   - the Info.plist property `REVENUECAT_API_KEY: $(REVENUECAT_API_KEY)`;
   - then run `xcodegen generate`. The public keys are safe to commit (they ship in the app).
2. Copy [SubscriptionManager.swift](SubscriptionManager.swift) to `<App>/Services/`, with `__ENTITLEMENT__` replaced.
3. In `AppEntry`: hold `@State private var subscriptions = SubscriptionManager()`, call `subscriptions.configure()` in `init` or `.task`, and inject it with `.environment(subscriptions)`.
4. With Firebase Auth: after sign-in, call `subscriptions.logIn(userID: uid)`, so purchases follow the account.
5. RevenueCat Paywalls: on the paid entry points, use `.presentPaywallIfNeeded(requiredEntitlementIdentifier: SubscriptionManager.entitlementID)` from RevenueCatUI.
6. `AGENTS.md`: add an invariant: **paid features check `SubscriptionManager.isSubscribed`; nothing else talks to RevenueCat.**
7. Build and test (XcodeBuildMCP). Commit on a branch: `feat(subscriptions): add <entitlement> subscriptions`.

## 7. Done: tell the user

- **Test purchases:** Debug builds use RevenueCat's Test Store (no sandbox account needed). TestFlight builds use Apple's sandbox.
- **What's left:** the review screenshot (a placeholder for now) and submitting the subscriptions together with the next app version (`release-ios`).
- Prices and plans change through the same plan flow (`revenuecat:revenuecat-store-state`), never by hand in two places.
