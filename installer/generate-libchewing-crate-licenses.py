#!/usr/bin/env python3
# Generated with assistance from OpenAI Codex.

"""Generate deterministic license notices for crates linked into chewing.dll."""

import argparse
import hashlib
import os
from pathlib import Path
import sys
import tomllib


# Keep this allowlist synchronized with:
# cargo tree -p chewing_capi --features sqlite --edges normal,build
# Build-only crates are intentionally excluded because they are not distributed.
RUNTIME_CRATES = (
    "anstream",
    "anstyle",
    "anstyle-parse",
    "anstyle-query",
    "anstyle-wincon",
    "bitflags",
    "colorchoice",
    "der",
    "env_filter",
    "env_logger",
    "fallible-iterator",
    "fallible-streaming-iterator",
    "foldhash",
    "hashbrown",
    "hashlink",
    "is_terminal_polyfill",
    "libsqlite3-sys",
    "log",
    "once_cell_polyfill",
    "rusqlite",
    "smallvec",
    "utf8parse",
    "windows-link",
    "windows-sys",
)


def find_crate_directory(name, version, registry_roots):
    for root in registry_roots:
        candidate = root / "{}-{}".format(name, version)
        if candidate.is_dir():
            return candidate
    raise FileNotFoundError(
        "Cargo source is unavailable for {} {}".format(name, version))


def license_files(crate_directory):
    prefixes = ("LICENSE", "COPYING", "NOTICE", "UNLICENSE")
    files = sorted(
        path for path in crate_directory.iterdir()
        if path.is_file() and path.name.upper().startswith(prefixes))
    if not files:
        raise FileNotFoundError(
            "No license file found in {}".format(crate_directory))
    return files


def normalize_text(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()


def generate(repository_root):
    lock_path = repository_root / "libchewing" / "Cargo.lock"
    lock = tomllib.loads(lock_path.read_text(encoding="utf-8"))
    packages = {
        package["name"]: package
        for package in lock["package"]
        if package["name"] in RUNTIME_CRATES
    }
    missing = sorted(set(RUNTIME_CRATES) - set(packages))
    if missing:
        raise ValueError(
            "Runtime crates missing from Cargo.lock: {}".format(
                ", ".join(missing)))

    cargo_home = Path(os.environ.get("CARGO_HOME", Path.home() / ".cargo"))
    registry_roots = sorted((cargo_home / "registry" / "src").glob("*"))
    if not registry_roots:
        raise FileNotFoundError("Cargo registry sources are unavailable")

    crate_records = []
    license_texts = {}
    for name in sorted(RUNTIME_CRATES):
        package = packages[name]
        version = package["version"]
        crate_directory = find_crate_directory(
            name, version, registry_roots)
        manifest = tomllib.loads(
            (crate_directory / "Cargo.toml").read_text(encoding="utf-8"))
        expression = manifest["package"].get("license", "not specified")
        file_records = []
        for path in license_files(crate_directory):
            content = normalize_text(path)
            digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
            license_texts.setdefault(digest, {
                "content": content,
                "users": [],
            })["users"].append(
                "{} {} ({})".format(name, version, path.name))
            file_records.append("{}:{}".format(path.name, digest[:12]))
        crate_records.append(
            "{} {} | {} | {}".format(
                name, version, expression, ", ".join(file_records)))

    lines = [
        "Bundled Rust Crate Licenses",
        "=" * 78,
        "",
        "Generated from libchewing/Cargo.lock and PIME's chewing_capi runtime",
        "crate allowlist. Build-only and test-only crates are excluded.",
        "",
        "Packages",
        "-" * 78,
        *crate_records,
    ]
    for digest in sorted(license_texts):
        record = license_texts[digest]
        lines.extend([
            "",
            "",
            "License text {}".format(digest),
            "-" * 78,
            "Used by:",
            *("  - " + user for user in sorted(record["users"])),
            "",
            record["content"],
        ])
    return "\r\n".join(lines) + "\r\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    repository_root = Path(__file__).resolve().parent.parent
    content = generate(repository_root)
    if args.check:
        if not args.output.is_file():
            raise FileNotFoundError(args.output)
        if args.output.read_text(encoding="utf-8") != content.replace(
                "\r\n", "\n"):
            raise ValueError(
                "{} is stale; regenerate installer licenses".format(
                    args.output))
    else:
        args.output.write_text(
            content, encoding="utf-8", newline="")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(error, file=sys.stderr)
        sys.exit(1)
