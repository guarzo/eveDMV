#!/bin/bash

# Script to fix dialyzer errors in the external directory

echo "Fixing external directory dialyzer errors..."

# Function to fix Ash bulk_create calls
fix_bulk_create() {
    local file="$1"
    [ ! -f "$file" ] && return
    
    # Fix Ash.bulk_create to use Api.bulk_create
    sed -i 's/Ash\.bulk_create(\([^,]*\), \([^,]*\), \([^,]*\),/\2 |> Ash.bulk_create(\3,/g' "$file"
    sed -i 's/domain: EveDmv\.Api,/|> EveDmv.Api.bulk_create(/g' "$file"
}

# Function to fix HTTPoison calls
fix_httpoison() {
    local file="$1"
    [ ! -f "$file" ] && return
    
    # These files likely need HTTPoison dependency added or mocked
    if grep -q "HTTPoison\." "$file"; then
        echo "Note: $file uses HTTPoison - may need dependency check"
    fi
}

# Function to fix Jason calls
fix_jason() {
    local file="$1"
    [ ! -f "$file" ] && return
    
    # Jason should be available, dialyzer might not know about it
    if grep -q "Jason\." "$file"; then
        echo "Note: $file uses Jason - may need PLT rebuild"
    fi
}

# Fix data_persistence.ex specifically
echo "Fixing data_persistence.ex..."
file="/workspace/lib/eve_dmv/external/eve/static_data_loader/data_persistence.ex"
if [ -f "$file" ]; then
    # Fix Ash.bulk_create calls to use Api
    sed -i 's/case Ash\.bulk_create(/case EveDmv.Api.bulk_create(/g' "$file"
    
    # Fix any Query.do_filter calls
    sed -i 's/Ash\.Query\.do_filter/Ash.Query.filter/g' "$file"
fi

# Fix static_data_resolver.ex
echo "Fixing static_data_resolver.ex..."
file="/workspace/lib/eve_dmv/external/eve/name_resolver/static_data_resolver.ex"
if [ -f "$file" ]; then
    # Run the general Ash fixes
    /workspace/scripts/fix_ash_calls.sh
fi

# Fix display_service.ex
echo "Fixing display_service.ex..."
file="/workspace/lib/eve_dmv/external/killmails/display_service.ex"
if [ -f "$file" ]; then
    # Apply general fixes
    sed -i 's/Ash\.read_one(/Api.read(Ash.Query.limit(/g' "$file"
    sed -i 's/domain: Api)/1)) |> case do {:ok, [result]} -> {:ok, result}; {:ok, []} -> {:error, :not_found}; error -> error end/g' "$file"
fi

# Fix all files in external/eve directory for common patterns
echo "Applying common fixes to all external files..."
find /workspace/lib/eve_dmv/external -name "*.ex" -type f | while read -r file; do
    # Fix Ash.Query.do_filter -> Ash.Query.filter
    sed -i 's/Ash\.Query\.do_filter/Ash.Query.filter/g' "$file"
    
    # Fix Ecto.Query.Builder references (these are internal Ecto functions)
    sed -i 's/Ecto\.Query\.Builder\.not_nil!/not is_nil/g' "$file"
    
    # Fix String.Chars.to_string/1 - this is usually because dialyzer doesn't know about protocol implementations
    # No fix needed, just a dialyzer PLT issue
done

echo "External directory fixes complete!"