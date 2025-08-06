#!/bin/bash
# Fix missing @impl true annotations for GenServer callbacks in Workstream A

echo "Fixing GenServer callback annotations in platform directory..."

# Find all Elixir files that use GenServer
files=$(find /workspace/lib/eve_dmv/platform -name "*.ex" -type f -exec grep -l "use GenServer" {} \;)

for file in $files; do
    echo "Processing $file..."
    
    # Create a temporary file
    temp_file="${file}.tmp"
    
    # Process the file line by line
    awk '
    BEGIN { 
        in_genserver = 0
        added_impl = 0
    }
    
    # Track if we are in a GenServer module
    /use GenServer/ { in_genserver = 1 }
    
    # Add @impl true before callback functions if not already present
    /^[[:space:]]*def (init|handle_call|handle_cast|handle_info|handle_continue|terminate|code_change)\(/ {
        if (in_genserver && !added_impl && prev_line !~ /@impl/) {
            print "  @impl true"
        }
        added_impl = 0
    }
    
    # Track @impl annotations
    /@impl/ { added_impl = 1 }
    
    # Print the current line
    { 
        prev_line = $0
        print 
    }
    ' "$file" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$file"
done

# Also fix Supervisor callbacks
echo "Fixing Supervisor callback annotations..."
files=$(find /workspace/lib/eve_dmv/platform -name "*.ex" -type f -exec grep -l "use Supervisor" {} \;)

for file in $files; do
    echo "Processing $file..."
    
    temp_file="${file}.tmp"
    
    awk '
    BEGIN { 
        in_supervisor = 0
        added_impl = 0
    }
    
    /use Supervisor/ { in_supervisor = 1 }
    
    /^[[:space:]]*def (init)\(/ {
        if (in_supervisor && !added_impl && prev_line !~ /@impl/) {
            print "  @impl true"
        }
        added_impl = 0
    }
    
    /@impl/ { added_impl = 1 }
    
    { 
        prev_line = $0
        print 
    }
    ' "$file" > "$temp_file"
    
    mv "$temp_file" "$file"
done

# Also handle DynamicSupervisor
echo "Fixing DynamicSupervisor callback annotations..."
files=$(find /workspace/lib/eve_dmv/platform -name "*.ex" -type f -exec grep -l "use DynamicSupervisor" {} \;)

for file in $files; do
    echo "Processing $file..."
    
    temp_file="${file}.tmp"
    
    awk '
    BEGIN { 
        in_supervisor = 0
        added_impl = 0
    }
    
    /use DynamicSupervisor/ { in_supervisor = 1 }
    
    /^[[:space:]]*def (init)\(/ {
        if (in_supervisor && !added_impl && prev_line !~ /@impl/) {
            print "  @impl true"
        }
        added_impl = 0
    }
    
    /@impl/ { added_impl = 1 }
    
    { 
        prev_line = $0
        print 
    }
    ' "$file" > "$temp_file"
    
    mv "$temp_file" "$file"
done

# Also fix Agent callbacks in cache and external modules
echo "Fixing callbacks in cache and external modules..."
cache_files=$(find /workspace/lib/eve_dmv/cache -name "*.ex" -type f 2>/dev/null)
external_files=$(find /workspace/lib/eve_dmv/external -name "*.ex" -type f 2>/dev/null)

for file in $cache_files $external_files; do
    if grep -q "use GenServer\|use Supervisor\|use DynamicSupervisor" "$file" 2>/dev/null; then
        echo "Processing $file..."
        
        temp_file="${file}.tmp"
        
        awk '
        BEGIN { 
            in_behavior = 0
            added_impl = 0
        }
        
        /use (GenServer|Supervisor|DynamicSupervisor)/ { in_behavior = 1 }
        
        /^[[:space:]]*def (init|handle_call|handle_cast|handle_info|handle_continue|terminate|code_change)\(/ {
            if (in_behavior && !added_impl && prev_line !~ /@impl/) {
                print "  @impl true"
            }
            added_impl = 0
        }
        
        /@impl/ { added_impl = 1 }
        
        { 
            prev_line = $0
            print 
        }
        ' "$file" > "$temp_file"
        
        mv "$temp_file" "$file"
    fi
done

echo "GenServer callback annotation fixes complete!"
echo ""
echo "Next steps:"
echo "1. Run 'mix compile --warnings-as-errors' to verify"
echo "2. Check specific modules with dialyzer"
echo "3. Commit with message: 'fix(dialyzer): add @impl true to GenServer callbacks in Workstream A'"