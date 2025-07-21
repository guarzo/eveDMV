#!/bin/bash
# WS-1: Targeted Pipeline Simplification
# Fix only simple single-line pipeline cases

echo "🔧 WS-1: Targeted Pipeline Fixes"

# Get current count
current=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
echo "Current pipeline issues: $current"

# Create backup
backup_dir="backup_targeted_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Counter
total_fixed=0

# Get specific files and line numbers with pipeline issues
mix credo --format=oneline 2>/dev/null | grep "↗" | while IFS=':' read -r file line_num rest; do
    # Skip if not a file path
    if [[ ! "$file" =~ ^lib/ ]]; then
        continue
    fi
    
    echo "Checking $file:$line_num"
    
    # Read the specific line
    line_content=$(sed -n "${line_num}p" "$file" 2>/dev/null)
    
    if [[ -n "$line_content" ]]; then
        echo "  Line: $line_content"
        
        # Only process simple single-line pipelines
        if [[ "$line_content" =~ ^[[:space:]]*[^|]*\|>[[:space:]]*[A-Za-z_] ]] && [[ ! "$line_content" =~ fn[[:space:]] ]]; then
            # Create backup of file if not already backed up
            backup_file="$backup_dir/$(basename "$file")_$(date +%H%M%S)"
            if [[ ! -f "$backup_file" ]]; then
                cp "$file" "$backup_file"
            fi
            
            # Apply fix patterns
            # Pattern 1: variable |> Module.function(args) 
            if [[ "$line_content" =~ ([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*([A-Z][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*)\) ]]; then
                var="${BASH_REMATCH[1]}"
                func="${BASH_REMATCH[2]}"
                args="${BASH_REMATCH[3]}"
                
                if [[ -n "$args" ]]; then
                    new_line=$(echo "$line_content" | sed "s/${var} |> ${func}(${args})/${func}(${var}, ${args})/")
                else
                    new_line=$(echo "$line_content" | sed "s/${var} |> ${func}()/${func}(${var})/")
                fi
                
                # Replace the line in file
                sed -i "${line_num}s|.*|$new_line|" "$file"
                echo "  ✅ Fixed: $new_line"
                total_fixed=$((total_fixed + 1))
            fi
        else
            echo "  ⏭️  Skipped: Complex pipeline"
        fi
    fi
done

# Final count
final=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
actual_fixed=$((current - final))

echo ""
echo "✅ WS-1: Targeted Pipeline Fixes Complete"
echo "Issues fixed: $actual_fixed"
echo "Remaining: $final/$current"
echo "Backup: $backup_dir"

if [[ $final -lt 400 ]]; then
    echo "✅ Target achieved!"
else
    echo "⚠️  Need more manual fixes"
fi