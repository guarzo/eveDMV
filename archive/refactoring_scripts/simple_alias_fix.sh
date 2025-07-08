#!/bin/bash
# simple_alias_fix.sh

set -e

echo "=== SIMPLE ALIAS ALPHABETIZATION ==="
BEFORE_COUNT=$(grep -c "not alphabetically ordered" /workspace/credo.txt)
echo "Starting with $BEFORE_COUNT alias ordering errors"

# Backup current state
cp -r lib/ lib_backup_simple_$(date +%Y%m%d_%H%M%S)

# Simple alphabetization only - no grouped alias expansion
find lib -name "*.ex" -type f | while read file; do
  if [ -f "$file" ]; then
    python3 << EOF
import re

def alphabetize_aliases(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        return
    
    lines = content.split('\n')
    modified = False
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if re.match(r'^alias\s+', line):
            # Found start of alias block
            alias_lines = []
            original_indices = []
            
            # Collect all consecutive alias lines
            while i < len(lines):
                current_line = lines[i].strip()
                if re.match(r'^alias\s+', current_line):
                    alias_lines.append(lines[i])
                    original_indices.append(i)
                    i += 1
                else:
                    break
            
            # Sort the alias lines alphabetically
            sorted_aliases = sorted(alias_lines)
            
            # Check if order changed
            if alias_lines != sorted_aliases:
                modified = True
                # Replace with sorted version
                for j, sorted_line in enumerate(sorted_aliases):
                    lines[original_indices[j]] = sorted_line
        else:
            i += 1
    
    if modified:
        with open(filepath, 'w') as f:
            f.write('\n'.join(lines))
        print(f"Alphabetized aliases in: {filepath}")

alphabetize_aliases('$file')
EOF
  fi
done

# Check compilation
echo "Checking compilation..."
if ! mix compile; then
  echo "COMPILATION FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_simple_* lib/
  exit 1
fi

# Check results
mix credo --strict > /tmp/credo_after_simple.txt
REMAINING_ERRORS=$(grep -c "not alphabetically ordered" /tmp/credo_after_simple.txt 2>/dev/null || echo "0")
echo "Remaining alias ordering errors: $REMAINING_ERRORS"

if [ "$REMAINING_ERRORS" -gt 0 ]; then
  echo "Some alias ordering errors remain:"
  grep "not alphabetically ordered" /tmp/credo_after_simple.txt | head -5
else
  echo "SUCCESS: All alias ordering errors eliminated"
  rm -rf lib_backup_simple_*
fi

echo "=== SIMPLE ALIAS ALPHABETIZATION COMPLETE ==="