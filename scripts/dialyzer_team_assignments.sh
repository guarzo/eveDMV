#!/bin/bash
# Dialyzer Team Assignment Script
# Generates specific error lists for each team to work on

set -e

DIALYZER_OUTPUT="/workspace/dialyzer.txt"
TEAM_DIR="/workspace/docs/team_assignments"

# Create team assignments directory
mkdir -p "$TEAM_DIR"

echo "=== Generating Team Assignments from Dialyzer Output ==="

# Team Alpha: unknown_function errors
echo "Team Alpha - Infrastructure (unknown_function errors):"
grep -E "lib/eve_dmv.*:unknown_function" "$DIALYZER_OUTPUT" > "$TEAM_DIR/team_alpha_unknown_functions.txt"
ALPHA_COUNT=$(wc -l < "$TEAM_DIR/team_alpha_unknown_functions.txt")
echo "  - $ALPHA_COUNT unknown_function errors assigned"

# Break down by developer
echo "  Developer 1 - UI Components:"
grep -E "(components/|live/)" "$TEAM_DIR/team_alpha_unknown_functions.txt" > "$TEAM_DIR/team_alpha_dev1_ui.txt"
UI_COUNT=$(wc -l < "$TEAM_DIR/team_alpha_dev1_ui.txt")
echo "    - $UI_COUNT errors in UI components and LiveViews"

echo "  Developer 2 - Database Layer:"
grep -E "(platform/database/|repo\.ex)" "$TEAM_DIR/team_alpha_unknown_functions.txt" > "$TEAM_DIR/team_alpha_dev2_database.txt"
DB_COUNT=$(wc -l < "$TEAM_DIR/team_alpha_dev2_database.txt")
echo "    - $DB_COUNT errors in database layer"

echo "  Developer 3 - Core Infrastructure:"
grep -E "(endpoint\.ex|platform/utilities/|platform/monitoring/)" "$TEAM_DIR/team_alpha_unknown_functions.txt" > "$TEAM_DIR/team_alpha_dev3_infra.txt"
INFRA_COUNT=$(wc -l < "$TEAM_DIR/team_alpha_dev3_infra.txt")
echo "    - $INFRA_COUNT errors in core infrastructure"

# Team Bravo: unused_fun errors
echo ""
echo "Team Bravo - Dead Code Removal (unused_fun errors):"
grep -E "lib/eve_dmv.*:unused_fun" "$DIALYZER_OUTPUT" > "$TEAM_DIR/team_bravo_unused_functions.txt"
BRAVO_COUNT=$(wc -l < "$TEAM_DIR/team_bravo_unused_functions.txt")
echo "  - $BRAVO_COUNT unused_fun errors assigned"

echo "  Developer 1 - Intelligence & Analytics:"
grep -E "contexts/(intelligence|analytics)" "$TEAM_DIR/team_bravo_unused_functions.txt" > "$TEAM_DIR/team_bravo_dev1_intelligence.txt"
INTEL_COUNT=$(wc -l < "$TEAM_DIR/team_bravo_dev1_intelligence.txt")
echo "    - $INTEL_COUNT errors in intelligence modules"

echo "  Developer 2 - Corporation & Battle:"
grep -E "contexts/(corporation|battle)" "$TEAM_DIR/team_bravo_unused_functions.txt" > "$TEAM_DIR/team_bravo_dev2_corp_battle.txt"
CORP_COUNT=$(wc -l < "$TEAM_DIR/team_bravo_dev2_corp_battle.txt")
echo "    - $CORP_COUNT errors in corporation/battle modules"

# Team Charlie: pattern_match and no_return errors
echo ""
echo "Team Charlie - Business Logic (pattern_match + no_return errors):"
grep -E "lib/eve_dmv.*:(pattern_match|no_return)" "$DIALYZER_OUTPUT" > "$TEAM_DIR/team_charlie_patterns.txt"
CHARLIE_COUNT=$(wc -l < "$TEAM_DIR/team_charlie_patterns.txt")
echo "  - $CHARLIE_COUNT pattern_match/no_return errors assigned"

echo "  Developer 1 - Intelligence Engine:"
grep -E "contexts/intelligence" "$TEAM_DIR/team_charlie_patterns.txt" > "$TEAM_DIR/team_charlie_dev1_intelligence.txt"
INTEL_PAT_COUNT=$(wc -l < "$TEAM_DIR/team_charlie_dev1_intelligence.txt")
echo "    - $INTEL_PAT_COUNT errors in intelligence engine"

