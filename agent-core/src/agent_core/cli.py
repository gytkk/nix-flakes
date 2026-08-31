from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .core import (
    RUNTIMES,
    ValidationError,
    compare_trees,
    materialize,
    output_hash,
    render,
    resource_root,
)


def _check() -> list[str]:
    errors: list[str] = []
    golden_path = resource_root() / "schema" / "golden-hashes.toml"
    try:
        import tomllib

        with golden_path.open("rb") as handle:
            golden_document = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as error:
        return [f"invalid golden fixture: {error}"]
    if set(golden_document) != {"hashes"} or not isinstance(
        golden_document["hashes"], dict
    ):
        return ["golden fixture must contain only a hashes table"]
    goldens = golden_document["hashes"]
    if set(goldens) != set(RUNTIMES):
        return ["golden fixture must configure exactly the supported runtimes"]
    for runtime in RUNTIMES:
        try:
            actual = output_hash(materialize(runtime))
        except ValidationError as error:
            errors.append(f"{runtime}: {error}")
            continue
        expected = goldens.get(runtime)
        if not isinstance(expected, str):
            errors.append(f"{runtime}: missing golden hash")
        elif actual != expected:
            errors.append(
                f"{runtime}: output hash differs (expected {expected}, got {actual})"
            )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="agent-core")
    commands = parser.add_subparsers(dest="command", required=True)
    render_parser = commands.add_parser("render")
    render_parser.add_argument("--runtime", choices=RUNTIMES, required=True)
    render_parser.add_argument(
        "--runtime-skill-root",
        action="append",
        default=[],
        type=Path,
    )
    render_parser.add_argument("--output", type=Path, required=True)
    commands.add_parser("check")
    verify_parser = commands.add_parser("verify-install")
    verify_parser.add_argument("--expected", type=Path, required=True)
    verify_parser.add_argument("--actual", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "render":
            render(args.runtime, args.output, args.runtime_skill_root)
            print(f"rendered {args.runtime} to {args.output}")
            return 0
        if args.command == "check":
            errors = _check()
            if errors:
                print("check failed:", *errors, sep="\n", file=sys.stderr)
                return 1
            print("check passed: canonical resources and hashes are valid")
            return 0
        differences = compare_trees(args.expected, args.actual)
        if differences:
            print(
                "install verification failed:", *differences, sep="\n", file=sys.stderr
            )
            return 1
        print("install verification passed")
        return 0
    except ValidationError as error:
        print(f"agent-core: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
