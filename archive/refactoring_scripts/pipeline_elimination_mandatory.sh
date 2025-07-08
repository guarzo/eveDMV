#!/bin/bash
# pipeline_elimination_mandatory.sh

set -e  # Exit on any error

echo "=== MANDATORY PIPELINE ELIMINATION ==="
echo "Starting with $(grep -c 'Use a function call when a pipeline is only one function long' /workspace/credo.txt) pipeline errors"

# STEP 1: Backup current state
cp -r lib/ lib_backup_$(date +%Y%m%d_%H%M%S)

# STEP 2: Execute systematic fixes
echo "Executing systematic pipeline fixes..."

# Pattern 1: Simple variable |> Function() - but NOT field.Module.function patterns
find lib -name "*.ex" -type f -exec sed -i -E 's/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*) \|> ([A-Z][a-zA-Z0-9]*\.[a-z][a-zA-Z0-9_]*)\(\)/\1\3(\2)/g' {} \;

# Pattern 2: variable |> Function(args) - but NOT field.Module.function patterns
find lib -name "*.ex" -type f -exec sed -i -E 's/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*) \|> ([A-Z][a-zA-Z0-9]*\.[a-z][a-zA-Z0-9_]*)\(([^)]*)\)/\1\3(\2, \4)/g' {} \;

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