#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix-prefetch-github gnused
# shellcheck shell=bash

set -euo pipefail

cd "$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")"

latest_tag="$(curl -s ${GITHUB_TOKEN:+-u ":$GITHUB_TOKEN"} https://api.github.com/repos/canonical/multipass/releases/latest | jq -r '.tag_name')"
latest_version="${latest_tag#v}"
current_version="$(sed -n 's/.*version = "\(.*\)";/\1/p' package.nix | head -n1)"

if [[ "$current_version" == "$latest_version" ]]; then
  echo "multipass is up to date: $current_version"
  exit 0
fi

source_hash="$(nix-prefetch-github canonical multipass --rev "refs/tags/v$latest_version" | jq -r '.hash')"
grpc_version="$(curl -s "https://raw.githubusercontent.com/canonical/multipass/refs/tags/v$latest_version/3rd-party/submodule_info.md" | sed -n 's/^Version: \([^ ]*\).*$/\1/p' | head -n1)"
grpc_hash="$(nix-prefetch-github grpc grpc --rev "refs/tags/v$grpc_version" --fetch-submodules | jq -r '.hash')"

sed -i "s|version = \".*\";|version = \"$latest_version\";|" package.nix
sed -i "/repo = \"multipass\";/,/};/s|hash = \".*\";|hash = \"$source_hash\";|" package.nix
sed -i "/repo = \"grpc\";/,/};/s|rev = \".*\";|rev = \"refs/tags/v$grpc_version\";|" package.nix
sed -i "/repo = \"grpc\";/,/};/s|hash = \".*\";|hash = \"$grpc_hash\";|" package.nix
