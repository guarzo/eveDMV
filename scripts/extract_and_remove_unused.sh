#!/bin/bash
# Extract and remove unused functions from dialyzer output

echo "🧹 Extracting and removing unused functions..."

# Create backup directory
BACKUP_DIR="/tmp/unused_functions_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Extract unused functions with their details
echo "Parsing dialyzer output..."
python3 << 'EOF' > /tmp/unused_functions_detailed.txt
import re

with open('/workspace/dialyzer.txt', 'r') as f:
    lines = f.readlines()

i = 0
while i < len(lines):
    line = lines[i].strip()
    if 'unused_fun' in line and i + 1 < len(lines):
        file_info = line.split(':')
        if len(file_info) >= 3:
            file_path = file_info[0]
            line_num = file_info[1]
            next_line = lines[i + 1].strip()
            
            # Extract function name and arity
            match = re.search(r'Function (\w+)/(\d+) will never be called', next_line)
            if match:
                func_name = match.group(1)
                arity = match.group(2)
                print(f"{file_path}|{line_num}|{func_name}|{arity}")
        i += 2
    else:
        i += 1
EOF

# Count functions to remove
total_functions=$(wc -l < /tmp/unused_functions_detailed.txt)
echo "Found $total_functions unused functions to remove"

# Process each file
cut -d'|' -f1 /tmp/unused_functions_detailed.txt | sort -u | while read -r file; do
    if [ ! -f "$file" ]; then
        echo "Skipping non-existent file: $file"
        continue
    fi
    
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "$BACKUP_DIR/$(basename "$file")"
    
    # Get all unused functions for this file
    grep "^$file|" /tmp/unused_functions_detailed.txt | cut -d'|' -f3,4 | tr '|' '/' > /tmp/current_file_unused.txt
    
    # Count functions in this file
    file_func_count=$(wc -l < /tmp/current_file_unused.txt)
    echo "  Found $file_func_count unused functions"
    
    # Create Python script to remove functions
    python3 << 'PYTHON' "$file" /tmp/current_file_unused.txt
import sys
import re

def find_function_end(lines, start_idx, base_indent):
    """Find the end of a function definition."""
    i = start_idx + 1
    while i < len(lines):
        line = lines[i]
        if line.strip() == "":
            i += 1
            continue
        
        current_indent = len(line) - len(line.lstrip())
        
        # If we find a line with same or less indentation (and it's not empty), we've reached the end
        if current_indent <= base_indent and line.strip() != "":
            # Check if it's a new function definition at the same level
            if re.match(r'\s*defp?\s+\w+\s*\(', line):
                return i - 1
            # Check if it's an 'end' at the same level
            elif line.strip() == "end" and current_indent == base_indent:
                return i
            else:
                return i - 1
        i += 1
    
    return len(lines) - 1

def remove_unused_functions(file_path, unused_functions):
    # Read unused functions into a set
    unused_set = set()
    with open(unused_functions, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                unused_set.add(line)
    
    print(f"  Functions to remove: {unused_set}")
    
    # Read file content
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    # Track which lines to keep
    keep_lines = [True] * len(lines)
    removed_count = 0
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Check for function definition
        match = re.match(r'(\s*)defp?\s+(\w+)\s*\((.*)', line)
        if match:
            indent = match.group(1)
            func_name = match.group(2)
            params_start = match.group(3)
            
            # Find the full function signature (might span multiple lines)
            full_sig = line
            j = i
            paren_count = 1 + params_start.count('(') - params_start.count(')')
            
            while paren_count > 0 and j + 1 < len(lines):
                j += 1
                full_sig += lines[j]
                paren_count += lines[j].count('(') - lines[j].count(')')
            
            # Try to determine arity
            # Extract the parameters part
            params_match = re.search(r'\((.*?)\)\s*(do|when|,|\z)', full_sig, re.DOTALL)
            if params_match:
                params = params_match.group(1).strip()
                if params == "":
                    arity = 0
                else:
                    # Simple arity counting - count commas at depth 0
                    arity = 1
                    depth = 0
                    for char in params:
                        if char in '([{':
                            depth += 1
                        elif char in ')]}':
                            depth -= 1
                        elif char == ',' and depth == 0:
                            arity += 1
            else:
                arity = 0  # Default
            
            func_key = f"{func_name}/{arity}"
            
            if func_key in unused_set:
                print(f"  Removing function: {func_key} at line {i+1}")
                removed_count += 1
                
                # Find the end of the function
                base_indent = len(indent)
                end_idx = find_function_end(lines, j, base_indent)
                
                # Mark lines for removal
                for k in range(i, end_idx + 1):
                    keep_lines[k] = False
                
                # Also remove any @doc, @spec, or comment lines above
                k = i - 1
                while k >= 0:
                    prev_line = lines[k].strip()
                    if (prev_line.startswith('@doc') or 
                        prev_line.startswith('@spec') or 
                        prev_line.startswith('#') or
                        prev_line == ""):
                        keep_lines[k] = False
                        k -= 1
                    else:
                        break
                
                i = end_idx
        
        i += 1
    
    # Write back only kept lines
    result_lines = [lines[i] for i in range(len(lines)) if keep_lines[i]]
    
    # Clean up multiple blank lines
    cleaned_lines = []
    prev_blank = False
    for line in result_lines:
        if line.strip() == "":
            if not prev_blank:
                cleaned_lines.append(line)
            prev_blank = True
        else:
            cleaned_lines.append(line)
            prev_blank = False
    
    # Write the result
    with open(file_path, 'w') as f:
        f.writelines(cleaned_lines)
    
    print(f"  Removed {removed_count} functions")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: script.py <file_path> <unused_functions_file>")
        sys.exit(1)
    
    remove_unused_functions(sys.argv[1], sys.argv[2])
PYTHON
done

echo ""
echo "✅ Unused function removal complete!"
echo "Backup created at: $BACKUP_DIR"
echo ""
echo "Summary:"
echo "- Total unused functions found: $total_functions"
echo "- Files processed: $(cut -d'|' -f1 /tmp/unused_functions_detailed.txt | sort -u | wc -l)"
echo ""
echo "Next steps:"
echo "1. Run 'mix compile --warnings-as-errors' to verify compilation"
echo "2. Run 'mix test' to ensure tests pass"
echo "3. Run 'mix dialyzer' to verify improvements"