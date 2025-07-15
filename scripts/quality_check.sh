#!/bin/bash

# Quality Check Script for EVE DMV
# This script runs all quality checks in the correct order
# Used by CI and local development to maintain code quality

set -e  # Exit on first error

echo "🔍 Running EVE DMV Quality Checks..."
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error counter
ERRORS=0

# Function to run a check with proper error handling
run_check() {
    local check_name="$1"
    local command="$2"
    local required="${3:-true}"
    
    echo -e "\n${YELLOW}Running $check_name...${NC}"
    
    if eval "$command"; then
        echo -e "${GREEN}✅ $check_name passed${NC}"
    else
        echo -e "${RED}❌ $check_name failed${NC}"
        ERRORS=$((ERRORS + 1))
        
        if [ "$required" = "true" ]; then
            echo -e "${RED}This check is required for quality gate${NC}"
        fi
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure we're in the right directory
if [ ! -f "mix.exs" ]; then
    echo -e "${RED}Error: Please run this script from the project root directory${NC}"
    exit 1
fi

# Check if Mix is available
if ! command_exists mix; then
    echo -e "${RED}Error: Mix is not installed or not in PATH${NC}"
    exit 1
fi

echo "Environment: ${MIX_ENV:-dev}"
echo "Elixir version: $(elixir --version | head -n1)"
echo "Mix version: $(mix --version)"

# ===========================================
# COMPILATION CHECKS
# ===========================================

run_check "Compilation" "mix compile --warnings-as-errors"

# ===========================================
# FORMATTING CHECKS
# ===========================================

run_check "Code Formatting" "mix format --check-formatted"

# ===========================================
# STATIC ANALYSIS
# ===========================================

run_check "Credo Analysis" "mix credo --strict --only readiness,warning"

# ===========================================
# SECURITY CHECKS
# ===========================================

run_check "Security Audit" "mix deps.audit" "false"

# ===========================================
# DEPENDENCY CHECKS
# ===========================================

run_check "Unused Dependencies" "mix deps.clean --unused --unlock" "false"

# ===========================================
# TYPE CHECKING (Optional - can be slow)
# ===========================================

if [ "${SKIP_DIALYZER:-false}" != "true" ]; then
    run_check "Type Checking (Dialyzer)" "timeout 300 mix dialyzer --halt-exit-status" "false"
else
    echo -e "\n${YELLOW}Skipping Dialyzer (SKIP_DIALYZER=true)${NC}"
fi

# ===========================================
# DOCUMENTATION CHECKS
# ===========================================

if [ "${CHECK_DOCS:-false}" = "true" ]; then
    run_check "Documentation" "mix docs --formatter html" "false"
fi

# ===========================================
# TEST SUITE (Optional - can be slow)
# ===========================================

if [ "${RUN_TESTS:-false}" = "true" ]; then
    run_check "Test Suite" "MIX_ENV=test mix test" "false"
fi

# ===========================================
# RESULTS SUMMARY
# ===========================================

echo -e "\n====================================="
echo "🏁 Quality Check Results"
echo "====================================="

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All quality checks passed!${NC}"
    echo "Your code is ready for commit/deployment."
    exit 0
else
    echo -e "${RED}❌ $ERRORS quality check(s) failed${NC}"
    echo "Please fix the issues above before committing."
    exit 1
fi