#!/bin/bash
# Workstream Coordination Check Script
# Part of Sprint 22a Workstream 5: Build Quality & Automation

set -e

echo "🔍 Workstream Coordination Check"
echo "================================"

# Check if we're in a Git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "✅ Not in a Git repository, skipping conflict checks"
    exit 0
fi

# Check for uncommitted changes that might conflict with other workstreams
echo "📋 Checking for potential workstream conflicts..."

# Check for modifications to shared files
SHARED_FILES=(
    "lib/eve_dmv/application.ex"
    "lib/eve_dmv/api.ex"
    "mix.exs"
    "config/"
    ".pre-commit-config.yaml"
)

conflict_found=false

for file_pattern in "${SHARED_FILES[@]}"; do
    if git status --porcelain | grep -q "$file_pattern"; then
        echo "⚠️  Shared file modified: $file_pattern"
        echo "   → Coordinate with other workstreams before committing"
        conflict_found=true
    fi
done

# Check for large number of files modified (might indicate cross-workstream changes)
modified_count=$(git status --porcelain | wc -l)
if [ "$modified_count" -gt 20 ]; then
    echo "⚠️  Large number of files modified ($modified_count)"
    echo "   → Consider breaking changes into smaller commits"
    echo "   → Coordinate with other workstreams if affecting shared areas"
    conflict_found=true
fi

# Check for specific workstream file patterns
echo ""
echo "📊 Workstream File Analysis:"

ws1_files=$(git status --porcelain | grep -c "lib/eve_dmv/analytics/" || echo "0")
ws2_files=$(git status --porcelain | grep -c "lib/eve_dmv/contexts/intelligence_infrastructure/" || echo "0")
ws3_files=$(git status --porcelain | grep -c -E "(lib/eve_dmv/application.ex|lib/eve_dmv/api/)" || echo "0")
ws4_files=$(git status --porcelain | grep -c -E "(lib/mix/tasks/|lib/eve_dmv/contexts/surveillance/)" || echo "0")
ws5_files=$(git status --porcelain | grep -c -E "(scripts/|\.pre-commit|config/)" || echo "0")

echo "• WS-1 Pipeline files: $ws1_files"
echo "• WS-2 Function complexity files: $ws2_files"  
echo "• WS-3 Module organization files: $ws3_files"
echo "• WS-4 Design/TODO files: $ws4_files"
echo "• WS-5 Build/automation files: $ws5_files"

# Warn if multiple workstreams are active
active_workstreams=0
if [ "$ws1_files" -gt 0 ]; then ((active_workstreams++)); fi
if [ "$ws2_files" -gt 0 ]; then ((active_workstreams++)); fi
if [ "$ws3_files" -gt 0 ]; then ((active_workstreams++)); fi
if [ "$ws4_files" -gt 0 ]; then ((active_workstreams++)); fi
if [ "$ws5_files" -gt 0 ]; then ((active_workstreams++)); fi

if [ "$active_workstreams" -gt 1 ]; then
    echo "⚠️  Multiple workstreams active - coordinate to avoid conflicts"
    conflict_found=true
fi

echo ""
if [ "$conflict_found" = true ]; then
    echo "🔄 Workstream coordination recommended"
    echo "   → Check with team before proceeding"
    echo "   → Consider smaller, focused commits"
    echo "   → Update workstream status if needed"
    exit 0  # Warning only, don't block commits
else
    echo "✅ No workstream conflicts detected"
    exit 0
fi