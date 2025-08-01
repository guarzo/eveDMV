#!/bin/bash

# Fix trailing whitespace in Elixir files
# Part of Workstream A - Automated Credo fixes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧹 Fixing trailing whitespace in Elixir files..."

# Counter for processed files
fixed_count=0
total_count=0

# Function to fix trailing whitespace in a single file
fix_file_whitespace() {
    local file="$1"
    local temp_file="/tmp/$(basename "$file").tmp"
    
    # Remove trailing whitespace and save to temp file
    sed 's/[[:space:]]*$//' "$file" > "$temp_file"
    
    # Only replace if changes were made
    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        echo "  ✅ Fixed: $file"
        return 0
    else
        rm "$temp_file"
        return 1
    fi
}

# Process files in batches following the protocol
process_batch() {
    local batch_files=("$@")
    local batch_size=${#batch_files[@]}
    
    echo "📦 Processing batch of $batch_size files..."
    
    for file in "${batch_files[@]}"; do
        total_count=$((total_count + 1))
        
        if fix_file_whitespace "$file"; then
            fixed_count=$((fixed_count + 1))
            
            # Test compilation after each file (as per protocol)
            echo "  🔍 Testing compilation..."
            if ! mix compile --warnings-as-errors >/dev/null 2>&1; then
                echo "  ❌ Compilation failed for $file - reverting"
                git checkout HEAD -- "$file"
                fixed_count=$((fixed_count - 1))
            else
                # Commit the single file fix
                git add "$file"
                git commit -m "fix(credo): resolve trailing whitespace in $(basename "$file")"
                echo "  ✅ Committed fix for $file"
            fi
        fi
    done
}

# Find all Elixir files with trailing whitespace
echo "🔍 Finding files with trailing whitespace..."
files_with_whitespace=()

while IFS= read -r -d '' file; do
    if grep -q '[[:space:]]$' "$file"; then
        files_with_whitespace+=("$file")
    fi
done < <(find "$PROJECT_ROOT/lib" -name "*.ex" -print0)

total_files=${#files_with_whitespace[@]}
echo "📊 Found $total_files files with trailing whitespace"

if [ $total_files -eq 0 ]; then
    echo "🎉 No trailing whitespace found!"
    exit 0
fi

# Process files in batches of 25 (manageable size with frequent commits)
batch_size=25
for ((i=0; i<total_files; i+=batch_size)); do
    batch=("${files_with_whitespace[@]:i:batch_size}")
    process_batch "${batch[@]}"
    
    # Quality gate checkpoint every 25 files
    echo "🏁 Batch checkpoint - running Credo analysis..."
    mix credo --strict --files-included="lib/**/*.ex" | head -5 || true
done

echo ""
echo "📈 Summary:"
echo "  Total files processed: $total_count"
echo "  Files with whitespace fixed: $fixed_count"
echo "  Compilation failures: $((total_count - fixed_count))"
echo ""
echo "🎯 Workstream A Progress: Automated trailing whitespace cleanup complete!"