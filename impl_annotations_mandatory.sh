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