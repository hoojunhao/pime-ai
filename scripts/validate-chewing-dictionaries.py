#!/usr/bin/env python3
"""Validate layered Chewing CSV dictionaries before generating runtime data."""

# Generated with assistance from OpenAI GPT-5.6.

import argparse
import csv
from pathlib import Path


def read_entries(path, reject_duplicates):
    """Return phrase-reading keys after validating one dictionary source."""
    entries = set()
    with path.open("r", encoding="utf-8", newline="") as source:
        rows = csv.reader(
            line for line in source
            if line.strip() and not line.lstrip().startswith("#"))
        for line_number, row in enumerate(rows, start=1):
            if len(row) != 3:
                raise ValueError(
                    "{}: data row {} must contain three columns".format(
                        path, line_number))

            phrase, frequency, reading = (column.strip() for column in row)
            if not phrase or not reading:
                raise ValueError(
                    "{}: data row {} has an empty phrase or reading".format(
                        path, line_number))
            try:
                parsed_frequency = int(frequency)
            except ValueError as error:
                raise ValueError(
                    "{}: data row {} has an invalid frequency".format(
                        path, line_number)) from error
            if parsed_frequency < 0:
                raise ValueError(
                    "{}: data row {} has a negative frequency".format(
                        path, line_number))

            syllables = reading.split()
            if len(phrase) != len(syllables):
                raise ValueError(
                    "{}: data row {} has {} characters but {} syllables".
                    format(path, line_number, len(phrase), len(syllables)))

            key = (phrase, " ".join(syllables))
            if reject_duplicates and key in entries:
                raise ValueError(
                    "{}: duplicate entry at data row {}: {}".format(
                        path, line_number, phrase))
            entries.add(key)
    return entries


def validate_layers(base_paths, overlay_paths):
    """Reject duplicate phrase-reading pairs within or across all layers."""
    known_entries = {}
    for path in base_paths:
        entries = read_entries(path, reject_duplicates=False)
        for key in entries:
            known_entries.setdefault(key, path)
        print("{}: {} unique entries".format(path, len(entries)))

    for path in overlay_paths:
        entries = read_entries(path, reject_duplicates=True)
        for key in entries:
            if key in known_entries:
                raise ValueError(
                    "{} duplicates {} from {}".format(
                        path, key[0], known_entries[key]))
            known_entries[key] = path
        print("{}: {} entries".format(path, len(entries)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--base", action="append", default=[], type=Path,
        help="Upstream dictionary CSV; may be repeated.")
    parser.add_argument(
        "--overlay", action="append", default=[], type=Path,
        help="Project overlay CSV in load order; may be repeated.")
    args = parser.parse_args()
    if not args.overlay:
        parser.error("at least one --overlay is required")

    try:
        validate_layers(args.base, args.overlay)
    except (OSError, UnicodeError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
