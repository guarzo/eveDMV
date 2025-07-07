# Workstream 1: Pipeline Elimination - MANDATORY COMPLETION

## Overview
- **Total Errors**: 241 errors (30% of all issues)
- **Priority**: CRITICAL - Largest error category
- **Completion Requirement**: MUST reduce to 0 errors
- **Time Estimate**: 2-3 hours with verification

## MANDATORY SUCCESS CRITERIA
1. **EXACTLY 0 pipeline errors** remaining after completion
2. **All tests must pass** after changes
3. **No compilation errors** introduced
4. **Verification screenshots** of before/after error counts

## Error Pattern Analysis
All errors follow pattern: `Use a function call when a pipeline is only one function long`

## EXECUTION SCRIPT - MUST RUN EXACTLY AS WRITTEN

```bash
#!/bin/bash
# pipeline_elimination_mandatory.sh

set -e  # Exit on any error

echo "=== MANDATORY PIPELINE ELIMINATION ==="
echo "Starting with $(grep -c 'Use a function call when a pipeline is only one function long' /workspace/credo.txt) pipeline errors"

# STEP 1: Backup current state
cp -r lib/ lib_backup_$(date +%Y%m%d_%H%M%S)

# STEP 2: Execute systematic fixes
echo "Executing systematic pipeline fixes..."

# Pattern 1: Simple variable |> Function()
find lib -name "*.ex" -type f -exec sed -i -E 's/([a-zA-Z_][a-zA-Z0-9_]*) \|> ([A-Z][a-zA-Z0-9\.]*\.[a-z][a-zA-Z0-9_]*)\(\)/\2(\1)/g' {} \;

# Pattern 2: variable |> Function(args)
find lib -name "*.ex" -type f -exec sed -i -E 's/([a-zA-Z_][a-zA-Z0-9_]*) \|> ([A-Z][a-zA-Z0-9\.]*\.[a-z][a-zA-Z0-9_]*)\(([^)]*)\)/\2(\1, \3)/g' {} \;

# Pattern 3: Phoenix LiveView specific patterns
find lib -name "*_live.ex" -type f -exec sed -i -E '
  s/socket \|> assign\(/assign(socket, /g
  s/socket \|> put_flash\(/put_flash(socket, /g
  s/socket \|> push_event\(/push_event(socket, /g
  s/socket \|> redirect\(/redirect(socket, /g
  s/socket \|> push_navigate\(/push_navigate(socket, /g
' {} \;

# Pattern 4: Common Enum patterns
find lib -name "*.ex" -type f -exec sed -i -E '
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> Enum\.count\(\)/Enum.count(\1)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> Enum\.empty\?\(\)/Enum.empty?(\1)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> length\(\)/length(\1)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> hd\(\)/hd(\1)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> tl\(\)/tl(\1)/g
' {} \;

# Pattern 5: Map operations
find lib -name "*.ex" -type f -exec sed -i -E '
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> Map\.get\(([^)]*)\)/Map.get(\1, \2)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> Map\.put\(([^)]*)\)/Map.put(\1, \2)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> Map\.merge\(([^)]*)\)/Map.merge(\1, \2)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> Map\.delete\(([^)]*)\)/Map.delete(\1, \2)/g
' {} \;

# Pattern 6: String operations
find lib -name "*.ex" -type f -exec sed -i -E '
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> String\.trim\(\)/String.trim(\1)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> String\.downcase\(\)/String.downcase(\1)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> String\.upcase\(\)/String.upcase(\1)/g
' {} \;

# Pattern 7: Process operations
find lib -name "*.ex" -type f -exec sed -i -E '
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> GenServer\.call\(([^)]*)\)/GenServer.call(\1, \2)/g
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|> GenServer\.cast\(([^)]*)\)/GenServer.cast(\1, \2)/g
' {} \;

# STEP 3: MANDATORY VERIFICATION
echo "Checking compilation..."
if ! mix compile --warnings-as-errors; then
  echo "COMPILATION FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_* lib/
  exit 1
fi

echo "Running tests..."
if ! mix test --max-failures 1; then
  echo "TESTS FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_* lib/
  exit 1
fi

# STEP 4: MANDATORY SUCCESS VERIFICATION
REMAINING_ERRORS=$(grep -c 'Use a function call when a pipeline is only one function long' /workspace/credo.txt 2>/dev/null || echo "0")
echo "Remaining pipeline errors: $REMAINING_ERRORS"

if [ "$REMAINING_ERRORS" -gt 0 ]; then
  echo "FAILURE: $REMAINING_ERRORS pipeline errors still remain"
  echo "Running manual review for remaining errors..."
  
  grep 'Use a function call when a pipeline is only one function long' /workspace/credo.txt | head -10
  
  echo "Manual fixes required for complex cases"
  exit 1
else
  echo "SUCCESS: All pipeline errors eliminated"
  rm -rf lib_backup_*
fi

echo "=== PIPELINE ELIMINATION COMPLETE ==="
```

## MANUAL REVIEW PROCESS - ONLY IF AUTOMATED SCRIPT FAILS

If the automated script leaves any errors, manually review each remaining case:

```bash
# Find remaining pipeline errors
grep 'Use a function call when a pipeline is only one function long' /workspace/credo.txt | while read line; do
  FILE=$(echo "$line" | cut -d: -f1 | sed 's/^\[R\] [↗↘→] //')
  LINE_NUM=$(echo "$line" | cut -d: -f2)
  
  echo "Manual review required: $FILE:$LINE_NUM"
  
  # Show context around the error
  sed -n "${LINE_NUM}p" "$FILE"
done
```

## EXECUTION INSTRUCTIONS - MUST FOLLOW EXACTLY

1. **SAVE** current credo.txt: `cp /workspace/credo.txt credo_before_pipelines.txt`
2. **RUN** the script: `chmod +x pipeline_elimination_mandatory.sh && ./pipeline_elimination_mandatory.sh`
3. **VERIFY** results: `mix credo --strict | grep -c 'Use a function call when a pipeline is only one function long' || echo "0"`
4. **CONFIRM** success: Result MUST be 0

## FAILURE RECOVERY

If script fails:
- Backup is automatically restored
- Review the specific error message
- Fix the issue manually
- Re-run the script

## COMMON PATTERNS THAT WILL BE FIXED

### Pattern 1: Simple Function Calls
```elixir
# BEFORE
data |> Map.get(:key)
socket |> assign(:loading, true)

# AFTER
Map.get(data, :key)
assign(socket, :loading, true)
```

### Pattern 2: Context-Specific Functions
```elixir
# BEFORE
result |> AnalyzerService.process()
params |> ValidationService.validate()

# AFTER
AnalyzerService.process(result)
ValidationService.validate(params)
```

This workstream MUST achieve 0 pipeline errors. No exceptions.