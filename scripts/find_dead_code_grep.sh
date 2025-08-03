#!/bin/bash
# Script to find dead code using grep

echo "🔍 Finding dead code patterns..."

# Create output directory
mkdir -p /tmp/dead_code_analysis

# 1. Find TODO/FIXME/HACK comments
echo "Finding TODO markers..."
grep -r "# \(TODO\|FIXME\|HACK\|XXX\|DEPRECATED\|UNUSED\)" lib/ --include="*.ex" > /tmp/dead_code_analysis/todo_markers.txt || true

# 2. Find commented out function definitions
echo "Finding commented out functions..."
grep -r "^\s*#.*def\s\+" lib/ --include="*.ex" > /tmp/dead_code_analysis/commented_functions.txt || true

# 3. Find empty function bodies
echo "Finding empty functions..."
grep -A2 -B1 "def[p]\?\s\+.*do$" lib/**/*.ex 2>/dev/null | \
  grep -B1 -A1 "^\s*\(nil\|:ok\|{:ok, nil}\|{:error, :not_implemented}\)$" > /tmp/dead_code_analysis/empty_functions.txt || true

# 4. Find test-only modules
echo "Finding test helper modules..."
find lib -name "*_test_helper.ex" -o -name "*_test_support.ex" > /tmp/dead_code_analysis/test_helpers.txt || true

# 5. Look for specific dead code patterns
echo "Finding specific patterns..."

# Not implemented functions
grep -r "{:error, :not_implemented}" lib/ --include="*.ex" > /tmp/dead_code_analysis/not_implemented.txt || true

# Raise not implemented
grep -r "raise.*not.*implemented" lib/ --include="*.ex" -i > /tmp/dead_code_analysis/raise_not_implemented.txt || true

# Functions that just return hardcoded values
grep -r "def[p]\?\s\+.*do\s*\n\s*\[\]\s*\n\s*end" lib/ --include="*.ex" > /tmp/dead_code_analysis/return_empty_list.txt || true

# 6. Find modules that might be obsolete
echo "Finding potentially obsolete modules..."
for file in lib/**/*_old.ex lib/**/*_backup.ex lib/**/*_deprecated.ex lib/**/*_legacy.ex; do
  [ -f "$file" ] && echo "$file" >> /tmp/dead_code_analysis/obsolete_modules.txt
done

# Generate summary
echo ""
echo "=== Dead Code Analysis Summary ==="
echo "TODO/FIXME markers: $(wc -l < /tmp/dead_code_analysis/todo_markers.txt 2>/dev/null || echo 0)"
echo "Commented functions: $(wc -l < /tmp/dead_code_analysis/commented_functions.txt 2>/dev/null || echo 0)"
echo "Empty functions: $(wc -l < /tmp/dead_code_analysis/empty_functions.txt 2>/dev/null || echo 0)"
echo "Test helpers in lib: $(wc -l < /tmp/dead_code_analysis/test_helpers.txt 2>/dev/null || echo 0)"
echo "Not implemented: $(wc -l < /tmp/dead_code_analysis/not_implemented.txt 2>/dev/null || echo 0)"
echo "Raise not implemented: $(wc -l < /tmp/dead_code_analysis/raise_not_implemented.txt 2>/dev/null || echo 0)"
echo "Return empty list: $(wc -l < /tmp/dead_code_analysis/return_empty_list.txt 2>/dev/null || echo 0)"
echo "Obsolete modules: $(wc -l < /tmp/dead_code_analysis/obsolete_modules.txt 2>/dev/null || echo 0)"

# Show some examples
if [ -s /tmp/dead_code_analysis/todo_markers.txt ]; then
  echo ""
  echo "Sample TODO markers:"
  head -5 /tmp/dead_code_analysis/todo_markers.txt
fi

if [ -s /tmp/dead_code_analysis/not_implemented.txt ]; then
  echo ""
  echo "Sample not implemented functions:"
  head -5 /tmp/dead_code_analysis/not_implemented.txt
fi

echo ""
echo "Full results saved to /tmp/dead_code_analysis/"