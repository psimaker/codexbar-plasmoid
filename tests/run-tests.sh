#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$repo_root"

python3 -m unittest discover -s tests -p 'test_*.py' -v
