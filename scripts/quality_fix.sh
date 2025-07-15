#!/bin/bash

# Quality Fix Script for EVE DMV
# This script automatically fixes quality issues where possible
# Run this before committing code to reduce quality check failures

set -e  # Exit on first error

echo "🔧 Running EVE DMV Quality Auto-Fixes..."
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run a fix with proper error handling
run_fix() {
    local fix_name="$1"
    local command="$2"
    
    echo -e "\n${YELLOW}Running $fix_name...${NC}"
    
    if eval "$command"; then
        echo -e "${GREEN}✅ $fix_name completed${NC}"
    else
        echo -e "${RED}❌ $fix_name failed${NC}"
        return 1
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

# ===========================================
# COMPILATION FIXES
# ===========================================

run_fix "Compile and check dependencies" "mix deps.get && mix compile"

# ===========================================
# FORMATTING FIXES
# ===========================================

run_fix "Auto-format code" "mix format"

# ===========================================
# DEPENDENCY FIXES
# ===========================================

run_fix "Clean unused dependencies" "mix deps.clean --unused" || true

# ===========================================
# CREDO FIXES
# ===========================================

echo -e "\n${YELLOW}Running Credo auto-fixes...${NC}"
if mix credo --strict --fix 2>/dev/null; then
    echo -e "${GREEN}✅ Credo auto-fixes completed${NC}"
else
    echo -e "${YELLOW}⚠️  Some Credo issues require manual fixing${NC}"
fi

# ===========================================
# GIT HOOKS SETUP (Optional)
# ===========================================

if [ "${SETUP_HOOKS:-false}" = "true" ] && [ -d ".git" ]; then
    echo -e "\n${YELLOW}Setting up Git hooks...${NC}"
    
    # Create pre-commit hook
    mkdir -p .git/hooks
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for EVE DMV
# Runs basic quality checks before allowing commit

echo "Running pre-commit quality checks..."

# Run formatting check
if ! mix format --check-formatted; then
    echo "❌ Code formatting issues found. Run 'mix format' to fix."
    exit 1
fi

# Run basic compilation check
if ! mix compile --warnings-as-errors; then
    echo "❌ Compilation warnings found. Please fix before committing."
    exit 1
fi

# Run Credo for basic issues
if ! mix credo --strict; then
    echo "❌ Credo issues found. Please fix before committing."
    exit 1
fi

echo "✅ Pre-commit checks passed!"
EOF
    
    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✅ Git pre-commit hook installed${NC}"
fi

# ===========================================
# RESULTS SUMMARY
# ===========================================

echo -e "\n========================================"
echo "🏁 Quality Fix Results"
echo "========================================"

echo -e "${GREEN}✅ Auto-fixes completed!${NC}"
echo "Run './scripts/quality_check.sh' to verify all quality checks pass."
echo ""
echo "Next steps:"
echo "1. Review the changes made by auto-fixes"
echo "2. Run quality checks to identify remaining issues"
echo "3. Manually fix any remaining quality issues"
echo "4. Commit your changes"