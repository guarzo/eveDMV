# Workstream 4: Alias Alphabetization - MANDATORY COMPLETION

## Overview
- **Total Errors**: 54 errors (7% of all issues)
- **Priority**: MEDIUM-HIGH - Code organization consistency
- **Completion Requirement**: MUST reduce to 0 errors
- **Time Estimate**: 1 hour with verification

## MANDATORY SUCCESS CRITERIA
1. **EXACTLY 0 alias ordering errors** remaining after completion
2. **All tests must pass** after changes
3. **No compilation errors** introduced
4. **Alphabetical alias ordering** in all files

## Error Pattern
All errors follow: `The alias 'X' is not alphabetically ordered among its group`

## EXECUTION SCRIPT - MUST RUN EXACTLY AS WRITTEN

```bash
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
  echo "Processing: $file"
  
  # Apply alphabetization using Python
  python3 << EOF
import re

def alphabetize_aliases(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
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

done

# STEP 3: Handle grouped aliases (if any remain)
echo "Checking for grouped aliases that need expansion..."
find lib -name "*.ex" -type f -exec grep -l "alias.*{" {} \; | while read file; do
  echo "Expanding grouped aliases in: $file"
  
  python3 << EOF
import re

def expand_grouped_aliases(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
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

done

# STEP 4: Final alphabetization pass (in case expansion created new ordering issues)
echo "Final alphabetization pass..."
find lib -name "*.ex" -type f | while read file; do
  python3 << EOF
import re

def final_alphabetize(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
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
```

## VERIFICATION COMMANDS

```bash
# 1. Check before state
grep -c "not alphabetically ordered" /workspace/credo.txt

# 2. Run the fix
chmod +x alias_alphabetization_mandatory.sh && ./alias_alphabetization_mandatory.sh

# 3. Verify after state (MUST be 0)
mix credo --strict | grep -c "not alphabetically ordered" || echo "0"
```

## TRANSFORMATION EXAMPLES

### Before (Incorrect Order)
```elixir
defmodule SomeModule do
  alias EveDmv.Repo
  alias EveDmv.Api
  alias EveDmv.Cache
  alias EveDmv.Analytics
```

### After (Alphabetical Order)
```elixir
defmodule SomeModule do
  alias EveDmv.Analytics
  alias EveDmv.Api
  alias EveDmv.Cache
  alias EveDmv.Repo
```

### Before (Grouped Aliases)
```elixir
alias EveDmv.Contexts.{FleetOperations, CombatIntelligence, MarketIntelligence}
```

### After (Individual + Alphabetical)
```elixir
alias EveDmv.Contexts.CombatIntelligence
alias EveDmv.Contexts.FleetOperations
alias EveDmv.Contexts.MarketIntelligence
```

## HIGH-IMPACT FILES

Based on error analysis, these files will be processed:
- `lib/eve_dmv/contexts/combat_intelligence.ex`
- `lib/eve_dmv/contexts/combat_intelligence/api.ex`
- `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex`
- `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex`
- `lib/eve_dmv/contexts/fleet_operations/api.ex`
- `lib/eve_dmv/contexts/fleet_operations/domain/effectiveness_calculator.ex`
- `lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex`
- `lib/eve_dmv/contexts/killmail_processing/api.ex`

## ALGORITHM DETAILS

The script uses a three-phase approach:

1. **Phase 1**: Find consecutive alias blocks and sort them alphabetically
2. **Phase 2**: Expand any remaining grouped aliases (`alias X.{A, B}`)
3. **Phase 3**: Final alphabetization pass to catch any new ordering issues

Each phase preserves:
- Original indentation
- Comments between aliases
- Module structure
- Non-alias lines

## FAILURE RECOVERY

If the script fails:
1. Backup is automatically restored
2. Check compilation error details
3. Fix manually if needed
4. Re-run the script

## SUCCESS CHECKLIST

- [ ] Script runs without errors
- [ ] All tests pass
- [ ] No compilation warnings
- [ ] `grep -c "not alphabetically ordered" /workspace/credo.txt` returns 0
- [ ] All alias blocks are in alphabetical order

This workstream MUST achieve 0 alias ordering errors. No exceptions.