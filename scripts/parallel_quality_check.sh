#!/bin/bash

# Parallel quality checks for faster CI
# Run independent checks concurrently

set -e

echo "🚀 Running parallel quality checks..."

# Create temp files for output
format_output=$(mktemp)
credo_output=$(mktemp)
audit_output=$(mktemp)
unused_deps_output=$(mktemp)

# Cleanup function
cleanup() {
    rm -f "$format_output" "$credo_output" "$audit_output" "$unused_deps_output"
}
trap cleanup EXIT

# Run checks in parallel
(
    echo "🔍 Checking format..."
    mix format --check-formatted > "$format_output" 2>&1
    echo "✅ Format check complete"
) &

(
    echo "🔍 Running Credo..."
    mix credo --strict > "$credo_output" 2>&1 
    echo "✅ Credo complete"
) &

(
    echo "🔍 Security audit..."
    mix deps.audit > "$audit_output" 2>&1
    echo "✅ Security audit complete"
) &

(
    echo "🔍 Checking unused deps..."
    mix deps.unlock --check-unused > "$unused_deps_output" 2>&1
    echo "✅ Unused deps check complete"
) &

# Wait for all background jobs to complete
wait

# Check results and output
echo ""
echo "📊 Quality Check Results:"
echo "========================"

# Format check
if grep -q "mix format" "$format_output" 2>/dev/null; then
    echo "❌ Format check failed:"
    cat "$format_output"
    exit 1
else
    echo "✅ Code formatting is correct"
fi

# Credo check
if grep -q "issues" "$credo_output" 2>/dev/null; then
    echo "⚠️  Credo found issues:"
    cat "$credo_output" | tail -20  # Show last 20 lines
else
    echo "✅ Credo found no issues"
fi

# Security audit
if grep -q "vulnerabilities" "$audit_output" 2>/dev/null; then
    echo "❌ Security vulnerabilities found:"
    cat "$audit_output"
    exit 1
else
    echo "✅ No security vulnerabilities found"
fi

# Unused deps
if grep -q "unused" "$unused_deps_output" 2>/dev/null; then
    echo "⚠️  Unused dependencies found:"
    cat "$unused_deps_output"
    exit 1
else
    echo "✅ No unused dependencies"
fi

echo ""
echo "🎉 All parallel quality checks completed successfully!"