#!/bin/bash
# Mark intentionally unused public functions with @compile directive

echo "=== Marking Intentionally Unused Public Functions ==="

# Public functions that appear to be intentionally unused (utility/API functions)
declare -A intentional_unused=(
    ["lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex"]="generate_highlight_id"
    ["lib/eve_dmv/contexts/combat/services/doctrine_effectiveness_service.ex"]="get_default_threat_doctrines"
    ["lib/eve_dmv/contexts/corporation/core/threat_detector.ex"]="generate_alert_id"
    ["lib/eve_dmv/contexts/threat_surveillance/domain/behavioral_pattern_analyzer.ex"]="get_last_analysis_time"
    ["lib/eve_dmv/core/domain/intelligence/core/intelligence_coordinator.ex"]="warm_analysis_cache warm_threat_cache"
    ["lib/eve_dmv/core/infrastructure/unified_event_processor.ex"]="register_default_handlers"
    ["lib/eve_dmv/utilities/analyzers/ship_stats_engine.ex"]="calculate_time_metrics update_ship_rankings"
)

# Also mark the warning functions from tactical_highlight_manager
warning_functions=(
    "capital_ship?"
    "extract_participants_from_killmail"
    "extract_tags_from_note"
    "intensity_change_moment?"
    "phase_transition_moment?"
    "tactical_term?"
)

# Add @compile directive to files
for file in "${!intentional_unused[@]}"; do
    if [ -f "$file" ]; then
        echo "Processing $file..."
        
        # Check if @compile directive already exists
        if grep -q "@compile {:nowarn_unused_function" "$file"; then
            echo "  @compile directive already exists, updating..."
            # Update existing directive
            functions="${intentional_unused[$file]}"
            func_list=$(echo $functions | sed 's/ /, :/g' | sed 's/^/[:/' | sed 's/$/, \\\]/')
            
            # Remove old directive and add new one
            sed -i '/@compile {:nowarn_unused_function/d' "$file"
        else
            functions="${intentional_unused[$file]}"
            func_list=$(echo $functions | sed 's/ /, :/g' | sed 's/^/[:/' | sed 's/$/]/')
        fi
        
        # Add directive after module declaration
        python3 << EOF
import re

with open("$file", 'r') as f:
    lines = f.readlines()

# Find the module declaration
module_found = False
insert_pos = -1
for i, line in enumerate(lines):
    if re.match(r'^defmodule\s+', line):
        module_found = True
        # Look for the first non-comment, non-empty line after module
        for j in range(i+1, len(lines)):
            if lines[j].strip() and not lines[j].strip().startswith('@') and not lines[j].strip().startswith('#'):
                insert_pos = j
                break
        break

if insert_pos > 0:
    # Build the @compile directive
    functions = "$functions".split()
    func_atoms = ", ".join(f":{func}" for func in functions)
    directive = f"  @compile {{:nowarn_unused_function, [{func_atoms}]}}\n\n"
    
    lines.insert(insert_pos, directive)
    
    with open("$file", 'w') as f:
        f.writelines(lines)
    
    print(f"Added @compile directive for: {functions}")
else:
    print("Could not find suitable insertion point")
EOF
    fi
done

# Handle the tactical_highlight_manager warnings separately
file="lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex"
if [ -f "$file" ]; then
    echo -e "\nProcessing warnings in $file..."
    
    # Add directive for warning functions
    python3 << EOF
import re

with open("$file", 'r') as f:
    lines = f.readlines()

# Check if we already have a @compile directive
has_compile = any("@compile {:nowarn_unused_function" in line for line in lines)

if not has_compile:
    # Find module declaration
    for i, line in enumerate(lines):
        if re.match(r'^defmodule\s+', line):
            # Insert after module line
            for j in range(i+1, len(lines)):
                if lines[j].strip() and not lines[j].strip().startswith('@'):
                    warning_funcs = ${warning_functions[@]}
                    func_list = ", ".join(f":{func}" for func in ["capital_ship?", "extract_participants_from_killmail", 
                                         "extract_tags_from_note", "intensity_change_moment?", 
                                         "phase_transition_moment?", "tactical_term?", "generate_highlight_id"])
                    directive = f"  @compile {{:nowarn_unused_function, [{func_list}]}}\n\n"
                    lines.insert(j, directive)
                    break
            break
    
    with open("$file", 'w') as f:
        f.writelines(lines)
    
    print("Added @compile directive for warning functions")
else:
    print("@compile directive already exists")
EOF
fi

echo -e "\n=== Testing Compilation ==="
cd /workspace && mix compile --force 2>&1 | grep -c "warning:"