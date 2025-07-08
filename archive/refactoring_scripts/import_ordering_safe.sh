#\!/bin/bash
# import_ordering_safe.sh

set -e

echo "=== SAFE IMPORT ORDERING FIX ==="
BEFORE_COUNT=$(grep -E "(alias must appear before|use must appear before)" /workspace/credo.txt | wc -l)
echo "Starting with $BEFORE_COUNT import ordering errors"

# Create backup
cp -r lib/ lib_backup_safe_$(date +%Y%m%d_%H%M%S)

# Get specific files that have import ordering issues
echo "Identifying files with import ordering issues..."
mix credo --strict --format=json > /tmp/credo_issues.json 2>/dev/null || true

# Process files with a safer approach - only files with actual import issues
grep -l "alias must appear before\|use must appear before" /workspace/credo.txt | while read -r line; do
    # Extract file path from credo output
    file_path=$(echo "$line" | grep -o 'lib/[^:]*\.ex' | head -1)
    if [ -n "$file_path" ] && [ -f "$file_path" ]; then
        echo "Processing: $file_path"
        
        # Create a backup of the individual file
        cp "$file_path" "$file_path.bak"
        
        # Use a simpler approach - just reorder within the existing structure
        python3 << PYTHON_EOF
import re

def fix_imports(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    # Find defmodule line
    module_line = -1
    for i, line in enumerate(lines):
        if re.match(r'^\s*defmodule\s+', line):
            module_line = i
            break
    
    if module_line == -1:
        return False
    
    # Find the range where imports/uses/aliases are
    start_idx = module_line + 1
    end_idx = len(lines)
    
    # Find first def/defp/defmacro line
    for i in range(start_idx, len(lines)):
        if re.match(r'^\s*(def|defp|defmacro|defmacrop|defstruct|defexception|@)\s+', lines[i]):
            end_idx = i
            break
    
    # Extract import-related lines in the range
    import_related = []
    other_lines = []
    
    for i in range(start_idx, end_idx):
        line = lines[i]
        stripped = line.strip()
        
        if (stripped.startswith('use ') or 
            stripped.startswith('alias ') or 
            stripped.startswith('require ') or 
            stripped.startswith('import ') or
            stripped == '' or
            stripped.startswith('#')):
            import_related.append(line)
        else:
            other_lines.append(line)
    
    # Separate into categories
    use_lines = []
    alias_lines = []
    require_lines = []
    import_lines = []
    comment_blank_lines = []
    
    for line in import_related:
        stripped = line.strip()
        if stripped.startswith('use '):
            use_lines.append(line)
        elif stripped.startswith('alias '):
            alias_lines.append(line)
        elif stripped.startswith('require '):
            require_lines.append(line)
        elif stripped.startswith('import '):
            import_lines.append(line)
        elif stripped == '' or stripped.startswith('#'):
            comment_blank_lines.append(line)
    
    # Sort each category
    use_lines.sort()
    alias_lines.sort()
    require_lines.sort()
    import_lines.sort()
    
    # Rebuild the file
    result = []
    result.extend(lines[:start_idx])
    
    # Add in correct order with spacing
    if use_lines:
        result.extend(use_lines)
        if alias_lines or require_lines or import_lines:
            result.append('')
    
    if alias_lines:
        result.extend(alias_lines)
        if require_lines or import_lines:
            result.append('')
    
    if require_lines:
        result.extend(require_lines)
        if import_lines:
            result.append('')
    
    if import_lines:
        result.extend(import_lines)
        if other_lines:
            result.append('')
    
    # Add non-import lines back
    result.extend(other_lines)
    
    # Add rest of file
    result.extend(lines[end_idx:])
    
    # Write back
    with open(filepath, 'w') as f:
        f.write('\n'.join(result))
    
    return True

try:
    fix_imports('$file_path')
    print(f"Fixed: $file_path")
except Exception as e:
    print(f"Error processing $file_path: {e}")
    # Restore backup on error
    import shutil
    shutil.copy('$file_path.bak', '$file_path')
PYTHON_EOF

        # Remove individual backup
        rm -f "$file_path.bak"
    fi
done

echo "Testing compilation..."
if mix compile --warnings-as-errors; then
    echo "Compilation successful\!"
    
    echo "Running quick test..."
    if mix test --max-failures 1 --exclude slow; then
        echo "Tests passed\!"
        
        # Check results
        mix credo --strict > /tmp/credo_after_safe.txt 2>/dev/null || true
        REMAINING=$(grep -E "(alias must appear before|use must appear before)" /tmp/credo_after_safe.txt | wc -l)
        echo "Remaining import ordering errors: $REMAINING"
        
        if [ "$REMAINING" -lt "$BEFORE_COUNT" ]; then
            echo "SUCCESS: Reduced from $BEFORE_COUNT to $REMAINING import ordering errors"
            rm -rf lib_backup_safe_*
        else
            echo "No improvement - restoring backup"
            rm -rf lib/
            mv lib_backup_safe_* lib/
        fi
    else
        echo "Tests failed - restoring backup"
        rm -rf lib/
        mv lib_backup_safe_* lib/
    fi
else
    echo "Compilation failed - restoring backup"
    rm -rf lib/
    mv lib_backup_safe_* lib/
fi

echo "=== SAFE IMPORT ORDERING FIX COMPLETE ==="
EOF < /dev/null