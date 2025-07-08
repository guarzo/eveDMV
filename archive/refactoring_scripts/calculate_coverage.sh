#!/bin/bash

# Calculate coverage statistics from ExCoveralls JSON format
JSON_FILE="cover/excoveralls.json"

if [ ! -f "$JSON_FILE" ]; then
    echo "Coverage file not found: $JSON_FILE"
    exit 1
fi

# Extract coverage data using jq
RELEVANT_LINES=$(jq '.source_files | map(.coverage) | flatten | map(select(. != null)) | length' "$JSON_FILE")
COVERED_LINES=$(jq '.source_files | map(.coverage) | flatten | map(select(. > 0)) | length' "$JSON_FILE")
TOTAL_LINES=$(jq '.source_files | map(.source | split("\n") | length) | add' "$JSON_FILE")

# Calculate coverage percentage
if [ "$RELEVANT_LINES" -gt 0 ]; then
    COVERAGE=$(echo "scale=2; $COVERED_LINES * 100 / $RELEVANT_LINES" | bc -l)
else
    COVERAGE=0
fi

echo "Coverage: ${COVERAGE}%"
echo "Lines covered: $COVERED_LINES"
echo "Lines relevant: $RELEVANT_LINES"
echo "Total lines: $TOTAL_LINES"

# Create a summary JSON that matches the expected format
cat > coverage_summary.json << EOF
{
  "coverage": $COVERAGE,
  "stats": {
    "covered_lines": $COVERED_LINES,
    "relevant_lines": $RELEVANT_LINES,
    "total_lines": $TOTAL_LINES
  }
}
EOF

echo "Coverage summary written to coverage_summary.json"