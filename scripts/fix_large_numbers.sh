#!/bin/bash

# Script to fix large number formatting issues identified by Credo
# This adds underscores to numbers > 9999

echo "Fixing large number formatting in all Elixir files..."

# Function to add underscores to large numbers
fix_large_numbers() {
    local file=$1
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Process the file line by line
    while IFS= read -r line; do
        # Replace large numbers with underscored versions
        # Handle numbers 10000-99999
        line=$(echo "$line" | sed -E 's/([^0-9])([0-9]{2})([0-9]{3})([^0-9])/\1\2_\3\4/g')
        
        # Handle numbers 100000-999999
        line=$(echo "$line" | sed -E 's/([^0-9])([0-9]{3})([0-9]{3})([^0-9])/\1\2_\3\4/g')
        
        # Handle numbers 1000000-9999999
        line=$(echo "$line" | sed -E 's/([^0-9])([0-9])([0-9]{3})([0-9]{3})([^0-9])/\1\2_\3_\4\5/g')
        
        echo "$line" >> "$temp_file"
    done < "$file"
    
    # Replace original file
    mv "$temp_file" "$file"
}

# Find all Elixir files and process them
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
    # Check if file has large numbers
    if grep -E '[^0-9][0-9]{5,}[^0-9]' "$file" > /dev/null 2>&1; then
        echo "Fixing large numbers in: $file"
        fix_large_numbers "$file"
    fi
done

echo "Large number formatting fixes complete!"