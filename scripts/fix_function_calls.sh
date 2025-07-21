#!/bin/bash
# Script to systematically fix missing function call parentheses
# Part of Workstream 5: Build Quality & Automation

set -e

echo "🔧 WS-5: Systematic Function Call Parentheses Fix"
echo "================================================="

# Get compilation warnings to identify specific function call issues
echo "📋 Identifying function call issues..."
mix compile --warnings-as-errors 2>&1 | grep "undefined variable" | while read -r line; do
    # Extract variable name and file path
    var_name=$(echo "$line" | grep -o '"[^"]*"' | tr -d '"' | head -1)
    file_path=$(echo "$line" | grep -o '/[^:]*\.ex' | head -1)
    
    if [[ -n "$var_name" && -n "$file_path" ]]; then
        echo "  • Variable '$var_name' in $file_path"
        
        # Check if this is actually a function call (has a matching defp or def)
        if grep -q "def.*$var_name" "$file_path" 2>/dev/null; then
            echo "    → Found function definition, will fix call"
            
            # Fix the function call by adding parentheses
            # Target pattern: variable_name = function_name (without parentheses)
            sed -i "s/= $var_name$/= $var_name()/g" "$file_path"
            sed -i "s/ $var_name$/ $var_name()/g" "$file_path"
            
            echo "    ✅ Fixed function call for $var_name"
        else
            echo "    ⚠️  Not a function call, skipping"
        fi
    fi
done

echo ""
echo "🧹 Running additional cleanup patterns..."

# Fix common patterns found in the codebase
find lib -name "*.ex" -type f | while read -r file; do
    # Fix self without parentheses
    sed -i 's/send(self,/send(self(),/g' "$file"
    sed -i 's/Process\.send_after(self,/Process.send_after(self(),/g' "$file"
    
    # Fix common function calls that were missed
    sed -i 's/ schedule_cleanup$/ schedule_cleanup()/g' "$file"
    sed -i 's/ cleanup_expired_entries$/ cleanup_expired_entries()/g' "$file"
    sed -i 's/ perform_cache_warming$/ perform_cache_warming()/g' "$file"
    sed -i 's/ schedule_warm_cache$/ schedule_warm_cache()/g' "$file"
    
    # Fix configuration function calls
    sed -i 's/: max_tokens,/: max_tokens(),/g' "$file"
    sed -i 's/: refill_rate]/: refill_rate()]/g' "$file"
    sed -i 's/: batch_size,/: batch_size(),/g' "$file"
    sed -i 's/: max_concurrency,/: max_concurrency(),/g' "$file"
    sed -i 's/: task_timeout/: task_timeout()/g' "$file"
done

echo "✅ Pattern-based fixes completed"

echo ""
echo "🔍 Testing compilation..."
if mix compile --warnings-as-errors; then
    echo "✅ Compilation successful!"
else
    echo "❌ Compilation still has issues - manual review needed"
    echo ""
    echo "📋 Remaining issues:"
    mix compile --warnings-as-errors 2>&1 | grep -E "(warning:|error:)" | head -20
fi

echo ""
echo "📈 Running formatter to clean up any formatting issues..."
mix format

echo ""
echo "🎯 WS-5 Function Call Fix Summary"
echo "================================"
echo "• Applied systematic function call parentheses fixes"
echo "• Fixed common patterns (self, schedule_*, cleanup_*, etc.)"
echo "• Applied configuration function call fixes"
echo "• Formatted code for consistency"
echo ""
echo "Next steps:"
echo "1. Review remaining compilation issues manually"
echo "2. Set up pre-commit hooks to prevent regressions"
echo "3. Run integration validation"