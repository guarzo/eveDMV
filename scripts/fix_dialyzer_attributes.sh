#!/bin/bash

echo "Fixing incorrect dialyzer attributes..."

# Find and fix all @dialyzer {:no_unused_fun, ...} attributes
find /workspace/lib -name "*.ex" -type f -exec sed -i 's/@dialyzer {:no_unused_fun,/@dialyzer {:nowarn_function,/g' {} \;

echo "Fixed all dialyzer attributes!"

# Show what was changed
echo "Changed files:"
find /workspace/lib -name "*.ex" -type f -exec grep -l "@dialyzer {:nowarn_function," {} \;