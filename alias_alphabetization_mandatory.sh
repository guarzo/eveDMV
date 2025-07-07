#!/bin/bash
# alias_alphabetization_mandatory.sh

set -e  # Exit on any error

echo "=== MANDATORY ALIAS ALPHABETIZATION ==="
BEFORE_COUNT=$(grep -c "not alphabetically ordered" /workspace/credo.txt)
echo "Starting with $BEFORE_COUNT alias ordering errors"

# STEP 1: Backup current state
cp -r lib/ lib_backup_aliases_$(date +%Y%m%d_%H%M%S)

# STEP 2: Execute systematic alphabetization
echo "Alphabetizing aliases in all Elixir files..."

find lib -name "*.ex" -type f | while read file; do
  if [ -f "$file" ]; then
    echo "Processing: $file"
    
    # Apply alphabetization using Python
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
    
    # Find all alias blocks (consecutive alias statements)
    i = 0
    while i < len(lines):
        if re.match(r'^\s*alias\s+', lines[i]):
            # Found start of alias block
            alias_block_start = i
            alias_lines = []
            original_indices = []
            
            # Collect all consecutive alias lines
            while i < len(lines) and re.match(r'^\s*alias\s+', lines[i]):
                alias_lines.append(lines[i])
                original_indices.append(i)
                i += 1
            
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

# STEP 3: Handle grouped aliases (if any remain)
echo "Checking for grouped aliases that need expansion..."
find lib -name "*.ex" -type f | while read file; do
  if [ -f "$file" ] && grep -q "alias.*{" "$file"; then
    echo "Expanding grouped aliases in: $file"
    
    python3 << EOF
import re

def expand_grouped_aliases(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        return
    
    # Pattern: alias Module.{A, B, C}
    def expand_alias_group(match):
        full_match = match.group(0)
        prefix = match.group(1)
        group_content = match.group(2)
        
        # Split the grouped modules
        modules = [m.strip() for m in group_content.split(',')]
        
        # Create individual alias statements
        individual_aliases = []
        for module in modules:
            individual_aliases.append(f"alias {prefix}{module}")
        
        # Sort alphabetically
        individual_aliases.sort()
        
        return '\n'.join(individual_aliases)
    
    # Apply the expansion
    new_content = re.sub(
        r'alias\s+([^{]+)\{([^}]+)\}',
        expand_alias_group,
        content
    )
    
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Expanded grouped aliases in: {filepath}")

expand_grouped_aliases('$file')
EOF
  fi
done

# STEP 4: Final alphabetization pass (in case expansion created new ordering issues)
echo "Final alphabetization pass..."
find lib -name "*.ex" -type f | while read file; do
  if [ -f "$file" ]; then
    python3 << EOF
import re

def final_alphabetize(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        return
    
    lines = content.split('\n')
    modified = False
    
    i = 0
    while i < len(lines):
        if re.match(r'^\s*alias\s+', lines[i]):
            alias_block_start = i
            alias_lines = []
            original_indices = []
            
            while i < len(lines) and re.match(r'^\s*alias\s+', lines[i]):
                alias_lines.append(lines[i])
                original_indices.append(i)
                i += 1
            
            sorted_aliases = sorted(alias_lines)
            
            if alias_lines != sorted_aliases:
                modified = True
                for j, sorted_line in enumerate(sorted_aliases):
                    lines[original_indices[j]] = sorted_line
        else:
            i += 1
    
    if modified:
        with open(filepath, 'w') as f:
            f.write('\n'.join(lines))

final_alphabetize('$file')
EOF
  fi
done

# STEP 5: MANDATORY VERIFICATION
echo "Checking compilation..."
if ! mix compile --warnings-as-errors; then
  echo "COMPILATION FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_aliases_* lib/
  exit 1
fi

echo "Running tests..."
if ! mix test --max-failures 1; then
  echo "TESTS FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_aliases_* lib/
  exit 1
fi

# STEP 6: MANDATORY SUCCESS VERIFICATION
mix credo --strict > /tmp/credo_after_aliases.txt
REMAINING_ERRORS=$(grep -c "not alphabetically ordered" /tmp/credo_after_aliases.txt 2>/dev/null || echo "0")
echo "Remaining alias ordering errors: $REMAINING_ERRORS"

if [ "$REMAINING_ERRORS" -gt 0 ]; then
  echo "FAILURE: $REMAINING_ERRORS alias ordering errors still remain"
  grep "not alphabetically ordered" /tmp/credo_after_aliases.txt | head -10
  exit 1
else
  echo "SUCCESS: All alias ordering errors eliminated"
  rm -rf lib_backup_aliases_*
fi

echo "=== ALIAS ALPHABETIZATION COMPLETE ==="