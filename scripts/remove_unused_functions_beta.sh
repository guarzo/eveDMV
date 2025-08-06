#!/bin/bash
# Comprehensive script to remove unused functions identified by dialyzer

echo "🧹 Removing unused functions from the codebase..."

# Create a backup directory
BACKUP_DIR="/tmp/unused_functions_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Extract unused function information from dialyzer.txt
echo "Analyzing dialyzer output..."
grep "unused_fun" /workspace/dialyzer.txt | while IFS=: read -r file line type rest; do
    if [[ "$rest" =~ Function\ ([a-zA-Z_][a-zA-Z0-9_]*)/([0-9]+)\ will\ never\ be\ called ]]; then
        func_name="${BASH_REMATCH[1]}"
        arity="${BASH_REMATCH[2]}"
        echo "$file:$line:$func_name:$arity"
    fi
done | sort -u > /tmp/unused_functions_list.txt

# Process each file
echo "Processing files with unused functions..."
cut -d: -f1 /tmp/unused_functions_list.txt | sort -u | while read -r file; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "$BACKUP_DIR/$(basename "$file")"
    
    # Get all unused functions for this file
    grep "^$file:" /tmp/unused_functions_list.txt | cut -d: -f3,4 | sort -u > /tmp/current_file_unused.txt
    
    # Create a Python script to remove functions
    cat > /tmp/remove_functions.py << 'EOF'
import sys
import re

def remove_unused_functions(file_path, unused_functions):
    with open(file_path, 'r') as f:
        content = f.read()
    
    lines = content.split('\n')
    result_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        # Check if this line starts a function definition
        match = re.match(r'\s*defp?\s+([a-zA-Z_][a-zA-Z0-9_?!]*)\s*\(', line)
        if match:
            func_name = match.group(1)
            # Count the arity by parsing the function definition
            func_def_lines = [line]
            paren_count = line.count('(') - line.count(')')
            j = i + 1
            
            # Collect the full function definition
            while paren_count > 0 and j < len(lines):
                func_def_lines.append(lines[j])
                paren_count += lines[j].count('(') - lines[j].count(')')
                j += 1
            
            # Try to determine arity from the function definition
            full_def = ' '.join(func_def_lines)
            # Simple arity detection - count commas + 1, or 0 if empty parens
            if '()' in full_def or '( )' in full_def:
                arity = 0
            else:
                # Extract parameters
                param_match = re.search(r'\((.*?)\)', full_def, re.DOTALL)
                if param_match:
                    params = param_match.group(1).strip()
                    if params:
                        # Count top-level commas (not inside nested structures)
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
                        arity = 0
                else:
                    arity = -1  # Unknown
            
            # Check if this function is in our unused list
            func_key = f"{func_name}:{arity}"
            if func_key in unused_functions:
                print(f"  Removing {func_name}/{arity}")
                # Skip to the end of the function
                i = j - 1
                indent = len(line) - len(line.lstrip())
                
                # Find the end of the function
                while i < len(lines) - 1:
                    i += 1
                    if i >= len(lines):
                        break
                    next_line = lines[i]
                    if next_line.strip() == "":
                        continue
                    next_indent = len(next_line) - len(next_line.lstrip())
                    if next_indent <= indent and next_line.strip() != "":
                        i -= 1
                        break
                
                # Also remove any @doc or @spec above the function
                k = len(result_lines) - 1
                while k >= 0:
                    prev_line = result_lines[k].strip()
                    if prev_line.startswith('@doc') or prev_line.startswith('@spec') or prev_line.startswith('#'):
                        result_lines.pop()
                        k -= 1
                    elif prev_line == "":
                        result_lines.pop()
                        k -= 1
                    else:
                        break
            else:
                result_lines.append(line)
        else:
            result_lines.append(line)
        i += 1
    
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
    
    return '\n'.join(cleaned_lines)

if __name__ == "__main__":
    file_path = sys.argv[1]
    unused_file = sys.argv[2]
    
    # Read unused functions
    unused_functions = set()
    with open(unused_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                unused_functions.add(line)
    
    # Remove unused functions
    new_content = remove_unused_functions(file_path, unused_functions)
    
    # Write back
    with open(file_path, 'w') as f:
        f.write(new_content)
EOF
    
    # Run the Python script
    python3 /tmp/remove_functions.py "$file" /tmp/current_file_unused.txt
done

# Summary
echo ""
echo "✅ Unused function removal complete!"
echo "Backup created at: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "1. Run 'mix compile --warnings-as-errors' to verify compilation"
echo "2. Run 'mix test' to ensure tests pass"
echo "3. Run 'mix dialyzer' to verify unused functions are removed"

# Count remaining unused functions
if [ -f /workspace/dialyzer.txt ]; then
    total_before=$(grep -c "unused_fun" /workspace/dialyzer.txt)
    echo ""
    echo "Unused functions before: $total_before"
    echo "Run dialyzer again to see the improvement!"
fi