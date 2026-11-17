#!/usr/bin/env bash
set -Eeuo pipefail
# Installs and activates a Node.js version via nvm, and makes it the default.
# Usage: set-node-version.sh [version]
#   version: anything nvm accepts (22, 22.11.0, lts/*, lts/jod). Defaults to
#            $NODE_VERSION, then lts/*.
# npm follows the Node version. Optionally pin npm with NPM_VERSION (e.g. 10).

NODE_VERSION_WANTED="${1:-${NODE_VERSION:-lts/*}}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "nvm not found in $NVM_DIR - skipping Node setup." >&2
  exit 0
fi

# nvm.sh is not safe under 'set -u', so relax it while sourcing/using nvm.
set +u
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

nvm install "$NODE_VERSION_WANTED"
nvm alias default "$NODE_VERSION_WANTED"
nvm use default
NODE_BIN="$(dirname "$(command -v node)")"
ln -sfn "$NODE_BIN" "$NVM_DIR/current"

if [ -n "${NPM_VERSION:-}" ]; then
  npm install -g "npm@${NPM_VERSION}"
fi
set -u

echo "Node $(node --version), npm $(npm --version) active (default: $NODE_VERSION_WANTED)."
