#!/bin/bash

echo "Fixing dependency issues in external directory..."

# Files that use HTTPoison
httpoison_files=(
    "/workspace/lib/eve_dmv/external/eve/esi_request_client.ex"
    "/workspace/lib/eve_dmv/external/wanderer/wanderer_client.ex"
)

# Files that use Jason
jason_files=(
    "/workspace/lib/eve_dmv/external/eve/esi_request_client.ex"
    "/workspace/lib/eve_dmv/external/wanderer/wanderer_client.ex"
)

# Files that use :telemetry
telemetry_files=(
    "/workspace/lib/eve_dmv/external/eve/circuit_breaker.ex"
    "/workspace/lib/eve_dmv/external/eve/esi_request_client.ex"
)

# Add HTTPoison alias where needed
for file in "${httpoison_files[@]}"; do
    if [ -f "$file" ]; then
        echo "Checking $file for HTTPoison usage..."
        # Check if HTTPoison is used but not aliased
        if grep -q "HTTPoison\." "$file" && ! grep -q "alias HTTPoison" "$file"; then
            echo "  Adding HTTPoison alias to $file"
            # Add alias after the module definition
            sed -i '/^defmodule.*do$/a\  alias HTTPoison' "$file"
        fi
    fi
done

# Add Jason alias where needed
for file in "${jason_files[@]}"; do
    if [ -f "$file" ]; then
        echo "Checking $file for Jason usage..."
        # Check if Jason is used but not aliased
        if grep -q "Jason\." "$file" && ! grep -q "alias Jason" "$file"; then
            echo "  Adding Jason alias to $file"
            # Add alias after existing aliases or module definition
            if grep -q "^  alias" "$file"; then
                # Add after last alias
                awk '/^  alias/ {last_alias=NR} {lines[NR]=$0} END {for(i=1;i<=NR;i++){print lines[i]; if(i==last_alias) print "  alias Jason"}}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            else
                # Add after module definition
                sed -i '/^defmodule.*do$/a\  alias Jason' "$file"
            fi
        fi
    fi
done

# Fix telemetry calls to use :telemetry module directly
for file in "${telemetry_files[@]}"; do
    if [ -f "$file" ]; then
        echo "Fixing telemetry calls in $file..."
        # Replace telemetry.execute with :telemetry.execute
        sed -i 's/telemetry\.execute/:telemetry.execute/g' "$file"
        # But not if it's already :telemetry.execute
        sed -i 's/::telemetry\.execute/:telemetry.execute/g' "$file"
    fi
done

# Fix String.Chars.to_string issues
# These usually come from string interpolation in Logger calls
# We need to explicitly convert terms to strings

echo "Fixing String.Chars.to_string issues..."
files_with_string_issues=(
    "/workspace/lib/eve_dmv/external/eve/circuit_breaker.ex"
    "/workspace/lib/eve_dmv/external/eve/error_classifier.ex"
    "/workspace/lib/eve_dmv/external/eve/esi_character_client.ex"
    "/workspace/lib/eve_dmv/external/eve/esi_corporation_client.ex"
    "/workspace/lib/eve_dmv/external/eve/esi_market_client.ex"
    "/workspace/lib/eve_dmv/external/eve/esi_parsers.ex"
    "/workspace/lib/eve_dmv/external/eve/esi_request_client.ex"
    "/workspace/lib/eve_dmv/external/eve/esi_universe_client.ex"
    "/workspace/lib/eve_dmv/external/eve/esi_utils.ex"
)

for file in "${files_with_string_issues[@]}"; do
    if [ -f "$file" ]; then
        echo "  Checking $file for string interpolation issues..."
        # This is tricky - we need to find Logger calls with interpolation
        # For now, let's ensure inspect is used for complex terms
        sed -i 's/Logger\.\(debug\|info\|warn\|error\)("\([^"]*\)#{/Logger.\1("\2#{inspect(/g' "$file"
    fi
done

echo "External directory dependency fixes complete!"