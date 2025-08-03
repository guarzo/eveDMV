#!/bin/bash
# Script to identify truly unused functions by checking references

echo "🔍 Identifying truly unused functions..."

# Extract unused functions from dialyzer
echo "Parsing dialyzer output..."
grep -A1 "unused_fun" /workspace/dialyzer.txt | \
  grep -B1 "Function.*will never be called" | \
  grep -v "^--$" | \
  paste - - | \
  awk -F'[: ]' '{
    file=$1; line=$2; 
    match($0, /Function ([a-zA-Z_?!]+)\/([0-9]+)/, arr); 
    if(arr[1]) print file "|" line "|" arr[1] "|" arr[2]
  }' > /tmp/unused_candidates.txt

echo "Found $(wc -l < /tmp/unused_candidates.txt) potentially unused functions"

# Check each function to see if it's truly unused
echo "Checking for references..."
> /tmp/truly_unused.txt

while IFS='|' read -r file line func arity; do
  # Skip if file doesn't exist
  [ ! -f "$file" ] && continue
  
  # Check if function is referenced anywhere in the codebase
  # Look for direct calls, apply/3 calls, or & references
  references=$(rg -c "\b$func\b" --type elixir 2>/dev/null | grep -v "^$file:" | wc -l)
  
  if [ "$references" -eq 0 ]; then
    # Double check with more patterns
    apply_refs=$(rg -c "apply.*:$func|&$func/$arity" --type elixir 2>/dev/null | wc -l)
    
    if [ "$apply_refs" -eq 0 ]; then
      echo "$file|$line|$func|$arity" >> /tmp/truly_unused.txt
    fi
  fi
done < /tmp/unused_candidates.txt

truly_unused_count=$(wc -l < /tmp/truly_unused.txt)
echo "Found $truly_unused_count truly unused functions (no references found)"

# Group by file
echo ""
echo "Files with truly unused functions:"
cut -d'|' -f1 /tmp/truly_unused.txt | sort | uniq -c | sort -nr | head -20

# Create removal script for truly unused functions
cat > /tmp/remove_truly_unused.py << 'EOF'
#!/usr/bin/env python3
import sys
import re

def remove_function(content, func_name, line_num):
    """Remove a function based on its name and approximate line number."""
    lines = content.split('\n')
    
    # Find the function definition near the given line
    search_start = max(0, int(line_num) - 10)
    search_end = min(len(lines), int(line_num) + 10)
    
    func_line_idx = None
    func_pattern = rf'^\s*defp?\s+{re.escape(func_name)}\s*\('
    
    for i in range(search_start, search_end):
        if re.match(func_pattern, lines[i]):
            func_line_idx = i
            break
    
    if func_line_idx is None:
        return content  # Function not found
    
    # Find the end of the function
    indent = len(lines[func_line_idx]) - len(lines[func_line_idx].lstrip())
    end_idx = func_line_idx + 1
    
    while end_idx < len(lines):
        line = lines[end_idx]
        if line.strip() == '':
            end_idx += 1
            continue
        
        line_indent = len(line) - len(line.lstrip())
        if line_indent <= indent and line.strip() != '':
            if line.strip() == 'end' and line_indent == indent:
                end_idx += 1
            break
        end_idx += 1
    
    # Remove @doc and @spec if present
    start_idx = func_line_idx
    i = func_line_idx - 1
    while i >= 0:
        line = lines[i].strip()
        if line.startswith('@') or line == '' or line.startswith('#'):
            start_idx = i
            i -= 1
        else:
            break
    
    # Remove the function
    new_lines = lines[:start_idx] + lines[end_idx:]
    
    # Clean up multiple blank lines
    cleaned = []
    prev_blank = False
    for line in new_lines:
        if line.strip() == '':
            if not prev_blank:
                cleaned.append(line)
            prev_blank = True
        else:
            cleaned.append(line)
            prev_blank = False
    
    return '\n'.join(cleaned)

if __name__ == '__main__':
    unused_file = sys.argv[1]
    
    # Group by file
    files_to_process = {}
    with open(unused_file, 'r') as f:
        for line in f:
            parts = line.strip().split('|')
            if len(parts) == 4:
                file_path, line_num, func_name, arity = parts
                if file_path not in files_to_process:
                    files_to_process[file_path] = []
                files_to_process[file_path].append((func_name, line_num))
    
    # Process each file
    for file_path, functions in files_to_process.items():
        print(f"Processing {file_path}...")
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            
            # Remove functions in reverse order (bottom to top)
            for func_name, line_num in sorted(functions, key=lambda x: int(x[1]), reverse=True):
                print(f"  Removing {func_name} at line {line_num}")
                content = remove_function(content, func_name, line_num)
            
            with open(file_path, 'w') as f:
                f.write(content)
            
            print(f"  ✓ Removed {len(functions)} functions")
        except Exception as e:
            print(f"  ✗ Error: {e}")
EOF

chmod +x /tmp/remove_truly_unused.py

echo ""
echo "To remove truly unused functions, run:"
echo "  python3 /tmp/remove_truly_unused.py /tmp/truly_unused.txt"
echo ""
echo "Or to see the list first:"
echo "  cat /tmp/truly_unused.txt"