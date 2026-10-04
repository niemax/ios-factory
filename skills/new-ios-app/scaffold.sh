#!/usr/bin/env bash
# Copies template/ into <dest>, fills in the placeholders and generates the
# Xcode project. Usage: scaffold.sh <dest> <AppName> <bundle.id> <TEAM_ID> [display name]
# Optional Firebase products: FIREBASE_AUTH=0 / FIREBASE_FIRESTORE=0 drop them (default: both in).
set -euo pipefail

[[ $# -ge 4 ]] || { echo "usage: $0 <dest> <AppName> <bundle.id> <TEAM_ID> [display name]" >&2; exit 2; }
dest=$1 app=$2 bundle_id=$3 team=$4 display=${5:-$2}

[[ $app =~ ^[A-Z][A-Za-z0-9]*$ ]] || { echo "AppName must be UpperCamelCase, letters and digits: $app" >&2; exit 2; }
[[ $bundle_id =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || { echo "invalid bundle ID: $bundle_id" >&2; exit 2; }
[[ -e $dest && -n $(ls -A "$dest") ]] && { echo "$dest exists and is not empty" >&2; exit 1; }
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen" >&2; exit 1; }

template="$(cd "$(dirname "$0")" && pwd)/template"
mkdir -p "$dest"
cp -R "$template/." "$dest/"
cd "$dest"
mv gitignore .gitignore
mv __APP__Tests "${app}Tests"
mv __APP__ "$app"

# Optional product lines carry a marker: keep the line (minus marker) or drop it.
for product in AUTH FIRESTORE; do
  flag=FIREBASE_$product
  if [[ ${!flag:-1} == 1 ]]; then perl -pi -e "s/ # __${product}__//" project.yml
  else perl -ni -e "print unless /# __${product}__/" project.yml; fi
done

export APP=$app BUNDLE_ID=$bundle_id BUNDLE_PREFIX=${bundle_id%.*} TEAM=$team DISPLAY=$display
grep -rlI '__[A-Z_]*__' . | while read -r file; do
  perl -pi -e 's/__APP__/$ENV{APP}/g; s/__BUNDLE_ID__/$ENV{BUNDLE_ID}/g; s/__BUNDLE_PREFIX__/$ENV{BUNDLE_PREFIX}/g; s/__TEAM_ID__/$ENV{TEAM}/g; s/__DISPLAY_NAME__/$ENV{DISPLAY}/g' "$file"
done
if grep -rnI '__[A-Z_]*__' .; then echo "unfilled placeholders above" >&2; exit 1; fi

xcodegen generate --quiet
git init -q -b main
echo "Scaffolded $app ($bundle_id) in $dest"
