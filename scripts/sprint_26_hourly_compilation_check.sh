#!/bin/bash

# Sprint 26 Hourly Compilation Check (Days 1-3 Emergency Phase)
# CRITICAL: Track compilation warning reduction during emergency recovery

echo "SPRINT 26 HOURLY COMPILATION STATUS"
echo "==================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Get current compilation warning count
echo "Checking compilation status..."
warnings=$(mix compile 2>&1 | grep "warning:" | wc -l)

# Sprint 26 baseline and targets
baseline_warnings=42
target_warnings=0
day_1_target=28  # 42 - 14
day_2_target=14  # 28 - 14  
day_3_target=0   # 14 - 14

echo "COMPILATION WARNING STATUS:"
echo "=========================="
echo "Current warnings: $warnings"
echo "Baseline (Sprint 26 start): $baseline_warnings"
echo "Target: $target_warnings"
echo ""

# Progress calculation
warnings_fixed=$((baseline_warnings - warnings))
progress_percent=$((warnings_fixed * 100 / baseline_warnings))

echo "PROGRESS TRACKING:"
echo "=================="
echo "Warnings fixed: $warnings_fixed / $baseline_warnings"
echo "Progress: $progress_percent%"
echo ""

# Daily targets (manual update needed)
current_day=1  # Update this manually: 1, 2, or 3
echo "DAILY TARGET TRACKING:"
echo "====================="
echo "Current day: $current_day"

case $current_day in
    1)
        target_today=$day_1_target
        echo "End of Day 1 target: $target_today warnings remaining"
        ;;
    2)
        target_today=$day_2_target
        echo "End of Day 2 target: $target_today warnings remaining"
        ;;
    3)
        target_today=$day_3_target
        echo "End of Day 3 target: $target_today warnings remaining"
        ;;
esac

echo ""

# Status assessment
if [ "$warnings" -eq 0 ]; then
    echo "🎉 COMPILATION EMERGENCY RESOLVED!"
    echo "✅ Ready to move to systematic Credo reduction phase"
    echo "✅ Production deployment no longer blocked by compilation"
elif [ "$warnings" -le "$target_today" ]; then
    echo "✅ ON TRACK for Day $current_day target"
    echo "🔄 Continue systematic warning reduction"
else
    echo "⚠️  BEHIND TARGET for Day $current_day"
    echo "❌ Need to accelerate warning fixes"
    echo "🚨 Consider additional resources for Workstream A"
fi

echo ""
echo "NEXT STEPS:"
echo "=========="
if [ "$warnings" -eq 0 ]; then
    echo "- Emergency phase complete"
    echo "- Begin systematic Credo issue reduction"
    echo "- All workstreams can proceed with normal Sprint 26 work"
else
    echo "- Continue fixing compilation warnings one by one"
    echo "- Validate each fix with: mix compile --warnings-as-errors"
    echo "- Report progress hourly during emergency phase"
    echo "- Other workstreams support compilation fixes"
fi

echo ""
echo "VALIDATION COMMANDS:"
echo "==================="
echo "mix compile --warnings-as-errors  # Must succeed when warnings = 0"
echo "mix test --max-failures=1         # Must succeed after each fix"

# Test status check
echo ""
echo "CURRENT TEST STATUS:"
echo "==================="
if mix test --max-failures=1 >/dev/null 2>&1; then
    echo "✅ Tests: PASSING"
else
    echo "❌ Tests: FAILING (may be due to compilation warnings)"
fi

echo ""
echo "Remember: Fix ONE warning at a time, validate immediately!"