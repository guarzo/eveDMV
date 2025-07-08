#\!/bin/bash
# import_ordering_mandatory.sh

set -e  # Exit on any error

echo "=== MANDATORY IMPORT ORDERING FIX ==="
BEFORE_COUNT=$(grep -E "(alias must appear before|use must appear before)" /workspace/credo.txt | wc -l)
echo "Starting with $BEFORE_COUNT import ordering errors"

# STEP 1: Backup current state
cp -r lib/ lib_backup_imports_$(date +%Y%m%d_%H%M%S)

# STEP 2: Execute systematic import reorganization
echo "Reorganizing imports in all Elixir files..."

find lib -name "*.ex" -type f | while read file; do
  echo "Processing: $file"
  
  # Create temporary reorganized file
  python3 << PYTHON_EOF
import re
import sys

def reorganize_imports(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Split file into lines
    lines = content.split('\n')
    
    # Find module definition
    module_start = -1
    for i, line in enumerate(lines):
        if re.match(r'^\s*defmodule\s+', line):
            module_start = i
            break
    
    if module_start == -1:
        return  # No module found, skip
    
    # Find first function/macro definition after module
    function_start = len(lines)
    for i in range(module_start + 1, len(lines)):
        if re.match(r'^\s*(def|defp|defmacro|defmacrop|defstruct|defexception)\s+', lines[i]):
            function_start = i
            break
    
    # Extract import-related lines between module and first function
    module_content_start = module_start + 1
    import_lines = []
    other_lines = []
    
    for i in range(module_content_start, function_start):
        line = lines[i].strip()
        if (line.startswith('use ') or 
            line.startswith('alias ') or 
            line.startswith('require ') or 
            line.startswith('import ')):
            import_lines.append((i, lines[i]))
        else:
            other_lines.append((i, lines[i]))
    
    # Categorize import lines
    use_lines = []
    alias_lines = []
    require_lines = []
    import_lines_only = []
    
    for original_index, line in import_lines:
        stripped = line.strip()
        if stripped.startswith('use '):
            use_lines.append(line)
        elif stripped.startswith('alias '):
            alias_lines.append(line)
        elif stripped.startswith('require '):
            require_lines.append(line)
        elif stripped.startswith('import '):
            import_lines_only.append(line)
    
    # Sort each category alphabetically (maintaining indentation)
    use_lines.sort()
    alias_lines.sort()
    require_lines.sort()
    import_lines_only.sort()
    
    # Reconstruct file
    new_lines = lines[:module_content_start]
    
    # Add imports in correct order: use, alias, require, import
    if use_lines:
        new_lines.extend(use_lines)
        if alias_lines or require_lines or import_lines_only:
            new_lines.append('')  # Blank line
    
    if alias_lines:
        new_lines.extend(alias_lines)
        if require_lines or import_lines_only:
            new_lines.append('')  # Blank line
    
    if require_lines:
        new_lines.extend(require_lines)
        if import_lines_only:
            new_lines.append('')  # Blank line
    
    if import_lines_only:
        new_lines.extend(import_lines_only)
        new_lines.append('')  # Blank line
    
    # Add other non-import lines back
    for original_index, line in other_lines:
        new_lines.append(line)
    
    # Add remaining lines (functions, etc.)
    new_lines.extend(lines[function_start:])
    
    # Write back to file
    with open(filepath, 'w') as f:
        f.write('\n'.join(new_lines))

reorganize_imports('$file')
PYTHON_EOF

done

# STEP 3: MANDATORY VERIFICATION
echo "Checking compilation..."
mix compile --warnings-as-errors
if [ $? -ne 0 ]; then
  echo "COMPILATION FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_imports_* lib/
  exit 1
fi

echo "Running tests..."
mix test --max-failures 1
if [ $? -ne 0 ]; then
  echo "TESTS FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_imports_* lib/
  exit 1
fi

# STEP 4: MANDATORY SUCCESS VERIFICATION
mix credo --strict > /tmp/credo_after_imports.txt
REMAINING_ERRORS=$(grep -E "(alias must appear before|use must appear before)" /tmp/credo_after_imports.txt | wc -l)
echo "Remaining import ordering errors: $REMAINING_ERRORS"

if [ "$REMAINING_ERRORS" -gt 0 ]; then
  echo "FAILURE: $REMAINING_ERRORS import ordering errors still remain"
  grep -E "(alias must appear before|use must appear before)" /tmp/credo_after_imports.txt | head -10
  exit 1
else
  echo "SUCCESS: All import ordering errors eliminated"
  rm -rf lib_backup_imports_*
fi

echo "=== IMPORT ORDERING FIX COMPLETE ==="
EOF < /dev/null