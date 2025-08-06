#!/bin/bash
# track_progress.sh - Track progress toward zero Dialyzer errors
# Part of DIALYZER_ZERO_ERROR_PLAN_FINAL.md Phase 0

INITIAL=231  # Current baseline after config change
CURRENT=$(grep -c "^lib/" dialyzer_current.txt || echo "0")
FIXED=$((INITIAL - CURRENT))
PERCENT=0

if [ $INITIAL -gt 0 ]; then
    PERCENT=$((FIXED * 100 / INITIAL))
fi

echo "=== Dialyzer Zero Error Progress ==="
echo "📊 Progress: $FIXED/$INITIAL fixed ($PERCENT%)"
echo "🎯 Remaining: $CURRENT errors"
echo "⏰ Target: 0 errors"

if [ $CURRENT -le 50 ]; then
    echo "🎉 Excellent! Within final sprint range!"
elif [ $CURRENT -le 100 ]; then
    echo "✨ Great progress! Approaching final phase!"
elif [ $CURRENT -le 150 ]; then
    echo "👍 Good progress! On track for Week 2 target!"
else
    echo "📈 Making progress! Continue with Week 1 focus!"
fi

echo ""
echo "=== Week Targets ==="
echo "Week 1 Target: 150 errors remaining"
echo "Week 2 Target: 50 errors remaining"
echo "Week 3 Target: 0 errors remaining"
echo ""

# Calculate days remaining based on progress
if [ $CURRENT -gt 150 ]; then
    echo "⏳ Focus: Week 1 - High-impact files"
elif [ $CURRENT -gt 50 ]; then
    echo "⏳ Focus: Week 2 - Pattern match systematic fixes"
else
    echo "⏳ Focus: Week 3 - Final cleanup & validation"
fi

echo ""
echo "Last updated: $(date)"