#!/usr/bin/env python3
"""Validate that a release tag and the packaged metadata version agree."""

import argparse
import json
import pathlib
import re
import sys


SEMVER_TAG = re.compile(
    r"^v(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)"
    r"(?:-(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)"
    r"(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Require a v<semver> tag matching KPlugin.Version."
    )
    parser.add_argument("tag", help="release tag, for example v0.3.1")
    parser.add_argument(
        "metadata", nargs="?", default="metadata.json", help="metadata.json path"
    )
    args = parser.parse_args()

    match = SEMVER_TAG.fullmatch(args.tag)
    if match is None:
        print(
            f"release-version: tag must use the v<semver> form: {args.tag}",
            file=sys.stderr,
        )
        return 1

    metadata_path = pathlib.Path(args.metadata)
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        version = metadata["KPlugin"]["Version"]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        print(f"release-version: invalid metadata: {error}", file=sys.stderr)
        return 1

    expected = args.tag[1:]
    if version != expected:
        print(
            "release-version: metadata version "
            f"{version!r} does not match release tag {args.tag!r}",
            file=sys.stderr,
        )
        return 1

    print(f"Release tag {args.tag} matches metadata version {version}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
