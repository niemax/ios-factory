#!/usr/bin/env bash
# Self-check for check-swift.sh. Run: scripts/test-check-swift.sh
set -u
cd "$(dirname "$0")"
fails=0

diff=$(cat <<'EOF'
diff --git a/App/Feed.swift b/App/Feed.swift
--- a/App/Feed.swift
+++ b/App/Feed.swift
@@ -10,0 +11,9 @@ struct Feed: View {
+        NavigationView {
+            Text("x").foregroundStyle(.red)
+            Text("y").foregroundColor(.red)
+            // NavigationView in a comment is fine
+            AnyView(Text("z")) // swift-lint:allow
+            ForEach(items.indices, id: \.self) { index in }
+        }
+        await MainActor.run { }
+final class Store: ObservableObject {}
@@ -40 +49 @@ struct Feed: View {
-        .cornerRadius(8)
+        .clipShape(.rect(cornerRadius: 8))
EOF
)

out=$(printf '%s\n' "$diff" | ./check-swift.sh)
status=$?

expect_line() {
  if ! grep -qF "$1" <<<"$out"; then echo "missing: $1"; fails=1; fi
}
expect_line "App/Feed.swift:11: NavigationView"
expect_line "App/Feed.swift:13: foregroundColor"
expect_line "App/Feed.swift:16: Do not use indices"
expect_line "App/Feed.swift:18: Never use MainActor.run"
expect_line "App/Feed.swift:19: Use @Observable"

count=$(grep -c . <<<"$out")
[ "$count" -eq 5 ] || { echo "expected 5 findings, got $count:"; echo "$out"; fails=1; }
[ "$status" -eq 1 ] || { echo "expected exit 1, got $status"; fails=1; }

# Clean diff (removed lines only, modern APIs added) passes.
printf -- '--- a/A.swift\n+++ b/A.swift\n@@ -1 +1 @@\n-        .cornerRadius(8)\n+        .clipShape(.rect(cornerRadius: 8))\n' | ./check-swift.sh >/dev/null \
  || { echo "clean diff failed"; fails=1; }

[ "$fails" -eq 0 ] && echo "all passed"
exit "$fails"
