#!/bin/bash
# Remove unused functions from historical_trend_analysis.ex

FILE="/workspace/lib/eve_dmv/contexts/intelligence/core/historical_trend_analysis.ex"
BACKUP="/tmp/historical_trend_analysis.ex.backup"

echo "Backing up file..."
cp "$FILE" "$BACKUP"

# List of unused functions from dialyzer
UNUSED_FUNCTIONS=(
  "analyze_kd_trend/1"
  "analyze_isk_trend/1"
  "analyze_ship_usage_trend/1"
  "analyze_activity_trend/1"
  "analyze_threat_score_trend/2"
  "week_key/1"
  "calculate_direction/1"
  "calculate_velocity/1"
  "calculate_volatility/1"
  "calculate_improvement_rate/1"
  "build_trend_line/1"
  "analyze_ship_progression/1"
  "calculate_ship_diversity/1"
  "detect_ship_specialization/1"
  "detect_recent_ship_changes/1"
  "find_peak_hours/1"
  "find_peak_days/1"
  "estimate_timezone/1"
  "calculate_activity_consistency/1"
  "categorize_activity_level/1"
  "calculate_performance_trends/1"
  "calculate_solo_ratio/1"
  "calculate_gang_effectiveness/1"
  "analyze_target_selection/1"
  "calculate_engagement_success/1"
  "determine_overall_direction/1"
  "calculate_change_rate/1"
  "project_future_score/2"
  "calculate_momentum/1"
  "calculate_trend_confidence/1"
  "calculate_score_momentum/2"
  "calculate_percentile_rank/1"
  "analyze_threat_evolution/2"
  "calculate_threat_score_for_period/2"
  "classify_threat_level/1"
  "determine_threat_trend_direction/1"
  "identify_evolution_pattern/1"
  "steadily_increasing?/1"
  "steadily_decreasing?/1"
  "has_spike_pattern?/1"
  "average/1"
)

echo "Processing file to remove unused functions..."

# Create a Python script to handle the removal
cat > /tmp/remove_unused.py << 'EOF'
import sys
import re

def remove_function(content, func_name, arity):
    """Remove a function definition from the content."""
    # Pattern to match function definition
    func_pattern = rf'^\s*defp?\s+{re.escape(func_name)}\s*\('
    
    lines = content.split('\n')
    new_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this line starts the function
        if re.match(func_pattern, line):
            # Skip any @doc or @spec lines above
            while new_lines and (new_lines[-1].strip().startswith('@') or new_lines[-1].strip() == ''):
                new_lines.pop()
            
            # Find the end of the function
            indent = len(line) - len(line.lstrip())
            i += 1
            
            # Skip until we find a line with same or less indentation
            while i < len(lines):
                current_line = lines[i]
                if current_line.strip() == '':
                    i += 1
                    continue
                    
                current_indent = len(current_line) - len(current_line.lstrip())
                
                # Check if we've reached the end
                if current_indent <= indent and current_line.strip() != '':
                    # If it's an 'end' at the same level, skip it
                    if current_line.strip() == 'end' and current_indent == indent:
                        i += 1
                    break
                    
                i += 1
            
            # Continue from here
            continue
            
        new_lines.append(line)
        i += 1
    
    # Clean up multiple blank lines
    result = []
    prev_blank = False
    for line in new_lines:
        if line.strip() == '':
            if not prev_blank:
                result.append(line)
            prev_blank = True
        else:
            result.append(line)
            prev_blank = False
    
    return '\n'.join(result)

# Read the file
with open(sys.argv[1], 'r') as f:
    content = f.read()

# Remove each unused function
unused_functions = sys.argv[2:]
for func_spec in unused_functions:
    if '/' in func_spec:
        func_name, arity = func_spec.split('/')
        print(f"Removing {func_name}/{arity}")
        content = remove_function(content, func_name, arity)

# Write back
with open(sys.argv[1], 'w') as f:
    f.write(content)
EOF

# Run the Python script with all unused functions
python3 /tmp/remove_unused.py "$FILE" "${UNUSED_FUNCTIONS[@]}"

echo "Done! Removed ${#UNUSED_FUNCTIONS[@]} unused functions from $FILE"
echo "Backup saved at: $BACKUP"