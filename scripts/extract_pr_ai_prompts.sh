#!/bin/bash
# Script to extract "Prompt for AI Agents" sections from PR review comments
# Usage: ./scripts/extract_pr_ai_prompts.sh <PR_NUMBER> [OUTPUT_FILE]
#
# Examples:
#   ./scripts/extract_pr_ai_prompts.sh 19
#   ./scripts/extract_pr_ai_prompts.sh 19 /tmp/prompts.md
#
# Requirements:
#   - gh (GitHub CLI) must be installed and authenticated
#   - jq must be installed

set -e

# Default repository (can be overridden with GITHUB_REPO env var)
REPO="${GITHUB_REPO:-guarzo/eveDMV}"

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <PR_NUMBER> [OUTPUT_FILE]"
    echo "Example: $0 19 /tmp/ai_prompts.md"
    exit 1
fi

PR_NUMBER="$1"
OUTPUT_FILE="${2:-pr${PR_NUMBER}_ai_agent_prompts.md}"

# Check for required tools
if ! command -v gh &> /dev/null; then
    echo "Error: gh (GitHub CLI) is not installed."
    echo "Install it with: sudo apt install gh"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    echo "Install it with: sudo apt install jq"
    exit 1
fi

# Check gh authentication
if ! gh auth status &> /dev/null; then
    echo "Error: gh is not authenticated."
    echo "Run: gh auth login"
    exit 1
fi

echo "Fetching PR #${PR_NUMBER} from ${REPO}..."

# Get the latest commit SHA from the PR
LATEST_COMMIT=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}" --jq '.head.sha')
if [ -z "$LATEST_COMMIT" ]; then
    echo "Error: Could not get latest commit for PR #${PR_NUMBER}"
    exit 1
fi

echo "Latest commit: ${LATEST_COMMIT}"

# Fetch all review comments
echo "Fetching review comments..."
TEMP_FILE=$(mktemp)
gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" --paginate > "$TEMP_FILE"

# Count total comments
TOTAL_COMMENTS=$(jq length "$TEMP_FILE")
echo "Found ${TOTAL_COMMENTS} review comments"

# Filter comments from the latest commit
LATEST_COMMIT_COMMENTS=$(mktemp)
jq --arg commit "$LATEST_COMMIT" '[.[] | select(.commit_id == $commit)]' "$TEMP_FILE" > "$LATEST_COMMIT_COMMENTS"
COMMIT_COMMENTS_COUNT=$(jq length "$LATEST_COMMIT_COMMENTS")
echo "Comments on latest commit: ${COMMIT_COMMENTS_COUNT}"

# Extract AI agent prompts
echo "Extracting AI agent prompts..."

# Create the output file with header
cat > "$OUTPUT_FILE" << EOF
# AI Agent Prompts from PR #${PR_NUMBER}

Repository: ${REPO}
Commit: ${LATEST_COMMIT}
Extracted: $(date -Iseconds)
Total review comments on commit: ${COMMIT_COMMENTS_COUNT}

---

EOF

# Extract prompts using jq and perl
PROMPT_COUNT=0
jq -r '.[] | "\n### File: \(.path)\n\n**Line \(.line // .original_line // "N/A")**\n\n\(.body)"' "$LATEST_COMMIT_COMMENTS" | \
perl -0777 -ne '
    while (/### File: ([^\n]+)\n\n\*\*Line ([^\*]+)\*\*\n\n.*?(?:<details>\s*<summary>Prompt for AI Agents<\/summary>\s*(.*?)<\/details>)/gs) {
        my ($file, $line, $prompt) = ($1, $2, $3);
        $prompt =~ s/^\s+|\s+$//g;  # Trim whitespace
        print "## $file (Line $line)\n\n";
        print "$prompt\n\n---\n\n";
        $count++;
    }
    END { print STDERR "Extracted $count prompts\n"; }
' >> "$OUTPUT_FILE"

# Count the extracted prompts
PROMPT_COUNT=$(grep -c "^## " "$OUTPUT_FILE" 2>/dev/null || echo "0")

# Update the header with count
sed -i "s/Total review comments on commit: ${COMMIT_COMMENTS_COUNT}/Total review comments on commit: ${COMMIT_COMMENTS_COUNT}\nAI agent prompts extracted: ${PROMPT_COUNT}/" "$OUTPUT_FILE"

# Cleanup
rm -f "$TEMP_FILE" "$LATEST_COMMIT_COMMENTS"

echo ""
echo "Done! Extracted ${PROMPT_COUNT} AI agent prompts"
echo "Output saved to: ${OUTPUT_FILE}"
