#!/usr/bin/env bash
# Flags discouraged Swift/SwiftUI APIs on lines a PR *adds*. Untouched legacy
# code is never reported — same scoping rule as Apple's swiftui-specialist
# skill ("only the code you are modifying"). Reads a zero-context diff:
#   git diff -U0 BASE...HEAD -- '*.swift' | scripts/check-swift.sh
#
# Rules come from Apple's Xcode 27 agent skills (swiftui-specialist:
# soft-deprecated-apis.md, dataflow.md, foreach.md — export them with
# `xcrun agent skills export --output-dir <dir>`) plus the shared concurrency
# rule (no MainActor.run / DispatchQueue.main). Soft-deprecated APIs compile
# without warnings, which is why they need a check at all.
#
# Escape hatch for a deliberate use: put `swift-lint:allow` on the line.
set -uo pipefail

rules=(
  '\bNavigationView\b|NavigationView is soft-deprecated: use NavigationStack or NavigationSplitView'
  '\.foregroundColor\(|foregroundColor is soft-deprecated: use .foregroundStyle(_:)'
  '\.cornerRadius\(|cornerRadius is soft-deprecated: use .clipShape(.rect(cornerRadius:))'
  '\.navigationBarTitle\(|navigationBarTitle is soft-deprecated: use .navigationTitle(_:) + .navigationBarTitleDisplayMode(_:)'
  '\.navigationBarItems\(|navigationBarItems is soft-deprecated: use .toolbar'
  '\.navigationBarHidden\(|navigationBarHidden is soft-deprecated: use .toolbar(.hidden, for: .navigationBar)'
  '\.accentColor\(|accentColor is soft-deprecated: use .tint(_:)'
  '\.autocapitalization\(|autocapitalization is soft-deprecated: use .textInputAutocapitalization(_:)'
  '\.disableAutocorrection\(|disableAutocorrection is soft-deprecated: use .autocorrectionDisabled(_:)'
  '\.edgesIgnoringSafeArea\(|edgesIgnoringSafeArea is soft-deprecated: use .ignoresSafeArea(_:edges:)'
  '\.tabItem\b|tabItem is soft-deprecated: use Tab(title:image:value:content:)'
  '\bpresentationMode\b|presentationMode is soft-deprecated: use @Environment(\.dismiss) or \.isPresented'
  '\.actionSheet\(|\bActionSheet\(|actionSheet is soft-deprecated: use .confirmationDialog'
  '\bMagnificationGesture\b|MagnificationGesture is soft-deprecated: use MagnifyGesture'
  '\bRotationGesture\b|RotationGesture is soft-deprecated: use RotateGesture'
  '\bObservableObject\b|@Published\b|@StateObject\b|@ObservedObject\b|@EnvironmentObject\b|Use @Observable, not ObservableObject (Apple swiftui-specialist, dataflow)'
  '\bAnyView\b|Avoid AnyView: it erases structural identity (Apple swiftui-specialist, foreach/structure)'
  'ForEach\(.*\.indices|Do not use indices as ForEach identity: identify by a property of the element (Apple swiftui-specialist, foreach)'
  'MainActor\.run|Never use MainActor.run: express isolation with @MainActor / Task { @MainActor in } (AGENTS.md, Concurrency)'
  'DispatchQueue\.main\.|No DispatchQueue.main in new code: use @MainActor / Task (AGENTS.md, Concurrency)'
)

# One pass: turn the diff into "file<TAB>line<TAB>code" for every added line
# worth checking, then one grep per rule over that list.
added=$(awk '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^\+\+\+ /    { file = ""; next }
  /^@@ /        { split($3, hunk, ","); line = substr(hunk[1], 2) + 0; next }
  /^\+/ {
    code = substr($0, 2)
    if (file != "" && code !~ /swift-lint:allow/ && code !~ /^[[:space:]]*\/\//)
      printf "%s\t%d\t%s\n", file, line, code
    line++
  }
')

findings=""
for rule in "${rules[@]}"; do
  pattern="${rule%|*}"; message="${rule##*|}"
  hits=$(printf '%s\n' "$added" | grep -E $'^[^\t]*\t[0-9]+\t.*('"$pattern"')' | cut -f1,2 | tr '\t' ':')
  [ -n "$hits" ] && findings+=$(printf '%s\n' "$hits" | sed "s|\$|: $message|")$'\n'
done

[ -z "$findings" ] && exit 0
printf '%s' "$findings" | sort -t: -k1,1 -k2,2n
exit 1
