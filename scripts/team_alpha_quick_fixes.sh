#!/bin/bash
# Team Alpha - Infrastructure Quick Fixes
# Automated fixes for common unknown_function errors

set -e

echo "=== Team Alpha - Infrastructure Quick Fixes ==="

# Common fix patterns for unknown_function errors
echo "Applying automated fixes for common patterns..."

# Fix 1: Missing Phoenix.LiveView.JS imports
echo "1. Adding missing Phoenix.LiveView.JS imports..."
find /workspace/lib/eve_dmv_web/live -name "*.ex" -type f -exec grep -l "JS\." {} \; | while read file; do
    if ! grep -q "alias Phoenix.LiveView.JS" "$file"; then
        echo "  Adding JS alias to $file"
        sed -i '/use EveDmvWeb, :live_view/a\  alias Phoenix.LiveView.JS' "$file"
    fi
done

# Fix 2: Missing component imports
echo "2. Adding missing component imports..."
find /workspace/lib/eve_dmv_web -name "*.ex" -type f -exec grep -l "\.icon\|\.button\|\.input" {} \; | while read file; do
    if ! grep -q "import EveDmvWeb.CoreComponents" "$file"; then
        echo "  Adding CoreComponents import to $file"
        sed -i '/use EveDmvWeb, :live_view/a\  import EveDmvWeb.CoreComponents' "$file"
    fi
done

# Fix 3: Missing Ash imports in API calls
echo "3. Adding missing Ash imports..."
find /workspace/lib -name "*.ex" -type f -exec grep -l "Ash\.read\|Ash\.create\|Ash\.update" {} \; | while read file; do
    if ! grep -q "alias EveDmv.Api" "$file" && ! grep -q "import Ash.Query" "$file"; then
        echo "  Adding Ash imports to $file"
        sed -i '/defmodule/a\\n  alias EveDmv.Api\n  import Ash.Query' "$file"
    fi
done

# Fix 4: Common typos in function names
echo "4. Fixing common function name typos..."
find /workspace/lib -name "*.ex" -type f -exec sed -i 's/defp analyse_/defp analyze_/g' {} \;
find /workspace/lib -name "*.ex" -type f -exec sed -i 's/\.analyse_/.analyze_/g' {} \;

# Fix 5: Missing Ecto imports for database modules
echo "5. Adding missing Ecto imports to database modules..."
find /workspace/lib/eve_dmv/platform/database -name "*.ex" -type f | while read file; do
    if grep -q "from.*in.*where" "$file" && ! grep -q "import Ecto.Query" "$file"; then
        echo "  Adding Ecto.Query import to $file"
        sed -i '/defmodule/a\\n  import Ecto.Query, warn: false' "$file"
    fi
done

# Fix 6: Missing GenServer imports
echo "6. Adding missing GenServer behavior imports..."
find /workspace/lib -name "*.ex" -type f -exec grep -l "use GenServer" {} \; | while read file; do
    if ! grep -q "@impl GenServer" "$file" && grep -q "def handle_" "$file"; then
        echo "  Adding @impl GenServer annotations to $file"
        sed -i 's/def handle_/@impl GenServer\n  def handle_/g' "$file"
    fi
done

echo ""
echo "=== Quick Fix Summary ==="
echo "Applied automated fixes for:"
echo "- Missing Phoenix.LiveView.JS imports"
echo "- Missing component imports" 
echo "- Missing Ash imports"
echo "- Common function name typos"
echo "- Missing Ecto imports"
echo "- Missing GenServer annotations"

echo ""
echo "=== Next Steps ==="
echo "1. Run: mix compile --warnings-as-errors"
echo "2. Check remaining errors: mix dialyzer --format short | grep unknown_function | wc -l"
echo "3. Review specific modules for manual fixes"
echo "4. Test affected functionality"

echo ""
echo "Quick fixes completed!"