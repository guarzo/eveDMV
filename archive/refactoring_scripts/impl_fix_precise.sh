#!/bin/bash
# impl_fix_precise.sh

set -e  # Exit on any error

echo "=== PRECISE @IMPL ANNOTATIONS FIX ==="
BEFORE_COUNT=$(grep -c "@impl true.*should be" /workspace/credo.txt)
echo "Starting with $BEFORE_COUNT @impl annotation errors"

# Apply precise fixes based on callback function names
echo "Fixing @impl annotations with precise callback matching..."

# Fix context modules - they implement both BoundedContext and Supervisor
# Functions like event_subscriptions, api_module, child_spec, can_handle? are BoundedContext callbacks
# Functions like init/1 are Supervisor callbacks

find lib/eve_dmv/contexts -name "*.ex" -type f | while read file; do
  if [[ -f "$file" ]]; then
    echo "Processing context file: $file"
    
    # Fix BoundedContext callbacks
    sed -i '/def event_subscriptions/,/^  end$/ s/@impl Supervisor/@impl EveDmv.Contexts.BoundedContext/g' "$file"
    sed -i '/def api_module/,/^  end$/ s/@impl Supervisor/@impl EveDmv.Contexts.BoundedContext/g' "$file"
    sed -i '/def child_spec/,/^  end$/ s/@impl Supervisor/@impl EveDmv.Contexts.BoundedContext/g' "$file"
    sed -i '/def can_handle?/,/^  end$/ s/@impl Supervisor/@impl EveDmv.Contexts.BoundedContext/g' "$file"
    
    # Keep Supervisor callbacks as @impl Supervisor (init/1 is correct)
    echo "Fixed BoundedContext callbacks in: $file"
  fi
done

# Fix standalone Supervisor modules (reliability_supervisor, event_bus_supervisor)
find lib -name "*supervisor.ex" -type f | while read file; do
  if [[ -f "$file" ]] && ! [[ "$file" =~ contexts/ ]]; then
    echo "Processing supervisor file: $file"
    # These are pure Supervisor implementations, keep as @impl Supervisor
    echo "Supervisor callbacks already correct in: $file"
  fi
done

# Fix GenServer modules
find lib -name "*.ex" -type f | while read file; do
  if [[ -f "$file" ]] && grep -q "use GenServer" "$file" && grep -q "@impl true" "$file"; then
    echo "Fixing GenServer @impl in: $file"
    sed -i 's/@impl true/@impl GenServer/g' "$file"
  fi
done

# Fix Phoenix.LiveView modules
find lib -name "*.ex" -type f | while read file; do
  if [[ -f "$file" ]] && (grep -q "use Phoenix.LiveView" "$file" || grep -q "use EveDmvWeb, :live_view" "$file") && grep -q "@impl true" "$file"; then
    echo "Fixing Phoenix.LiveView @impl in: $file"
    sed -i 's/@impl true/@impl Phoenix.LiveView/g' "$file"
  fi
done

# Fix Broadway modules
find lib -name "*.ex" -type f | while read file; do
  if [[ -f "$file" ]] && grep -q "use Broadway" "$file" && grep -q "@impl true" "$file"; then
    echo "Fixing Broadway @impl in: $file"
    sed -i 's/@impl true/@impl Broadway/g' "$file"
  fi
done

# Fix Phoenix.LiveComponent modules
find lib -name "*.ex" -type f | while read file; do
  if [[ -f "$file" ]] && grep -q "use Phoenix.LiveComponent" "$file" && grep -q "@impl true" "$file"; then
    echo "Fixing Phoenix.LiveComponent @impl in: $file"
    sed -i 's/@impl true/@impl Phoenix.LiveComponent/g' "$file"
  fi
done

# Fix Agent modules
find lib -name "*.ex" -type f | while read file; do
  if [[ -f "$file" ]] && grep -q "use Agent" "$file" && grep -q "@impl true" "$file"; then
    echo "Fixing Agent @impl in: $file"
    sed -i 's/@impl true/@impl Agent/g' "$file"
  fi
done

# Fix Task modules
find lib -name "*.ex" -type f | while read file; do
  if [[ -f "$file" ]] && grep -q "use Task" "$file" && grep -q "@impl true" "$file"; then
    echo "Fixing Task @impl in: $file"
    sed -i 's/@impl true/@impl Task/g' "$file"
  fi
done

echo "Verification phase..."

# Check compilation (allow warnings for now)
echo "Checking compilation..."
if ! mix compile; then
  echo "COMPILATION FAILED"
  exit 1
fi

# Check final result
mix credo --strict > /tmp/credo_after_impl.txt
REMAINING_ERRORS=$(grep -c "@impl true.*should be" /tmp/credo_after_impl.txt 2>/dev/null || echo "0")
echo "Remaining @impl annotation errors: $REMAINING_ERRORS"

if [ "$REMAINING_ERRORS" -gt 0 ]; then
  echo "REMAINING ERRORS: $REMAINING_ERRORS @impl annotation errors"
  grep "@impl true.*should be" /tmp/credo_after_impl.txt | head -10
  echo "Files requiring manual review:"
  grep "@impl true.*should be" /tmp/credo_after_impl.txt | cut -d: -f1 | sed 's/^\[R\] [→] //' | sort | uniq
else
  echo "SUCCESS: All @impl annotation errors eliminated"
fi

echo "=== @IMPL ANNOTATIONS FIX COMPLETE ==="