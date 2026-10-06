#!/usr/bin/env bash
# Shared by the smoke and documentation renderers. Callers set repo, work,
# CODEXBAR_MOCK_STATE and failed, and run with set -euo pipefail.
set -euo pipefail

# package NAME KEY=VALUE... copies the checkout with scenario defaults.
package() {
    local dir="$work/pkg-$1"
    shift
    mkdir -p "$dir"
    cp -r "$repo/metadata.json" "$repo/contents" "$dir/"
    local xml="$dir/contents/config/main.xml" pair key value
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        awk -v key="$key" -v value="$value" '
            index($0, "<entry name=\"" key "\"") { hit = 1 }
            hit && /<default>/ { sub(/<default>.*<\/default>/, "<default>" value "</default>"); hit = 0 }
            { print }
        ' "$xml" >"$xml.new"
        mv "$xml.new" "$xml"
        grep -q -F "<default>$value</default>" "$xml" || { echo "unknown setting: $key" >&2; return 1; }
    done
    echo "$dir"
}

# expect_config ID... checks the mock config.json's enabled providers.
expect_config() {
    local want have
    want="$(printf '%s\n' "$@" | sort | tr '\n' ' ')"
    have="$({ cat "$CODEXBAR_MOCK_STATE" 2>/dev/null || echo codex; } | sort | tr '\n' ' ')"
    if [[ "$want" != "$have" ]]; then
        echo "config.json enables [$have], expected [$want]" >&2
        failed=1
    fi
}
