#!/bin/bash

# Check for stale entries in .dialyzer_ignore.exs
# This script parses the file for all "lib/... .ex" paths and verifies each exists on disk.
# Exits with non-zero status if any referenced files are missing.

set -e

DIALYZER_IGNORE=".dialyzer_ignore.exs"

if [ ! -f "$DIALYZER_IGNORE" ]; then
    echo "Warning: $DIALYZER_IGNORE not found, skipping stale entry check"
    exit 0
fi

# Extract all quoted "lib/... .ex" paths from the file
# Pattern matches: {"lib/path/to/file.ex", ...}
PATHS=$(grep -oE '"lib/[^"]+\.ex"' "$DIALYZER_IGNORE" | tr -d '"' | sort -u)

MISSING=0
for path in $PATHS; do
    if [ ! -f "$path" ]; then
        echo "Missing file referenced in .dialyzer_ignore.exs: $path"
        MISSING=$((MISSING + 1))
    fi
done

if [ $MISSING -gt 0 ]; then
    echo ""
    echo "ERROR: $MISSING stale entry/entries found in $DIALYZER_IGNORE"
    echo "Please remove the missing file references from $DIALYZER_IGNORE"
    exit 1
fi

echo "All $DIALYZER_IGNORE entries reference existing files"
exit 0
