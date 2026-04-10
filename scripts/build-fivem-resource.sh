#!/usr/bin/env bash

set -euo pipefail

version="$1"
root_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$root_dir/dist/fivem"
archive_path="$root_dir/dist/Sonoran.lua-fivem-${version}.zip"

rm -rf "$output_dir"
mkdir -p "$output_dir/lua/sonoran/adapters"

cp "$root_dir/fxmanifest.lua" "$output_dir/fxmanifest.lua"
cp "$root_dir/README.md" "$output_dir/README.md"
cp "$root_dir/lua/sonoran/client.lua" "$output_dir/lua/sonoran/client.lua"
cp "$root_dir/lua/sonoran/init.lua" "$output_dir/lua/sonoran/init.lua"
cp "$root_dir/lua/sonoran/adapters/fivem.lua" "$output_dir/lua/sonoran/adapters/fivem.lua"

rm -f "$archive_path"
(
  cd "$output_dir"
  zip -qr "$archive_path" .
)

printf '%s\n' "$archive_path"
