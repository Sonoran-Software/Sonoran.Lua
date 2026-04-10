#!/usr/bin/env bash

set -euo pipefail

version="$1"
root_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$root_dir/dist/roblox"

rm -rf "$output_dir"
mkdir -p "$output_dir/src/adapters"

cp "$root_dir/lua/sonoran/client.lua" "$output_dir/src/client.lua"
cp "$root_dir/lua/sonoran/adapters/roblox.lua" "$output_dir/src/adapters/roblox.lua"
cp "$root_dir/roblox/src/init.lua" "$output_dir/src/init.lua"
cp "$root_dir/roblox/default.project.json" "$output_dir/default.project.json"
cp "$root_dir/README.md" "$output_dir/README.md"

cat > "$output_dir/wally.toml" <<EOF
[package]
name = "sonoranbrian/sonoran-lua"
description = "Sonoran CAD v2 client for Roblox"
version = "${version}"
license = "PolyForm-Noncommercial-1.0.0"
authors = ["Sonoran Software"]
realm = "shared"
registry = "https://github.com/UpliftGames/wally-index"
repository = "https://github.com/Sonoran-Software/Sonoran.Lua"
include = ["default.project.json", "README.md", "src"]
EOF

cp "$root_dir/LICENSE" "$output_dir/LICENSE"

printf '%s\n' "$output_dir"
