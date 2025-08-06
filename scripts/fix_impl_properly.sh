#!/bin/bash
# Fix duplicate @impl attributes more thoroughly

echo "Fixing duplicate @impl attributes properly..."

# Function to fix @impl issues
fix_impl() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "Processing $file"
        # Remove @impl GenServer lines (keeping only @impl true)
        sed -i '/@impl GenServer$/d' "$file"
        
        # Remove consecutive @impl true lines
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

# Fix the problematic files
fix_impl "/workspace/lib/eve_dmv/platform/database/connection_pool_monitor.ex"
fix_impl "/workspace/lib/eve_dmv/platform/monitoring/telemetry/query_monitor.ex"
fix_impl "/workspace/lib/eve_dmv/platform/monitoring/performance_dashboard.ex"

echo "Fixed @impl attributes"