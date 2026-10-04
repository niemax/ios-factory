#!/usr/bin/env bash
# Copies template/ into <dest>, fills in the placeholders and generates the
# Xcode project. Usage: scaffold.sh <dest> <AppName> <bundle.id> <TEAM_ID> [display name]
# Optional Firebase products: FIREBASE_AUTH=0 / FIREBASE_FIRESTORE=0 drop them (default: both in).
# LLM_PROVIDERS=openai,anthropic,gemini (any subset) adds backend/ (Cloud Functions LLM proxy)
# and Services/LLMService.swift; it forces Auth on, since the backend needs a uid.
set -euo pipefail

[[ $# -ge 4 ]] || { echo "usage: $0 <dest> <AppName> <bundle.id> <TEAM_ID> [display name]" >&2; exit 2; }
dest=$1 app=$2 bundle_id=$3 team=$4 display=${5:-$2}

[[ $app =~ ^[A-Z][A-Za-z0-9]*$ ]] || { echo "AppName must be UpperCamelCase, letters and digits: $app" >&2; exit 2; }
[[ $bundle_id =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || { echo "invalid bundle ID: $bundle_id" >&2; exit 2; }
[[ -e $dest && -n $(ls -A "$dest") ]] && { echo "$dest exists and is not empty" >&2; exit 1; }
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen" >&2; exit 1; }

skill_dir="$(cd "$(dirname "$0")" && pwd)"
providers=${LLM_PROVIDERS:-}
for provider in ${providers//,/ }; do
  [[ -f "$skill_dir/template-llm/backend/providers/$provider.js" ]] || { echo "unknown LLM provider: $provider" >&2; exit 2; }
done
mkdir -p "$dest"
cp -R "$skill_dir/template/." "$dest/"
cd "$dest"
mv gitignore .gitignore

if [[ -n $providers ]]; then
  FIREBASE_AUTH=1 FIREBASE_LLM=1
  cp -R "$skill_dir/template-llm/." .
  mv backend/gitignore backend/.gitignore
  for file in backend/providers/*.js; do
    name=$(basename "$file" .js)
    [[ $name == upstream || ,$providers, == *",$name,"* ]] || rm "$file"
  done
  for provider in ${providers//,/ }; do
    echo "export * as $provider from \"./$provider.js\";"
  done > backend/providers/index.js
  perl -pi -e "s/__LLM_CASES__/${providers//,/, }/" __APP__/Services/LLMService.swift
fi
mv __APP__Tests "${app}Tests"
mv __APP__ "$app"

# Optional product lines carry a marker: keep the line (minus marker) or drop it.
for product in AUTH FIRESTORE LLM; do
  flag=FIREBASE_$product default=1
  [[ $product == LLM ]] && default=0
  if [[ ${!flag:-$default} == 1 ]]; then perl -pi -e "s/ # __${product}__//" project.yml
  else perl -ni -e "print unless /# __${product}__/" project.yml; fi
done

export KEBAB=$(basename "$dest") APP=$app BUNDLE_ID=$bundle_id BUNDLE_PREFIX=${bundle_id%.*} TEAM=$team DISPLAY=$display
grep -rlI '__[A-Z_]*__' . | while read -r file; do
  perl -pi -e 's/__APP__/$ENV{APP}/g; s/__BUNDLE_ID__/$ENV{BUNDLE_ID}/g; s/__BUNDLE_PREFIX__/$ENV{BUNDLE_PREFIX}/g; s/__TEAM_ID__/$ENV{TEAM}/g; s/__DISPLAY_NAME__/$ENV{DISPLAY}/g; s/__KEBAB__/$ENV{KEBAB}/g' "$file"
done
if grep -rnI '__[A-Z_]*__' .; then echo "unfilled placeholders above" >&2; exit 1; fi

xcodegen generate --quiet
git init -q -b main
echo "Scaffolded $app ($bundle_id) in $dest"
