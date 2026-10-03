# Project Guidelines

<!-- Template from niemax/ios-factory (skills/setup-ios-cicd). Every `{{…}}` placeholder
and "tailor" comment is replaced or deleted by the skill; none survive into
the written file. Domain knowledge goes in the app repo only, never back here. -->

## Architecture

{{AppName}} — {{one line: iOS (SwiftUI) app + backend, if any, and what the backend is for}}.

**Stack:** {{frameworks actually imported + SPM packages from project.yml / Package.resolved}}
**Backend:** {{language, host, what it proxies/holds; delete line if no backend}}

**Layout:**
- `{{client dir}}/` — iOS app. {{top-level source folders}}. {{XcodeGen: "`project.yml` is the XcodeGen spec; its generated `.xcodeproj` is committed so Xcode Cloud can open it after cloning" — or plain .xcodeproj}}
- {{backend dir, docs dir, one line each}}
- `CONTEXT.md` — canonical glossary ({{5–10 key terms}}). Use these terms in code and copy; update the glossary if the language shifts rather than running two vocabularies in parallel.

## The load-bearing decision

<!-- tailor: the one decision everything else follows from — usually the
product's differentiator or its cost model. Propose it from ADRs/PRD, confirm
with the user. Shape: bold claim, what follows from it, what change would break
the product ("Raise it before building it"), what the backend exists for. -->
{{load-bearing decision}}

## Project generation

<!-- tailor: XcodeGen projects only; delete section otherwise -->
```bash
cd {{client dir}} && xcodegen generate
```

Run after `project.yml` changes or files are added/removed under `{{source dir}}/`. Commit the regenerated `.xcodeproj` with the change. Xcode Cloud builds what is committed.

## Build / test / run

```bash
xcodebuildmcp simulator build --project-path {{xcodeproj path}} --scheme {{Scheme}} --simulator-name "iPhone 17"
xcodebuildmcp simulator test --project-path {{xcodeproj path}} --scheme {{Scheme}} --simulator-name "iPhone 17"
xcodebuildmcp simulator build-and-run --project-path {{xcodeproj path}} --scheme {{Scheme}} --simulator-name "iPhone 17"
```

Use XcodeBuildMCP after meaningful iOS changes. Build/test before marking work done. Fix all errors.

<!-- tailor: add backend build/test commands from its package manifest; add
device-only caveats (camera, sensors) if the app has features the simulator
can't exercise -->

## iOS Conventions

**Target:** iOS {{deployment target}}+, {{devices/orientation from project settings}}.

**Feature folder structure:**
<!-- tailor: describe the structure the code ALREADY uses (inspect 2–3 feature
folders). For a greenfield app, use: Views/ (view + its view model),
Components/, Utils/ -->
```
{{feature folder tree}}
```
- **Any view that fetches, loads or stores owns a view model**, `@MainActor @Observable` and held by the view as `@State`. Backend calls, persistence writes and heavy work start there. The view keeps layout, navigation and purely visual state. Pure logic the view model leans on goes in `Utils/`, where a test can reach it without either.
- Visual building blocks go in `Components/`, feature-local business logic in `Utils/`. One type per file.
- If a type is used by two features, it moves to a shared folder ({{shared folders}}). Nothing feature-specific goes there.
- Extract business logic to plain types so it is testable without a view.
- Inject shared state via `.environment()` — only if not already accessible from the component
- NEVER add padding to reusable components — consumer decides spacing
- Avoid computed variables in view body — extract to dedicated component files
- NEVER define more than one view struct per file — always extract to its own file
- NEVER use extensions on a view struct to organize its own private members — use `private` directly in the struct
- Extract views before they hit 150 LoC
- Always cancel async tasks on view disappear (prefer `.task {}` which auto-cancels)

## Apple guidance (Xcode agent skills)

Apple ships authoritative agent skills with Xcode. They supersede training data on these topics. Install or refresh them (re-run after every Xcode update):

```bash
xcrun agent skills export --output-dir ~/.claude/skills
```

- **Any SwiftUI change:** follow `swiftui-specialist`; for APIs new this cycle, `swiftui-whats-new-*`.
- **Tests:** new and touched tests follow `modernize-tests` (Swift Testing).
- **Never introduce a soft-deprecated API** — they compile without warnings. Check `swiftui-specialist/references/soft-deprecated-apis.md` when unsure.
- Same scoping rule as Apple's: apply this to the code you are changing. Don't flag or migrate untouched code unless asked.

`pr-checks.yml` runs `swift-lint` (shared from `niemax/ios-factory`). It flags soft-deprecated APIs, `ObservableObject`, `AnyView`, index-based `ForEach` identity, `MainActor.run` and `DispatchQueue.main` **on lines a PR adds**. For a deliberate exception, put `// swift-lint:allow` on the line with the reason. Never merge while it's red.

## Concurrency

**Never use `MainActor.run`.** Reaching for it almost always means isolation is modelled wrong. Express isolation instead:

- Mark the type or function `@MainActor` and `await` it — a `Task {}` created inside a `@MainActor` type already inherits that isolation, so there is nothing to hop to.
- From a `nonisolated` context, use `Task { @MainActor in … }`.
- Needs to be isolated to something else? Use an `actor`.

Same for `DispatchQueue.main.async` in new code.

**Keep expensive work off the main actor.** {{the app's actual heavy work: image processing, Vision, decoding, payload encoding — name the types}}. Do the work `nonisolated`, return a small `Sendable` result, and hop to the main actor once to publish it.

<!-- tailor: one "## <Area> invariants" section per area that has hard rules
(from ADRs, code comments that say NEVER/always, limits/config files). Each
bullet: bold rule, one-line why, ADR link. Skip areas with nothing load-bearing;
never invent rules the repo doesn't already hold. -->
{{invariant sections}}

## Rules

- No comments unless logic is non-obvious
- Delete dead code — don't comment it out
- Use Context7 MCP for all library/API documentation lookups (Apple's Xcode skills take precedence for SwiftUI)
- No single-letter variables - always declare clear intent
- Non-trivial logic leaves one runnable check behind — see `{{test dirs}}`

## Commits

Every commit must follow Conventional Commits: `<type>[(scope)][!]: <description>`, types `feat fix perf refactor docs style test build ci chore revert` (e.g. `feat({{scope}}): …`, `fix: …`). `!` or a `BREAKING CHANGE:` footer marks a breaking change.

- `pr-checks.yml` runs `commit-lint` on every non-merge commit in a PR. Never merge a PR while it's red.
- `feat:` and `fix:` subjects become user-facing release notes, so write them for users. Version bumps are inferred from commit types (`feat` → minor, `fix`/`perf` → patch, `!` → major).

## Release

- **Merge to `main`** → Xcode Cloud archives and uploads an **internal** TestFlight build.
- **Merge to `production`** → the App Store release: version bump, release notes / What's New, App Store metadata and submit-for-review. Never wire any of those to `main`.

Xcode Cloud is configured in App Store Connect, not in this repo. Release metadata tooling lives in `niemax/ios-factory`.

<!-- tailor: keep the repo's existing "Agent skills" / issue-tracker /
CodeGraph sections verbatim if present -->
