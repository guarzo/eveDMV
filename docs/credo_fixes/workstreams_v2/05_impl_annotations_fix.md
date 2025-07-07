# Workstream 5: @impl Annotations Fix - MANDATORY COMPLETION

## Overview
- **Total Errors**: 43 errors (5% of all issues)
- **Priority**: MEDIUM - Code documentation and behavior clarity
- **Completion Requirement**: MUST reduce to 0 errors
- **Time Estimate**: 1 hour with verification

## MANDATORY SUCCESS CRITERIA
1. **EXACTLY 0 @impl annotation errors** remaining after completion
2. **All tests must pass** after changes
3. **No compilation errors** introduced
4. **Specific behavior annotations** instead of generic `@impl true`

## Error Pattern
All errors follow: `@impl true should be @impl MyBehaviour`

## EXECUTION SCRIPT - MUST RUN EXACTLY AS WRITTEN

```bash
#!/bin/bash
# impl_annotations_mandatory.sh

set -e  # Exit on any error

echo "=== MANDATORY @IMPL ANNOTATIONS FIX ==="
BEFORE_COUNT=$(grep -c "@impl true.*should be" /workspace/credo.txt)
echo "Starting with $BEFORE_COUNT @impl annotation errors"

# STEP 1: Backup current state
cp -r lib/ lib_backup_impl_$(date +%Y%m%d_%H%M%S)

# STEP 2: Execute systematic @impl fixes
echo "Fixing @impl annotations in all Elixir files..."

find lib -name "*.ex" -type f | while read file; do
  # Check if file has @impl true errors
  if grep -q "@impl true.*should be" /workspace/credo.txt | grep -q "$file"; then
    echo "Processing: $file"
    
    # Apply fixes using Python for precise control
    python3 << EOF
import re

def fix_impl_annotations(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Detect behavior patterns based on use statements and module context
    behavior_map = {
        'use GenServer': 'GenServer',
        'use Phoenix.LiveView': 'Phoenix.LiveView',
        'use EveDmvWeb, :live_view': 'Phoenix.LiveView', 
        'use Broadway': 'Broadway',
        'use Agent': 'Agent',
        'use Task': 'Task',
        'use Supervisor': 'Supervisor',
        'use DynamicSupervisor': 'DynamicSupervisor',
        '@behaviour GenServer': 'GenServer',
        '@behaviour Phoenix.LiveView': 'Phoenix.LiveView',
        '@behaviour Broadway': 'Broadway'
    }
    
    # Context-specific behaviors for new domain modules
    if 'contexts/' in filepath:
        if 'bounded_context' in filepath:
            behavior_map['use EveDmv.Contexts.BoundedContext'] = 'EveDmv.Contexts.BoundedContext'
        if any(x in filepath for x in ['combat_intelligence', 'fleet_operations', 'market_intelligence']):
            behavior_map['@behaviour EveDmv.Contexts.BoundedContext'] = 'EveDmv.Contexts.BoundedContext'
    
    # Detect the primary behavior for this file
    detected_behavior = None
    
    # Check for explicit use statements
    for pattern, behavior in behavior_map.items():
        if pattern in content:
            detected_behavior = behavior
            break
    
    # If no explicit behavior found, infer from callback patterns
    if not detected_behavior:
        if re.search(r'def handle_call|def handle_cast|def handle_info|def init', content):
            detected_behavior = 'GenServer'
        elif re.search(r'def mount|def handle_event|def handle_params|def render', content):
            detected_behavior = 'Phoenix.LiveView'
        elif re.search(r'def child_specs|def api|def resources', content):
            detected_behavior = 'EveDmv.Contexts.BoundedContext'
        elif re.search(r'def handle_message|def handle_batch', content):
            detected_behavior = 'Broadway'
    
    # Apply the fix if behavior detected
    if detected_behavior:
        # Replace @impl true with specific behavior
        content = re.sub(r'@impl true', f'@impl {detected_behavior}', content)
        
        if content != original_content:
            with open(filepath, 'w') as f:
                f.write(content)
            print(f"Fixed @impl annotations in: {filepath} -> {detected_behavior}")
    else:
        print(f"Could not detect behavior for: {filepath}")

fix_impl_annotations('$file')
EOF
  fi
done

# STEP 3: Handle specific context module behaviors
echo "Applying context-specific @impl fixes..."

# Fix BoundedContext implementations
find lib/eve_dmv/contexts -name "*.ex" -type f | while read file; do
  if grep -q "@impl true" "$file"; then
    echo "Checking context module: $file"
    
    # Check if it's a bounded context implementation
    if grep -q "child_specs\|api\|resources" "$file"; then
      sed -i 's/@impl true/@impl EveDmv.Contexts.BoundedContext/g' "$file"
      echo "Fixed BoundedContext @impl in: $file"
    fi
  fi
done

# STEP 4: MANDATORY VERIFICATION
echo "Checking compilation..."
if ! mix compile --warnings-as-errors; then
  echo "COMPILATION FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_impl_* lib/
  exit 1
fi

echo "Running tests..."
if ! mix test --max-failures 1; then
  echo "TESTS FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_impl_* lib/
  exit 1
fi

# STEP 5: MANDATORY SUCCESS VERIFICATION
mix credo --strict > /tmp/credo_after_impl.txt
REMAINING_ERRORS=$(grep -c "@impl true.*should be" /tmp/credo_after_impl.txt 2>/dev/null || echo "0")
echo "Remaining @impl annotation errors: $REMAINING_ERRORS"

if [ "$REMAINING_ERRORS" -gt 0 ]; then
  echo "FAILURE: $REMAINING_ERRORS @impl annotation errors still remain"
  grep "@impl true.*should be" /tmp/credo_after_impl.txt | head -10
  
  echo "Files requiring manual review:"
  grep "@impl true.*should be" /tmp/credo_after_impl.txt | cut -d: -f1 | sed 's/^\[R\] [→] //' | sort | uniq
  
  exit 1
else
  echo "SUCCESS: All @impl annotation errors eliminated"
  rm -rf lib_backup_impl_*
fi

echo "=== @IMPL ANNOTATIONS FIX COMPLETE ==="
```

