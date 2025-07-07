# Workstream 2: Import Ordering Fix - MANDATORY COMPLETION

## Overview
- **Total Errors**: 104 errors (13% of all issues)
- **Priority**: HIGH - Module organization foundation
- **Completion Requirement**: MUST reduce to 0 errors
- **Time Estimate**: 1-2 hours with verification

## MANDATORY SUCCESS CRITERIA
1. **EXACTLY 0 import ordering errors** remaining after completion
2. **All tests must pass** after changes
3. **No compilation errors** introduced
4. **Consistent import pattern** across all files

## Error Patterns to Fix
- `alias must appear before require` - 52 errors
- `use must appear before alias` - 52 errors

## EXECUTION SCRIPT - MUST RUN EXACTLY AS WRITTEN

```bash
#!/bin/bash
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
  python3 << EOF
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
EOF

done

# STEP 3: MANDATORY VERIFICATION
echo "Checking compilation..."
if ! mix compile --warnings-as-errors; then
  echo "COMPILATION FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_imports_* lib/
  exit 1
fi

echo "Running tests..."
if ! mix test --max-failures 1; then
  echo "TESTS FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_imports_* lib/
  exit 1
fi

# STEP 4: MANDATORY SUCCESS VERIFICATION
mix credo --strict > /tmp/credo_after_imports.txt
REMAINING_ERRORS=\$(grep -E "(alias must appear before|use must appear before)" /tmp/credo_after_imports.txt | wc -l)
echo "Remaining import ordering errors: \$REMAINING_ERRORS"

if [ "\$REMAINING_ERRORS" -gt 0 ]; then
  echo "FAILURE: \$REMAINING_ERRORS import ordering errors still remain"
  grep -E "(alias must appear before|use must appear before)" /tmp/credo_after_imports.txt | head -10
  exit 1
else
  echo "SUCCESS: All import ordering errors eliminated"
  rm -rf lib_backup_imports_*
fi

echo "=== IMPORT ORDERING FIX COMPLETE ==="
```

## MANUAL VERIFICATION COMMANDS

```bash
# 1. Check before state
grep -E "(alias must appear before|use must appear before)" /workspace/credo.txt | wc -l

# 2. Run the fix
chmod +x import_ordering_mandatory.sh && ./import_ordering_mandatory.sh

# 3. Verify after state (MUST be 0)
mix credo --strict | grep -E "(alias must appear before|use must appear before)" | wc -l
```

## EXPECTED TRANSFORMATIONS

### Before (Incorrect Order)
```elixir
defmodule SomeModule do
  require Logger
  alias EveDmv.Api
  use GenServer
  alias EveDmv.Repo
  
  def some_function, do: :ok
end
```

### After (Correct Order)
```elixir
defmodule SomeModule do
  use GenServer
  
  alias EveDmv.Api
  alias EveDmv.Repo
  
  require Logger
  
  def some_function, do: :ok
end
```

## HIGH-IMPACT FILES TO VERIFY

Based on error analysis, these files will be fixed:
- `lib/eve_dmv/contexts/fleet_operations/domain/effectiveness_calculator.ex`
- `lib/eve_dmv/contexts/killmail_processing/domain/ingestion_service.ex`
- `lib/eve_dmv/contexts/killmail_processing/domain/killmail_orchestrator.ex`
- `lib/eve_dmv/contexts/market_intelligence/domain/price_service.ex`

## FAILURE RECOVERY

If the script fails:
1. Backup is automatically restored
2. Check the specific compilation error
3. Fix manually if needed
4. Re-run the script

## SUCCESS VERIFICATION CHECKLIST

- [ ] Script runs without errors
- [ ] All tests pass
- [ ] No compilation warnings
- [ ] `grep -E "(alias must appear before|use must appear before)" /workspace/credo.txt | wc -l` returns 0
- [ ] Files follow consistent import pattern: use → alias → require → import

This workstream MUST achieve 0 import ordering errors. No exceptions.