#!/bin/bash

echo "Restoring 205 corrupted files from git..."

# Get the list of corrupted files and restore them from git
find lib -name "*.ex" -exec grep -l "^|> Enum.sum() |> round()" {} \; | while read file; do
    echo "Restoring $file..."
    git restore "$file"
done

echo "Restoration complete. Checking compilation status..."
timeout 30s mix compile --force 2>&1 | head -10