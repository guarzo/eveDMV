#!/bin/bash
# Remove specific unused functions from battle_sharing_service.ex

FILE="/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_sharing_service.ex"

echo "Removing unused functions from battle_sharing_service.ex..."

# Create backup
cp "$FILE" "/tmp/battle_sharing_service.ex.backup"

# Remove specific unused functions identified by dialyzer
python3 << 'EOF'
import re

# Read the file
with open("/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_sharing_service.ex", 'r') as f:
    content = f.read()

# List of functions to remove (from dialyzer output)
functions_to_remove = [
    "build_battle_title",
    "format_key_stats", 
    "format_stat_value",
    "get_participant_breakdown",
    "analyze_battle_participants",
    "extract_battle_participants",
    "group_participants_by_affiliation",
    "format_isk_value",
    "format_duration"
]

def remove_function(content, func_name):
    """Remove a function and its documentation from content."""
    # Pattern to find the function
    pattern = rf'((?:@doc\s+"""[\s\S]*?"""\s*)?(?:@spec\s+.*\n)?)\s*defp?\s+{re.escape(func_name)}\s*\([^{{]*\{{'
    
    # Split into lines for easier processing
    lines = content.split('\n')
    result_lines = []
    i = 0
    
    while i < len(lines):
        # Check if this line starts our target function
        if re.match(rf'^\s*defp?\s+{re.escape(func_name)}\s*\(', lines[i]):
            # Found the function, now find where it ends
            start_i = i
            
            # First check if there are @doc or @spec lines above
            j = i - 1
            while j >= 0 and (lines[j].strip().startswith('@') or lines[j].strip() == '' or lines[j].strip().startswith('#')):
                j -= 1
            start_i = j + 1
            
            # Find the base indentation
            base_indent = len(lines[i]) - len(lines[i].lstrip())
            
            # Skip to end of function
            i += 1
            brace_count = 0
            in_string = False
            
            while i < len(lines):
                line = lines[i]
                
                # Track if we're in a string
                for char in line:
                    if char == '"' and not in_string:
                        in_string = True
                    elif char == '"' and in_string:
                        in_string = False
                
                if not in_string:
                    # Count braces
                    brace_count += line.count('{') - line.count('}')
                
                # Check if we've returned to base level
                if line.strip() and not in_string:
                    current_indent = len(line) - len(line.lstrip())
                    if current_indent <= base_indent and line.strip() == "end":
                        # This is the end of our function
                        i += 1
                        break
                    elif current_indent < base_indent and line.strip():
                        # We've gone past the function
                        break
                
                i += 1
            
            # Remove everything from start_i to current i
            print(f"Removing function {func_name} (lines {start_i+1} to {i})")
            
            # Skip adding these lines to result
            continue
        else:
            result_lines.append(lines[i])
            i += 1
    
    return '\n'.join(result_lines)

# Remove each function
for func in functions_to_remove:
    print(f"Processing {func}...")
    content = remove_function(content, func)

# Clean up multiple blank lines
lines = content.split('\n')
cleaned = []
prev_blank = False

for line in lines:
    if line.strip() == '':
        if not prev_blank:
            cleaned.append(line)
        prev_blank = True
    else:
        cleaned.append(line)
        prev_blank = False

# Write back
with open("/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_sharing_service.ex", 'w') as f:
    f.write('\n'.join(cleaned))

print("Done!")
EOF

echo "Unused functions removed from battle_sharing_service.ex"