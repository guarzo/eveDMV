#!/bin/bash

# Quality check script for EVE DMV
# Runs all quality checks that are also run in CI

set -e

echo "🔍 Running EVE DMV Quality Checks"
echo "=================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "\n📋 ${YELLOW}$description${NC}"
    echo "Running: $cmd"
    
    if eval "$cmd"; then
        echo -e "✅ ${GREEN}$description passed${NC}"
        return 0
    else
        echo -e "❌ ${RED}$description failed${NC}"
        return 1
    fi
}

# Track overall success
overall_success=true

# Dependency management
check_command "mix deps.get" "Installing dependencies" || overall_success=false

# Formatting check
check_command "mix format --check-formatted" "Code formatting" || overall_success=false

# Compilation with warnings as errors
check_command "mix compile --warnings-as-errors" "Compilation" || overall_success=false

# Unused dependencies check
check_command "mix deps.unlock --check-unused" "Unused dependencies" || overall_success=false

# Security audit
check_command "mix deps.audit" "Security audit" || overall_success=false

# Credo static analysis
check_command "mix credo --strict" "Static analysis (Credo)" || overall_success=false

# Create PLT directory if it doesn't exist
mkdir -p priv/plts

# Dialyzer type checking
check_command "mix dialyzer" "Type checking (Dialyzer)" || overall_success=false

# Database setup for tests
echo -e "\n📋 ${YELLOW}Setting up test database${NC}"
if MIX_ENV=test mix ecto.create --quiet && MIX_ENV=test mix ecto.migrate --quiet; then
    echo -e "✅ ${GREEN}Test database setup passed${NC}"
else
    echo -e "❌ ${RED}Test database setup failed${NC}"
    overall_success=false
fi

# Run tests with coverage
check_command "MIX_ENV=test mix test --cover" "Tests with coverage" || overall_success=false

# Summary
echo -e "\n🏁 Quality Check Summary"
echo "========================"

if [ "$overall_success" = true ]; then
    echo -e "✅ ${GREEN}All quality checks passed!${NC}"
    exit 0
else
    echo -e "❌ ${RED}Some quality checks failed${NC}"
    echo -e "💡 ${YELLOW}Run 'mix quality.fix' to auto-fix some issues${NC}"
    exit 1
fi