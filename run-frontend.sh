#!/usr/bin/env bash
set -euo pipefail

# Resolve paths from this script, regardless of the terminal's current folder.
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
local_node="$project_dir/contracts/.tools/node-v22.23.2-linux-x64/bin"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # This workspace's Node runtime and dependencies were installed in WSL.
    if [[ -f "$local_node/node" ]] && command -v wsl.exe >/dev/null 2>&1; then
      exec wsl.exe --cd "$(cygpath -w "$project_dir")" \
        --exec bash ./run-frontend.sh "$@"
    fi
    ;;
  Linux*)
    if [[ -x "$local_node/node" ]]; then
      export PATH="$local_node:$PATH"
    fi
    ;;
esac

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  printf 'Node.js and npm are required. Install Node.js 22.12 or newer.\n' >&2
  exit 1
fi

node -e '
  const [major, minor] = process.versions.node.split(".").map(Number);
  if (major < 22 || (major === 22 && minor < 12)) {
    console.error("Node.js 22.12 or newer is required.");
    process.exit(1);
  }
'

cd -- "$project_dir/frontend"
if [[ ! -d node_modules ]]; then
  printf 'Installing frontend dependencies...\n'
  npm ci
fi

printf 'Starting TipJar. Open the URL below. Press Ctrl+C to stop.\n'
exec npm run dev -- "$@"
