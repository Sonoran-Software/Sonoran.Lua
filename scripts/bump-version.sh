#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <patch|minor|major>" >&2
  exit 1
fi

bump_type="$1"
manifest_path="fxmanifest.lua"

current_version="$(sed -nE "s/^version '([0-9]+\\.[0-9]+\\.[0-9]+)'$/\\1/p" "$manifest_path")"

if [[ -z "$current_version" ]]; then
  echo "unable to read version from $manifest_path" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<< "$current_version"

case "$bump_type" in
  patch)
    patch=$((patch + 1))
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  *)
    echo "unsupported bump type: $bump_type" >&2
    exit 1
    ;;
esac

next_version="${major}.${minor}.${patch}"

sed -i.bak "s/^version '${current_version}'$/version '${next_version}'/" "$manifest_path"
rm -f "${manifest_path}.bak"

printf '%s\n' "$next_version"
