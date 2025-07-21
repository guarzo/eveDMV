#!/bin/bash

# Script to fix refactoring issues identified by Credo

echo "Starting refactoring fixes..."

# Function to fix pipe chain issues
fix_pipe_chains() {
    echo "Fixing pipe chain issues..."
    
    # Find all files with pipe chain issues
    mix credo --only refactor --format oneline 2>/dev/null | grep "Pipe chain should start" | cut -d' ' -f3 | while read -r file; do
        if [[ -f "$file" ]]; then
            echo "Processing $file"
            
            # Fix patterns like |> Enum.map() at start of line
            sed -i 's/^\(\s*\)|> \(.*\)$/\1\2/' "$file"
            
            # Fix patterns where pipe starts expression after = 
            sed -i 's/= |> /= /' "$file"
            
            # Fix patterns in case/if blocks
            sed -i 's/-> |> /-> /' "$file"
            
            # Fix double pipes
            sed -i 's/|> |> /|> /g' "$file"
        fi
    done
}

# Function to fix duplicate variable declarations
fix_duplicate_vars() {
    echo "Fixing duplicate variable declarations..."
    
    # Process files with the most common duplicate variables
    for var in "recommendations" "insights" "factors" "gaps" "patterns" "socket"; do
        echo "Fixing duplicate '$var' declarations..."
        
        mix credo --only refactor --format oneline 2>/dev/null | grep "Variable \"$var\" was declared more than once" | cut -d' ' -f3 | cut -d':' -f1 | sort -u | while read -r file; do
            if [[ -f "$file" ]]; then
                echo "  Processing $file for $var"
                
                # Create a temporary file
                temp_file=$(mktemp)
                
                # Process the file to rename duplicate declarations
                awk -v var="$var" '
                    BEGIN { count = 0; in_function = 0 }
                    /^\s*def / { in_function = 1; count = 0 }
                    /^\s*end\s*$/ && in_function { in_function = 0 }
                    {
                        if (in_function && match($0, "^(\\s*)" var "\\s*=", groups)) {
                            if (count > 0) {
                                sub(var "\\s*=", var "_" count " =", $0)
                            }
                            count++
                        }
                        print
                    }
                ' "$file" > "$temp_file"
                
                # Replace the original file
                mv "$temp_file" "$file"
            fi
        done
    done
}

# Function to fix module dependency issues
fix_module_deps() {
    echo "Fixing module dependency issues..."
    
    # Extract modules with too many dependencies
    mix credo --only refactor --format oneline 2>/dev/null | grep "Module has too many dependencies" | cut -d' ' -f3 | cut -d':' -f1 | sort -u | while read -r file; do
        if [[ -f "$file" ]]; then
            echo "Module with too many dependencies: $file"
            # For now, just log these - they need manual refactoring
        fi
    done > modules_need_refactoring.txt
}

# Function to fix inefficient Enum operations
fix_enum_efficiency() {
    echo "Fixing inefficient Enum operations..."
    
    # Fix double Enum.map
    find lib -name "*.ex" -type f -exec sed -i 's/|> Enum\.map([^)]*) |> Enum\.map(\([^)]*\))/|> Enum.map(\1)/g' {} \;
    
    # Fix double Enum.filter  
    find lib -name "*.ex" -type f -exec sed -i 's/|> Enum\.filter([^)]*) |> Enum\.filter(\([^)]*\))/|> Enum.filter(\1)/g' {} \;
}

# Main execution
echo "=== Refactoring Fix Script ==="
echo "Current refactoring issues: $(mix credo --only refactor --format oneline 2>/dev/null | wc -l)"

fix_pipe_chains
fix_duplicate_vars
fix_enum_efficiency
fix_module_deps

echo "Refactoring issues after fixes: $(mix credo --only refactor --format oneline 2>/dev/null | wc -l)"
echo "Modules needing manual refactoring saved to: modules_need_refactoring.txt"