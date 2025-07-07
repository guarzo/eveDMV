#!/bin/bash
# impl_fix_direct.sh

set -e  # Exit on any error

echo "=== DIRECT @IMPL ANNOTATIONS FIX ==="
BEFORE_COUNT=$(grep -c "@impl true.*should be" /workspace/credo.txt)
echo "Starting with $BEFORE_COUNT @impl annotation errors"

# Apply specific fixes based on actual behavior analysis
echo "Fixing @impl annotations systematically..."

# Fix context modules that use Supervisor
find lib/eve_dmv/contexts -name "*.ex" -type f | while read file; do
  if grep -q "@impl true" "$file" && grep -q "use Supervisor" "$file"; then
    echo "Fixing Supervisor @impl in: $file"
    sed -i 's/@impl true/@impl Supervisor/g' "$file"
  fi
done

# Fix reliability_supervisor that uses Supervisor  
if [[ -f "lib/eve_dmv/eve/reliability_supervisor.ex" ]] && grep -q "@impl true" "lib/eve_dmv/eve/reliability_supervisor.ex" && grep -q "use Supervisor" "lib/eve_dmv/eve/reliability_supervisor.ex"; then
  echo "Fixing Supervisor @impl in: lib/eve_dmv/eve/reliability_supervisor.ex"
  sed -i 's/@impl true/@impl Supervisor/g' "lib/eve_dmv/eve/reliability_supervisor.ex"
fi

# Fix event_bus_supervisor that uses Supervisor
if [[ -f "lib/eve_dmv/infrastructure/event_bus_supervisor.ex" ]] && grep -q "@impl true" "lib/eve_dmv/infrastructure/event_bus_supervisor.ex" && grep -q "use Supervisor" "lib/eve_dmv/infrastructure/event_bus_supervisor.ex"; then
  echo "Fixing Supervisor @impl in: lib/eve_dmv/infrastructure/event_bus_supervisor.ex"
  sed -i 's/@impl true/@impl Supervisor/g' "lib/eve_dmv/infrastructure/event_bus_supervisor.ex"
fi

# Fix GenServer modules
find lib -name "*.ex" -type f | while read file; do
  if grep -q "@impl true" "$file" && grep -q "use GenServer" "$file"; then
    echo "Fixing GenServer @impl in: $file"
    sed -i 's/@impl true/@impl GenServer/g' "$file"
  fi
done

# Fix Phoenix.LiveView modules
find lib -name "*.ex" -type f | while read file; do
  if grep -q "@impl true" "$file" && (grep -q "use Phoenix.LiveView" "$file" || grep -q "use EveDmvWeb, :live_view" "$file"); then
    echo "Fixing Phoenix.LiveView @impl in: $file"
    sed -i 's/@impl true/@impl Phoenix.LiveView/g' "$file"
  fi
done

# Fix Broadway modules
find lib -name "*.ex" -type f | while read file; do
  if grep -q "@impl true" "$file" && grep -q "use Broadway" "$file"; then
    echo "Fixing Broadway @impl in: $file"
    sed -i 's/@impl true/@impl Broadway/g' "$file"
  fi
done

# Fix Phoenix.LiveComponent modules
find lib -name "*.ex" -type f | while read file; do
  if grep -q "@impl true" "$file" && grep -q "use Phoenix.LiveComponent" "$file"; then
    echo "Fixing Phoenix.LiveComponent @impl in: $file"
    sed -i 's/@impl true/@impl Phoenix.LiveComponent/g' "$file"
  fi
done

# Fix Agent modules
find lib -name "*.ex" -type f | while read file; do
  if grep -q "@impl true" "$file" && grep -q "use Agent" "$file"; then
    echo "Fixing Agent @impl in: $file"
    sed -i 's/@impl true/@impl Agent/g' "$file"
  fi
done

# Fix Task modules
find lib -name "*.ex" -type f | while read file; do
  if grep -q "@impl true" "$file" && grep -q "use Task" "$file"; then
    echo "Fixing Task @impl in: $file"
    sed -i 's/@impl true/@impl Task/g' "$file"
  fi
done

echo "Verification phase..."

# Check compilation
echo "Checking compilation..."
if ! mix compile --warnings-as-errors; then
  echo "COMPILATION FAILED"
  exit 1
fi

# Check final result
mix credo --strict > /tmp/credo_after_impl.txt
REMAINING_ERRORS=$(grep -c "@impl true.*should be" /tmp/credo_after_impl.txt 2>/dev/null || echo "0")
echo "Remaining @impl annotation errors: $REMAINING_ERRORS"

if [ "$REMAINING_ERRORS" -gt 0 ]; then
  echo "FAILURE: $REMAINING_ERRORS @impl annotation errors still remain"
  grep "@impl true.*should be" /tmp/credo_after_impl.txt | head -5
  exit 1
else
  echo "SUCCESS: All @impl annotation errors eliminated"
fi

echo "=== @IMPL ANNOTATIONS FIX COMPLETE ==="