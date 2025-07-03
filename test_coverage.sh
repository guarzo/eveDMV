#!/bin/bash

# Test coverage calculation
JSON_FILE="cover/excoveralls.json"

echo "Testing coverage calculation..."

# Test simple extraction first
echo "Source files count:"
jq '.source_files | length' "$JSON_FILE"

echo "Getting total lines from coverage arrays:"
LINES_RELEVANT=$(jq '.source_files | map(.coverage) | flatten | map(select(. != null)) | length' "$JSON_FILE")
echo "Relevant lines: $LINES_RELEVANT"

LINES_COVERED=$(jq '.source_files | map(.coverage) | flatten | map(select(. > 0)) | length' "$JSON_FILE")
echo "Covered lines: $LINES_COVERED"

# Calculate coverage
if [ "$LINES_RELEVANT" -gt 0 ]; then
  COVERAGE=$(awk "BEGIN {printf \"%.1f\", $LINES_COVERED * 100 / $LINES_RELEVANT}")
  echo "Coverage: ${COVERAGE}%"
else
  echo "Coverage: 0.0%"
fi