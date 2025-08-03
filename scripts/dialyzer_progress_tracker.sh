#!/bin/bash
# Dialyzer Progress Tracking Script
# Monitors daily progress for each team

set -e

echo "=== Dialyzer Cleanup Progress Tracker ==="
echo "Date: $(date)"
echo ""

# Get current error counts
CURRENT_ERRORS=$(mix dialyzer --format short 2>/dev/null | grep -E "lib/eve_dmv.*:" | wc -l || echo "0")
echo "Current Total Errors: $CURRENT_ERRORS"

# Track by error type
echo ""
echo "=== Error Distribution by Type ==="
if [ -f "/workspace/dialyzer.txt" ]; then
    echo "unknown_function: $(grep -E "lib/eve_dmv.*:unknown_function" /workspace/dialyzer.txt | wc -l)"
    echo "unused_fun: $(grep -E "lib/eve_dmv.*:unused_fun" /workspace/dialyzer.txt | wc -l)"
    echo "pattern_match: $(grep -E "lib/eve_dmv.*:pattern_match" /workspace/dialyzer.txt | wc -l)"
    echo "no_return: $(grep -E "lib/eve_dmv.*:no_return" /workspace/dialyzer.txt | wc -l)"
    echo "callback_info_missing: $(grep -E "lib/eve_dmv.*:callback_info_missing" /workspace/dialyzer.txt | wc -l)"
    echo "contract_supertype: $(grep -E "lib/eve_dmv.*:contract_supertype" /workspace/dialyzer.txt | wc -l)"
    echo "invalid_contract: $(grep -E "lib/eve_dmv.*:invalid_contract" /workspace/dialyzer.txt | wc -l)"
else
    echo "No dialyzer.txt found - run 'mix dialyzer --format short > dialyzer.txt' first"
fi

echo ""
echo "=== Team Progress Targets ==="
BASELINE=7776
WEEK1_TARGET=$((BASELINE * 40 / 100))  # 60% reduction target
WEEK2_TARGET=200                        # Final target

WEEK1_REDUCTION=$((BASELINE - WEEK1_TARGET))
CURRENT_REDUCTION=$((BASELINE - CURRENT_ERRORS))

echo "Baseline Errors: $BASELINE"
echo "Week 1 Target: $WEEK1_TARGET (reduce by $WEEK1_REDUCTION)"
echo "Week 2 Target: $WEEK2_TARGET"
echo ""
echo "Current Progress: $CURRENT_REDUCTION errors fixed ($(( CURRENT_REDUCTION * 100 / BASELINE ))% reduction)"

if [ $CURRENT_ERRORS -le $WEEK1_TARGET ]; then
    echo "✅ Week 1 target achieved!"
elif [ $CURRENT_ERRORS -le $WEEK2_TARGET ]; then
    echo "🎯 Final target achieved!"
else
    REMAINING_TO_WEEK1=$((CURRENT_ERRORS - WEEK1_TARGET))
    echo "⏳ $REMAINING_TO_WEEK1 errors remaining to reach Week 1 target"
fi

echo ""
echo "=== Team Velocity Tracking ==="

# Calculate daily velocity if we have historical data
PROGRESS_LOG="/workspace/docs/dialyzer_progress.log"
if [ -f "$PROGRESS_LOG" ]; then
    echo "Reading progress history..."
    tail -5 "$PROGRESS_LOG"
else
    echo "No progress history found. Starting tracking..."
    echo "$(date +%Y-%m-%d),$CURRENT_ERRORS" > "$PROGRESS_LOG"
fi

# Add today's data
echo "$(date +%Y-%m-%d),$CURRENT_ERRORS" >> "$PROGRESS_LOG"

# Show velocity if we have more than one data point
if [ -f "$PROGRESS_LOG" ] && [ $(wc -l < "$PROGRESS_LOG") -gt 1 ]; then
    YESTERDAY_ERRORS=$(tail -2 "$PROGRESS_LOG" | head -1 | cut -d, -f2)
    DAILY_REDUCTION=$((YESTERDAY_ERRORS - CURRENT_ERRORS))
    if [ $DAILY_REDUCTION -gt 0 ]; then
        echo "Daily reduction: $DAILY_REDUCTION errors"
        DAYS_TO_TARGET=$(( (CURRENT_ERRORS - WEEK1_TARGET) / DAILY_REDUCTION ))
        if [ $DAYS_TO_TARGET -gt 0 ]; then
            echo "Estimated days to Week 1 target: $DAYS_TO_TARGET"
        fi
    elif [ $DAILY_REDUCTION -lt 0 ]; then
        echo "⚠️  Errors increased by $((-DAILY_REDUCTION)) since yesterday"
    else
        echo "No change since yesterday"
    fi
fi

echo ""
echo "=== Quick Commands ==="
echo "Update dialyzer output: mix dialyzer --format short > dialyzer.txt"
echo "Generate team assignments: ./scripts/dialyzer_team_assignments.sh"
echo "Check compilation: mix compile --warnings-as-errors"
echo "Run tests: mix test --cover"