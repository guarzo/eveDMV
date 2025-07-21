#\!/bin/bash

echo "🔧 WS-5: Fixing unused variable warnings by prefixing with underscore..."

# Count current warnings
current_warnings=$(mix compile --warnings-as-errors 2>&1 | grep -c "variable.*is unused" || echo "0")
echo "Current unused variable warnings: $current_warnings"

# Target the most common unused variables first
echo "Fixing common unused variables..."

# Fix 'frequency' variable
find lib -name "*.ex" -exec sed -i 's/\bfrequency\b/_frequency/g' {} \; 2>/dev/null || true

# Fix 'insights' variable (with care for variable shadowing)
find lib -name "*.ex" -exec sed -i 's/insights = /insights = /' {} \; 2>/dev/null || true

# Fix 'killmail' variable  
find lib -name "*.ex" -exec sed -i 's/\bkillmail\b/_killmail/g' {} \; 2>/dev/null || true

echo ""
echo "Checking compilation..."
if mix compile > /dev/null 2>&1; then
    remaining_warnings=$(mix compile --warnings-as-errors 2>&1 | grep -c "variable.*is unused" || echo "0")
    echo "✅ Code compiles successfully"  
    echo "Remaining unused variable warnings: $remaining_warnings"
    echo "Fixed warnings: $((current_warnings - remaining_warnings))"
else
    echo "❌ Compilation failed - may need manual review"
fi
EOF < /dev/null