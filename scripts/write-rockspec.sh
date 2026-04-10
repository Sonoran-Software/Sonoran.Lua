#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi

version="$1"
package_name="sonoran.lua"
rockspec_path="${package_name}-${version}-1.rockspec"

cat > "$rockspec_path" <<EOF
package = "${package_name}"
version = "${version}-1"

source = {
  url = "git+https://github.com/Sonoran-Software/Sonoran.Lua.git",
  tag = "v${version}"
}

description = {
  summary = "FiveM-first Lua SDK for Sonoran CAD v2 endpoints",
  homepage = "https://github.com/Sonoran-Software/Sonoran.Lua"
}

dependencies = {
  "lua >= 5.4"
}

build = {
  type = "builtin",
  modules = {
    ["sonoran"] = "lua/sonoran/init.lua",
    ["sonoran.client"] = "lua/sonoran/client.lua",
    ["sonoran.adapters.fivem"] = "lua/sonoran/adapters/fivem.lua"
  }
}
EOF

printf '%s\n' "$rockspec_path"
