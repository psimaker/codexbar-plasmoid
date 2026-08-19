#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$repo_root"

python3 -m unittest discover -s tests -p 'test_*.py' -v

if ! command -v node >/dev/null 2>&1; then
    echo "node: not available; CLI status tests cannot run" >&2
    exit 1
fi
node tests/test-cli-status.js
