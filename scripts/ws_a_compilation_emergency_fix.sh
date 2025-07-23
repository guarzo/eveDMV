#!/bin/bash

# Workstream A: Compilation Emergency Fix Script
# CRITICAL: Fix 42 compilation warnings one by one with validation
# Sprint 26 Days 1-3 emergency phase

echo "WORKSTREAM A: COMPILATION EMERGENCY FIX"
echo "======================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Safety check - ensure we start with a clean working directory
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ ERROR: Working directory not clean. Commit or stash changes first."
    echo ""
    git status
    exit 1
fi

# Get initial warning count
echo "Checking initial compilation status..."
initial_warnings=$(mix compile 2>&1 | grep "warning:" | wc -l)
echo "Starting with: $initial_warnings compilation warnings"
echo ""

if [ "$initial_warnings" -eq 0 ]; then
    echo "✅ No compilation warnings found! Emergency phase already complete."
    exit 0
fi

echo "EMERGENCY PROTOCOL: Fix warnings ONE AT A TIME"
echo "=============================================="
echo ""

# List the most common warning patterns for targeting
echo "Common warning patterns to look for:"
echo "1. unused variables (prefix with _)"
echo "2. unused imports (remove or alias as _)"
echo "3. unreachable code (remove or fix logic)"
echo "4. deprecated function calls (update to new API)"
echo "5. pattern match issues (improve patterns)"
echo ""

echo "MANDATORY PROCESS for each warning fix:"
echo "======================================="
echo "1. Identify ONE specific warning"
echo "2. Edit ONLY the affected file"
echo "3. Make the SMALLEST possible change"  
echo "4. Validate immediately:"
echo "   mix compile --warnings-as-errors"
echo "   mix test --max-failures=1"
echo "5. Commit immediately if validation passes"
echo "6. Report progress hourly"
echo ""

# Create a log file for tracking progress
log_file="/workspace/ws_a_compilation_progress.log"
echo "Workstream A Compilation Progress Log" > "$log_file"
echo "Started: $(date)" >> "$log_file"
echo "Initial warnings: $initial_warnings" >> "$log_file"
echo "" >> "$log_file"

echo "Progress will be logged to: $log_file"
echo ""

# Show current warnings for targeting
echo "CURRENT COMPILATION WARNINGS:"
echo "============================="
mix compile 2>&1 | grep "warning:" | head -10
echo ""

if [ "$initial_warnings" -gt 10 ]; then
    echo "(Showing first 10 warnings - total: $initial_warnings)"
    echo ""
fi

echo "WORKSTREAM A DAILY TARGETS:"
echo "=========================="
echo "Day 1 target: Fix 14 warnings (42 → 28 remaining)"
echo "Day 2 target: Fix 14 warnings (28 → 14 remaining)" 
echo "Day 3 target: Fix 14 warnings (14 → 0 remaining)"
echo ""

echo "HOURLY PROGRESS TRACKING:"
echo "========================"
echo "Run this script hourly to:"
echo "1. Check current warning count"
echo "2. Log progress in $log_file"
echo "3. Assess if on track for daily targets"
echo ""

# Function to check and log progress
check_progress() {
    current_warnings=$(mix compile 2>&1 | grep "warning:" | wc -l)
    warnings_fixed=$((initial_warnings - current_warnings))
    
    echo "$(date): $current_warnings warnings remaining ($warnings_fixed fixed)" >> "$log_file"
    
    echo "CURRENT STATUS:"
    echo "==============="
    echo "Warnings remaining: $current_warnings"
    echo "Warnings fixed: $warnings_fixed"
    echo "Progress: $(($warnings_fixed * 100 / initial_warnings))%"
    
    if [ "$current_warnings" -eq 0 ]; then
        echo "" >> "$log_file"
        echo "COMPILATION EMERGENCY RESOLVED: $(date)" >> "$log_file"
        echo "" 
        echo "🎉 COMPILATION EMERGENCY RESOLVED!"
        echo "✅ All compilation warnings fixed"
        echo "✅ Ready to move to systematic Credo reduction"
        echo ""
        echo "Next phase: Begin fixing Software Design Credo issues"
        echo "Target: 28 Credo issues per day (500 issues ÷ 18 days)"
    fi
}

# Check current progress
check_progress

echo ""
echo "VALIDATION COMMANDS:"
echo "==================="
echo "# Before fixing any warning:"
echo "mix compile --warnings-as-errors  # Should fail with current warnings"
echo "mix test --max-failures=1         # Should pass"
echo ""
echo "# After fixing each warning:"
echo "mix compile --warnings-as-errors  # Should succeed"
echo "mix test --max-failures=1         # Should still pass"
echo "git add [modified_file]"
echo "git commit -m 'fix: resolve compilation warning in [file] - validate: compile+test OK'"
echo ""

echo "EMERGENCY CONTACT:"
echo "=================="
echo "If stuck on any warning:"
echo "1. Document the specific warning and attempted fixes"
echo "2. Request immediate support from senior team members"
echo "3. Do not attempt bulk fixes or risky changes"
echo "4. Compilation emergency blocks ALL other Sprint 26 work"
echo ""

echo "Remember: ONE warning at a time, validate immediately!"
echo "Track progress hourly during emergency phase."