echo "  Developer 2 - Battle Analysis:"
grep -E "contexts/battle_analysis" "$TEAM_DIR/team_charlie_patterns.txt" > "$TEAM_DIR/team_charlie_dev2_battle.txt"
BATTLE_PAT_COUNT=$(wc -l < "$TEAM_DIR/team_charlie_dev2_battle.txt")
echo "    - $BATTLE_PAT_COUNT errors in battle analysis"

echo "  Developer 3 - Wormhole Operations:"
grep -E "contexts/wormhole_operations" "$TEAM_DIR/team_charlie_patterns.txt" > "$TEAM_DIR/team_charlie_dev3_wormhole.txt"
WH_PAT_COUNT=$(wc -l < "$TEAM_DIR/team_charlie_dev3_wormhole.txt")
echo "    - $WH_PAT_COUNT errors in wormhole operations"

# Team Delta: callback and contract errors
echo ""
echo "Team Delta - Integration Layer (callback + contract errors):"
grep -E "lib/eve_dmv.*:(callback_info_missing|contract_supertype|invalid_contract|unknown_type)" "$DIALYZER_OUTPUT" > "$TEAM_DIR/team_delta_contracts.txt"
DELTA_COUNT=$(wc -l < "$TEAM_DIR/team_delta_contracts.txt")
echo "  - $DELTA_COUNT callback/contract errors assigned"

echo "  Developer 1 - Behavior Implementations:"
grep -E "callback_info_missing" "$TEAM_DIR/team_delta_contracts.txt" > "$TEAM_DIR/team_delta_dev1_callbacks.txt"
CALLBACK_COUNT=$(wc -l < "$TEAM_DIR/team_delta_dev1_callbacks.txt")
echo "    - $CALLBACK_COUNT callback implementation errors"

echo "  Developer 2 - Contract Specifications:"
grep -E "(contract_supertype|invalid_contract|unknown_type)" "$TEAM_DIR/team_delta_contracts.txt" > "$TEAM_DIR/team_delta_dev2_contracts.txt"
CONTRACT_COUNT=$(wc -l < "$TEAM_DIR/team_delta_dev2_contracts.txt")
echo "    - $CONTRACT_COUNT contract/type specification errors"

# Generate summary
echo ""
echo "=== Team Assignment Summary ==="
echo "Team Alpha (Infrastructure): $ALPHA_COUNT errors"
echo "Team Bravo (Dead Code): $BRAVO_COUNT errors"
echo "Team Charlie (Business Logic): $CHARLIE_COUNT errors"
echo "Team Delta (Integration): $DELTA_COUNT errors"
TOTAL_ASSIGNED=$((ALPHA_COUNT + BRAVO_COUNT + CHARLIE_COUNT + DELTA_COUNT))
echo "Total Assigned: $TOTAL_ASSIGNED errors"

# Get total from dialyzer output
TOTAL_ERRORS=$(grep -E "lib/eve_dmv.*:" "$DIALYZER_OUTPUT" | wc -l)
echo "Total Errors: $TOTAL_ERRORS"
UNASSIGNED=$((TOTAL_ERRORS - TOTAL_ASSIGNED))
echo "Remaining Unassigned: $UNASSIGNED errors"

if [ $UNASSIGNED -gt 0 ]; then
    echo ""
    echo "=== Unassigned Errors (for Team Echo coordination) ==="
    grep -E "lib/eve_dmv.*:" "$DIALYZER_OUTPUT" > "$TEAM_DIR/all_errors.tmp"
    cat "$TEAM_DIR"/team_*_*.txt | sort | uniq > "$TEAM_DIR/assigned_errors.tmp"
    comm -23 "$TEAM_DIR/all_errors.tmp" "$TEAM_DIR/assigned_errors.tmp" > "$TEAM_DIR/team_echo_unassigned.txt"
    echo "Unassigned errors saved to: $TEAM_DIR/team_echo_unassigned.txt"
    rm "$TEAM_DIR"/*.tmp
fi

echo ""
echo "All team assignments saved to: $TEAM_DIR/"
echo "Ready for parallel implementation!"