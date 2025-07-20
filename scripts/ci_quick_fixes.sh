#!/bin/bash

# CI Quick Fixes - Immediate actions to improve CI
# Run this to apply the most critical fixes

set -e

echo "🚀 Applying Critical CI Fixes"
echo "============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}1. Removing continue-on-error from test job...${NC}"
sed -i '/mix coveralls.json/,+1s/continue-on-error: true/# continue-on-error: true/' .github/workflows/ci.yml
echo -e "${GREEN}✓ Tests will now fail CI on errors${NC}"

echo -e "\n${YELLOW}2. Fixing Dialyzer to report errors...${NC}"
sed -i 's/exit 0/exit 1/' .github/workflows/ci.yml
echo -e "${GREEN}✓ Dialyzer warnings will now fail CI${NC}"

echo -e "\n${YELLOW}3. Making security audit required...${NC}"
sed -i 's/run_check "Security Audit" "mix deps.audit" "false"/run_check "Security Audit" "mix deps.audit" "true"/' scripts/quality_check.sh
echo -e "${GREEN}✓ Security vulnerabilities will now fail CI${NC}"

echo -e "\n${YELLOW}4. Summary of changes:${NC}"
echo "- ✅ Fixed database name to eve_dmv_test"
echo "- ✅ Set coverage threshold to 40%"
echo "- ✅ Enabled all Credo checks"
echo "- ✅ Made tests fail CI on errors"
echo "- ✅ Made Dialyzer fail on warnings"
echo "- ✅ Made security audit required"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Run: ./scripts/fix_tests.sh to identify test failures"
echo "2. Fix failing tests (see docs/CI_IMPLEMENTATION_PLAN.md)"
echo "3. Commit changes with message: 'fix: Enable proper CI quality gates'"

echo -e "\n${GREEN}Quick fixes complete!${NC}"