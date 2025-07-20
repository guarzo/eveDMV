#!/bin/bash

# Setup Pre-commit Hooks for EVE DMV Quality Standards
# Part of Sprint 22 Quality Standards Implementation

set -e

echo "🔧 Setting up Pre-commit Hooks for EVE DMV"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Check if .pre-commit-config.yaml exists
if [ ! -f ".pre-commit-config.yaml" ]; then
    echo "❌ Error: .pre-commit-config.yaml not found"
    exit 1
fi

echo -e "\n${YELLOW}1. Checking for pre-commit installation...${NC}"

# Check if pre-commit is available via pip
if ! command -v pre-commit >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing pre-commit via pip...${NC}"
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install pre-commit
    elif command -v pip >/dev/null 2>&1; then
        pip install pre-commit
    else
        echo "❌ Error: pip not found. Please install Python and pip first."
        echo "Alternative: Install pre-commit manually or use conda/homebrew"
        exit 1
    fi
else
    echo -e "${GREEN}✓ pre-commit already installed${NC}"
fi

echo -e "\n${YELLOW}2. Installing git hooks...${NC}"
if pre-commit install; then
    echo -e "${GREEN}✓ Pre-commit hooks installed successfully${NC}"
else
    echo "⚠️  Pre-commit install failed, trying manual setup"
    
    # Manual git hook setup as fallback
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Manual pre-commit hook for EVE DMV Quality Standards

echo "Running quality checks..."

# Run mix format
echo "Formatting code..."
mix format

# Run Credo checks
echo "Running Credo analysis..."
if ! mix credo --strict; then
    echo "❌ Credo issues found. Fix them before committing."
    exit 1
fi

echo "✅ Quality checks passed"
EOF
    
    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✓ Manual pre-commit hook installed${NC}"
fi

echo -e "\n${YELLOW}3. Testing pre-commit setup...${NC}"
if command -v pre-commit >/dev/null 2>&1; then
    if pre-commit run --all-files 2>/dev/null; then
        echo -e "${GREEN}✓ Pre-commit hooks working correctly${NC}"
    else
        echo -e "${YELLOW}⚠️  Pre-commit check failed (may be due to existing issues)${NC}"
        echo "This is expected during Sprint 22 quality improvements"
    fi
else
    echo -e "${YELLOW}⚠️  Using manual git hook (pre-commit not available)${NC}"
fi

echo -e "\n${GREEN}✅ Pre-commit setup complete!${NC}"
echo ""
echo -e "${BLUE}Usage:${NC}"
echo "• Hooks will run automatically on 'git commit'"
echo "• Run manually with: pre-commit run --all-files"
echo "• Skip hooks with: git commit --no-verify (use sparingly)"
echo ""
echo -e "${YELLOW}Quality Standards Enforced:${NC}"
echo "• Code formatting (mix format)"
echo "• Style consistency (mix credo)"
echo "• Trailing whitespace removal"
echo "• Large number formatting"