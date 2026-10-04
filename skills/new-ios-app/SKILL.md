---
name: new-ios-app
description: Scaffolds a new iOS app repo on niemax/ios-factory conventions. XcodeGen project with buildable folders, iOS 26, Swift 6, generic Coordinator navigation, nested feature folders, Firebase (optionally Auth and Firestore) and PostHog wired in and provisioned through their MCPs, then hands off to setup-ios-cicd. Use when starting a new iOS app, creating a new Xcode project, or bootstrapping an app repo from scratch.
---

# new-ios-app

Ask, scaffold, provision, hand off. One question batch at a time.

## 0. Tools

Each check is silent when it passes.
- `xcodegen` missing: ask, then `brew install xcodegen`.
- **Firebase MCP:** `mcp__plugin_firebase_firebase__*` tools available? If not, have the user run:
  ```
  /plugin marketplace add firebase/firebase-tools
  /plugin install firebase@firebase
  ```
- **PostHog MCP:** `mcp__plugin_posthog_posthog__exec` available? If not: `/plugin install posthog@claude-plugins-official`.
- After any install: `/reload-plugins`. If the tools still don't appear, the user restarts Claude Code and re-runs this skill. Then log in: `firebase_login` if `firebase_get_environment` shows no user; PostHog prompts its own OAuth on first use.
- **Settings:** team ID `${user_config.team_id}`, bundle prefix `${user_config.bundle_id_prefix}`, projects folder `${user_config.projects_dir}`, App Store Connect key ID `${user_config.asc_key_id}`. If any is empty, run `/ios-factory:setup` first.

## 1. Ask (one message)

Three questions:
- App name: UpperCamelCase, used for the module, target and scheme. Add a display name if it's different.
- One line of what the app is. It seeds `CONTEXT.md`.
- **Firebase Auth and Firestore?** Default: both. If Auth, which sign-in methods: Sign in with Apple (default), Google, email/password, anonymous. App Store rule 4.8: offering Google means Sign in with Apple is offered too.

Everything else is derived. Show it in one line, which the user can override:
- bundle ID `${user_config.bundle_id_prefix}.<lowercased name>`;
- folder `${user_config.projects_dir}/<kebab-name>`, which must not exist yet or must be empty;
- team `${user_config.team_id}`.

Never name the module after a framework type (`NotificationCenter`, `Color`, `App`…): it shadows it inside the module.

## 2. Scaffold

```bash
FIREBASE_AUTH=1|0 FIREBASE_FIRESTORE=1|0 \
  "${CLAUDE_PLUGIN_ROOT}/skills/new-ios-app/scaffold.sh" <dest> <AppName> <bundle.id> "${user_config.team_id}" "<Display Name>"
```
It copies [template/](template/), fills the placeholders, runs `xcodegen generate` and `git init`. Then write `CONTEXT.md`: the one-liner under `# <Display Name>`, plus an empty `## Glossary`.

What the template gives you (the same shape as truster's NotificationApp):
- `AppDelegate/AppEntry.swift`: composition root. Starts Firebase and analytics, then shows `HomeStack`.
- `Coordinator/`: one generic `Coordinator<Route>`, route enums in `Routes/`, stack views in `CoordinatorStacks/`.
- `Features/<Feature>/{Views,ViewModel,Components,Models,Utils}`, plus `Services/`, `UIComponents/`, `Constants/`, `Utils/Extensions/`, `Assets/`.
- `Services/FirebaseService.swift`: skipped while `GoogleService-Info.plist` is absent.
- `Services/Analytics.swift`: PostHog. Off in Debug and while there's no key.
- A Swift Testing target, and `.swiftlint.yml` (force unwraps, `try!` and `as!` are errors).

## 3. Provision (dry run first: show what will be created and wait for a yes)

**Firebase** (Firebase MCP):
1. `firebase_list_projects`. Reuse one or `firebase_create_project`. Project IDs are global: propose `<kebab-name>-<short random>`.
2. `firebase_create_app` (platform ios, the bundle ID). Reuse if it already exists (`firebase_list_apps`).
3. `firebase_get_sdk_config` for that app. Write it to `<AppName>/GoogleService-Info.plist`; the buildable folder bundles it with no project edit. Commit it: it identifies the project and isn't a secret, and Xcode Cloud needs it in the repo.
4. **Auth** (if chosen): `firebase_init` with `features.auth.providers`, from the app repo root. It covers Google, email/password and anonymous.
   - **Sign in with Apple** isn't in the MCP. The user enables it in the Firebase console → Authentication → Sign-in method → Apple, which needs only a toggle for native iOS. Give them the link: `https://console.firebase.google.com/project/<id>/authentication/providers`. Add the capability: an `<AppName>.entitlements` file outside `<AppName>/` (like `Config/`) with `com.apple.developer.applesignin` = `[Default]`, plus `CODE_SIGN_ENTITLEMENTS` in `project.yml`.
   - **Google:** also add the `GoogleSignIn` package (`https://github.com/google/GoogleSignIn-iOS`, product `GoogleSignIn`) and a URL type with the plist's `REVERSED_CLIENT_ID`.
   - The sign-in UI and flow are app code. Don't scaffold them here.
5. **Firestore** (if chosen): `firebase_init` with `features.firestore`, `location_id: eur3` (EU) unless the user says otherwise. Never take the default rules: they're open to everyone for 30 days. Pass locked rules instead (signed-in users reach only their own data):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```
   Then deploy them with `firebase_deploy` (`only: firestore`). Commit `firebase.json`, `.firebaserc` and `firestore.rules`.
6. More products later: add a `product:` line under the Firebase package in `project.yml`, then run `xcodegen generate`.

**PostHog** (PostHog MCP `exec`; read its `command` description for the syntax):
1. List projects. Reuse one or create `<Display Name>`.
2. Put the project's API token in `project.yml` → `POSTHOG_API_KEY`, then `xcodegen generate`. The token is public by design (it's in every shipped binary). Never use a personal API key here.

## 4. Verify, commit

- Build and test on the simulator (XcodeBuildMCP: load its skill first). Fix everything until it's green.
- `swiftlint --strict` if installed.
- Show the tree and the diff summary. On a yes, commit on `main`: `chore: scaffold <AppName>`.
- Remote: ask which owner (personal or an org). Then `gh repo create <owner>/<kebab-name> --private --source . --push`.

## 5. Hand off

Run `/ios-factory:setup-ios-cicd` in the new repo. It writes `AGENTS.md` and the PR checks, creates the App Store Connect app (`produce` needs an Apple ID and a 2FA prompt, which the user runs), and guides the two Xcode Cloud workflows. Create the `production` branch from `main` once it's pushed.
