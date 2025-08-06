#!/bin/bash
CHANGE_DESCRIPTION="$1"

echo "🛡️ MICRO-CHANGE WORKFLOW: $CHANGE_DESCRIPTION"
echo "RULE: Maximum 3-5 functions per change"

# Pre-change checkpoint
git add -A && git commit -m "CHECKPOINT: Before $CHANGE_DESCRIPTION"

# Remind about validation requirement
echo "MANDATORY: Run ./scripts/validation_gate.sh after change"
echo "MANDATORY: Commit immediately after validation passes"
echo "MANDATORY: Rollback immediately if validation fails"