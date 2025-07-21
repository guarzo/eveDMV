#!/bin/bash

echo "Finding files with corrupted patterns..."

# Find files starting with |> Enum.sum() |> round() pattern
find lib -name "*.ex" -exec grep -l "^|> Enum.sum() |> round()" {} \; | sort

echo "---"
echo "Total corrupted files found:"
find lib -name "*.ex" -exec grep -l "^|> Enum.sum() |> round()" {} \; | wc -l