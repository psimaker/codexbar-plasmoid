#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Build a reproducible Plasma widget package from a Git commit.

Usage:
  scripts/build-plasmoid.sh [--force] [GIT_REF]
  scripts/build-plasmoid.sh --help

GIT_REF defaults to HEAD. The package and its SHA-256 checksum are written to
dist/. Existing artifacts are preserved unless --force is supplied.
EOF
}

fail() {
    printf 'build-plasmoid: %s\n' "$*" >&2
    exit 1
}

force=false
ref="HEAD"
ref_seen=false

while (($# > 0)); do
    case "$1" in
        --force)
            force=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            if (($# > 1)); then
                fail "expected at most one Git ref"
            fi
            if (($# == 1)); then
                ref="$1"
                ref_seen=true
            fi
            break
            ;;
        -*)
            fail "unknown option: $1 (use --help for usage)"
            ;;
        *)
            if [[ "$ref_seen" == true ]]; then
                fail "expected at most one Git ref"
            fi
            ref="$1"
            ref_seen=true
            ;;
    esac
    shift
done

for tool in git python3 tar unzip sha256sum; do
    command -v "$tool" >/dev/null 2>&1 || fail "required tool is not available: $tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" \
    || fail "the script must be run from a Git worktree"
cd "$repo_root"

commit="$(git rev-parse --verify "${ref}^{commit}" 2>/dev/null)" \
    || fail "Git ref does not resolve to a commit: $ref"

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
package_root="$tmp_dir/package"
mkdir -p "$package_root"

if ! git archive --format=tar "$commit" -- metadata.json contents LICENSE \
        | tar -xf - -C "$package_root"; then
    fail "could not extract required package files from Git ref: $ref"
fi

[[ -f "$package_root/metadata.json" ]] \
    || fail "metadata.json is missing at Git ref: $ref"
[[ -f "$package_root/contents/ui/main.qml" ]] \
    || fail "contents/ui/main.qml is missing at Git ref: $ref"
[[ -f "$package_root/LICENSE" ]] \
    || fail "LICENSE is missing at Git ref: $ref"

if find "$package_root" -type l -print -quit | grep -q .; then
    fail "symbolic links are not allowed in the package"
fi

metadata_values="$tmp_dir/metadata-values"
if ! python3 - "$package_root/metadata.json" >"$metadata_values" <<'PY'
import json
import re
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        metadata = json.load(handle)
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"invalid metadata.json: {error}")

structure = metadata.get("KPackageStructure")
if structure != "Plasma/Applet":
    raise SystemExit(
        "metadata.json KPackageStructure must be exactly Plasma/Applet"
    )

plugin = metadata.get("KPlugin")
if not isinstance(plugin, dict):
    raise SystemExit("metadata.json KPlugin must be an object")

plugin_id = plugin.get("Id")
version = plugin.get("Version")
minimum = metadata.get("X-Plasma-API-Minimum-Version")

if not isinstance(plugin_id, str) or not re.fullmatch(r"[A-Za-z0-9._-]+", plugin_id):
    raise SystemExit("metadata.json contains an invalid or missing KPlugin.Id")
if not isinstance(version, str) or not re.fullmatch(r"[0-9A-Za-z.+-]+", version):
    raise SystemExit("metadata.json contains an invalid or missing KPlugin.Version")
if not isinstance(minimum, str) or not minimum.strip():
    raise SystemExit("metadata.json is missing X-Plasma-API-Minimum-Version")

def numeric_version(value):
    if not re.fullmatch(r"\d+(?:\.\d+)*", value):
        raise SystemExit(
            "X-Plasma-API-Minimum-Version must contain only numeric components"
        )
    parts = [int(component) for component in value.split(".")]
    return tuple((parts + [0, 0])[:2])

if numeric_version(minimum) < (6, 0):
    raise SystemExit("X-Plasma-API-Minimum-Version must be at least 6.0")

print(plugin_id)
print(version)
print(minimum)
PY
then
    fail "metadata validation failed for Git ref: $ref"
fi

mapfile -t values <"$metadata_values"
[[ ${#values[@]} -eq 3 ]] || fail "metadata validation returned incomplete data"
plugin_id="${values[0]}"
version="${values[1]}"

dist_dir="$repo_root/dist"
artifact_name="${plugin_id}-${version}.plasmoid"
checksum_name="${artifact_name}.sha256"
artifact="$dist_dir/$artifact_name"
checksum="$dist_dir/$checksum_name"

if [[ "$force" != true ]]; then
    [[ ! -e "$artifact" ]] \
        || fail "artifact already exists: $artifact (use --force to replace it)"
    [[ ! -e "$checksum" ]] \
        || fail "checksum already exists: $checksum (use --force to replace it)"
fi

mkdir -p "$dist_dir"
tmp_artifact="$tmp_dir/$artifact_name"
tmp_checksum="$tmp_dir/$checksum_name"
commit_epoch="$(git show -s --format=%ct "$commit")"

if ! python3 - "$package_root" "$tmp_artifact" "$commit_epoch" <<'PY'
import datetime
import pathlib
import stat
import sys
import zipfile

root = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
epoch = int(sys.argv[3])
timestamp = datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc)
timestamp = max(timestamp, datetime.datetime(1980, 1, 1, tzinfo=datetime.timezone.utc))
zip_timestamp = timestamp.timetuple()[:6]

paths = [root / "metadata.json", root / "LICENSE"]
paths.extend(path for path in (root / "contents").rglob("*") if path.is_file())

with zipfile.ZipFile(
    output, mode="x", compression=zipfile.ZIP_DEFLATED, compresslevel=9
) as archive:
    for path in sorted(paths, key=lambda item: item.relative_to(root).as_posix()):
        relative = path.relative_to(root).as_posix()
        info = zipfile.ZipInfo(relative, date_time=zip_timestamp)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.create_system = 3
        source_mode = stat.S_IMODE(path.stat().st_mode)
        normalized_mode = 0o755 if source_mode & 0o111 else 0o644
        info.external_attr = (stat.S_IFREG | normalized_mode) << 16
        with path.open("rb") as handle:
            archive.writestr(info, handle.read(), compress_type=zipfile.ZIP_DEFLATED,
                             compresslevel=9)
PY
then
    fail "failed to create the package archive"
fi

unzip -t "$tmp_artifact" >/dev/null \
    || fail "archive integrity validation failed"

archive_entries="$tmp_dir/archive-entries"
unzip -Z1 "$tmp_artifact" >"$archive_entries" \
    || fail "could not inspect archive entries"

grep -Fxq "metadata.json" "$archive_entries" \
    || fail "metadata.json is not at the package root"
grep -Fxq "contents/ui/main.qml" "$archive_entries" \
    || fail "contents/ui/main.qml is missing from the archive"

while IFS= read -r entry; do
    case "$entry" in
        metadata.json|LICENSE|contents/*)
            ;;
        *)
            fail "unexpected archive entry: $entry"
            ;;
    esac
done <"$archive_entries"

(
    cd "$tmp_dir"
    sha256sum "$artifact_name" >"$checksum_name"
)
(
    cd "$tmp_dir"
    sha256sum --check --status "$checksum_name"
) || fail "generated SHA-256 checksum does not match the archive"

if [[ "$force" == true ]]; then
    rm -f -- "$artifact" "$checksum"
else
    [[ ! -e "$artifact" && ! -e "$checksum" ]] \
        || fail "an output artifact appeared while the package was being built"
fi

mv -- "$tmp_artifact" "$artifact"
mv -- "$tmp_checksum" "$checksum"

printf 'Built %s from %s (%s)\n' "$artifact" "$ref" "$commit"
printf 'Checksum: %s\n' "$checksum"