## BEHAVIOR DETECTION RULES

The script uses these rules to detect the correct behavior:

### GenServer Modules
- **Detection**: `use GenServer` OR callback functions like `handle_call`, `handle_cast`, `init`
- **Fix**: `@impl true` → `@impl GenServer`

### Phoenix LiveView Modules  
- **Detection**: `use EveDmvWeb, :live_view` OR callback functions like `mount`, `handle_event`, `render`
- **Fix**: `@impl true` → `@impl Phoenix.LiveView`

### BoundedContext Modules
- **Detection**: Located in `contexts/` AND has functions like `child_specs`, `api`, `resources`
- **Fix**: `@impl true` → `@impl EveDmv.Contexts.BoundedContext`

### Broadway Modules
- **Detection**: `use Broadway` OR callback functions like `handle_message`, `handle_batch`
- **Fix**: `@impl true` → `@impl Broadway`

## VERIFICATION COMMANDS

```bash
# 1. Check before state
grep -c "@impl true.*should be" /workspace/credo.txt

# 2. Run the fix
chmod +x impl_annotations_mandatory.sh && ./impl_annotations_mandatory.sh

# 3. Verify after state (MUST be 0)
mix credo --strict | grep -c "@impl true.*should be" || echo "0"
```

## TRANSFORMATION EXAMPLES

### Before (Generic Annotation)
```elixir
defmodule SomeGenServer do
  use GenServer
  
  @impl true
  def init(_), do: {:ok, %{}}
  
  @impl true
  def handle_call(_, _, state), do: {:reply, :ok, state}
end
```

### After (Specific Annotation)
```elixir
defmodule SomeGenServer do
  use GenServer
  
  @impl GenServer
  def init(_), do: {:ok, %{}}
  
  @impl GenServer
  def handle_call(_, _, state), do: {:reply, :ok, state}
end
```

### Context Module Example

#### Before
```elixir
defmodule EveDmv.Contexts.CombatIntelligence do
  @impl true
  def child_specs, do: []
  
  @impl true
  def api, do: EveDmv.Contexts.CombatIntelligence.Api
end
```

#### After
```elixir
defmodule EveDmv.Contexts.CombatIntelligence do
  @impl EveDmv.Contexts.BoundedContext
  def child_specs, do: []
  
  @impl EveDmv.Contexts.BoundedContext
  def api, do: EveDmv.Contexts.CombatIntelligence.Api
end
```

## HIGH-IMPACT FILES

Based on error analysis, these files will be processed:
- `lib/eve_dmv/contexts/combat_intelligence.ex`
- `lib/eve_dmv/contexts/fleet_operations.ex`
- `lib/eve_dmv/contexts/market_intelligence.ex`
- All other context modules with generic `@impl true` annotations

## MANUAL REVIEW PROCESS (If Needed)

If any errors remain after automated fixes:

```bash
# Show remaining @impl errors with context
grep "@impl true.*should be" /workspace/credo.txt | while read error; do
  FILE=$(echo "$error" | cut -d: -f1 | sed 's/^\[R\] [→] //')
  LINE=$(echo "$error" | cut -d: -f2)
  
  echo "Manual review needed: $FILE:$LINE"
  
  # Show the @impl line and surrounding context
  sed -n "$((LINE-2)),$((LINE+2))p" "$FILE"
  echo "---"
done
```

For manual fixes:
1. Identify the primary behavior being implemented
2. Look for `use` statements or `@behaviour` declarations
3. Check callback function names to infer behavior
4. Replace `@impl true` with `@impl SpecificBehavior`

## FAILURE RECOVERY

If the script fails:
1. Backup is automatically restored
2. Check compilation error details
3. Review behavior detection logic
4. Fix manually if needed
5. Re-run the script

## SUCCESS CHECKLIST

- [ ] Script runs without errors
- [ ] All tests pass
- [ ] No compilation warnings
- [ ] `grep -c "@impl true.*should be" /workspace/credo.txt` returns 0
- [ ] All @impl annotations specify exact behaviors

This workstream MUST achieve 0 @impl annotation errors. No exceptions.