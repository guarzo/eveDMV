#!/bin/bash

echo "🔧 Fixing duplicate pipe operators..."

# Fix |> Enum|> Enum -> |> Enum (remove duplicate Enum)
find lib -name "*.ex" -type f -exec sed -i 's/|> Enum|> Enum/|> Enum/g' {} \;

# Fix |> Map|> Map -> |> Map (remove duplicate Map)  
find lib -name "*.ex" -type f -exec sed -i 's/|> Map|> Map/|> Map/g' {} \;

# Fix |> Kernel|> Kernel -> |> Kernel (remove duplicate Kernel)
find lib -name "*.ex" -type f -exec sed -i 's/|> Kernel|> Kernel/|> Kernel/g' {} \;

echo "✅ Duplicate pipe operators fixed"