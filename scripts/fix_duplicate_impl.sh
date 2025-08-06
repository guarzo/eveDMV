#!/bin/bash
# Fix duplicate @impl attributes

echo "Fixing duplicate @impl attributes..."

# Function to fix duplicate @impl in a file
fix_file() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "Processing $file"
        # Use awk to remove consecutive @impl true lines, keeping only the first one
        awk '
        BEGIN { prev_impl = 0 }
        /^[[:space:]]*@impl true[[:space:]]*$/ {
            if (!prev_impl) {
                print
                prev_impl = 1
            }
            next
        }
        {
            prev_impl = 0
            print
        }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
}

# Fix files with duplicate @impl annotations
fix_file "/workspace/lib/eve_dmv/platform/database/connection_pool_monitor.ex"
fix_file "/workspace/lib/eve_dmv/platform/monitoring/telemetry/query_monitor.ex"
fix_file "/workspace/lib/eve_dmv/platform/monitoring/performance_dashboard.ex"

echo "Fixed duplicate @impl attributes"