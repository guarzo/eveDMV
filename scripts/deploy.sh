#!/bin/bash

echo "=== EVE DMV Deployment Preparation ==="
echo

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

echo "Step 1: Running security check..."
if ./scripts/security_check.sh; then
    echo -e "${GREEN}✅ Security check passed${NC}"
else
    echo -e "${RED}❌ Security check failed${NC}"
    ((FAILED++))
fi

echo
echo "Step 2: Running tests..."
if MIX_ENV=test mix test --max-failures=5; then
    echo -e "${GREEN}✅ Tests passed${NC}"
else
    echo -e "${RED}❌ Tests failed${NC}"
    ((FAILED++))
fi

echo
echo "Step 3: Checking compilation with warnings as errors..."
if MIX_ENV=prod mix compile --warnings-as-errors; then
    echo -e "${GREEN}✅ Clean compilation${NC}"
else
    echo -e "${RED}❌ Compilation warnings/errors${NC}"
    ((FAILED++))
fi

echo
echo "Step 4: Running code quality checks..."
if mix format --check-formatted; then
    echo -e "${GREEN}✅ Code properly formatted${NC}"
else
    echo -e "${RED}❌ Code formatting issues${NC}"
    ((FAILED++))
fi

echo
echo "Step 5: Checking for unused dependencies..."
if mix deps.unlock --check-unused; then
    echo -e "${GREEN}✅ No unused dependencies${NC}"
else
    echo -e "${YELLOW}⚠️  Unused dependencies found${NC}"
    # Don't fail for this - it's just a warning
fi

echo
echo "Step 6: Building production release..."
if MIX_ENV=prod mix release --overwrite; then
    echo -e "${GREEN}✅ Production release built successfully${NC}"
else
    echo -e "${RED}❌ Production release build failed${NC}"
    ((FAILED++))
fi

echo
echo "Step 7: Checking environment variables..."
if [ -f ".env.example" ]; then
    echo -e "${GREEN}✅ .env.example exists for reference${NC}"
else
    echo -e "${YELLOW}⚠️  No .env.example file found${NC}"
fi

# Check if critical env vars are documented
REQUIRED_VARS=("SECRET_KEY_BASE" "DATABASE_URL" "EVE_SSO_CLIENT_ID" "EVE_SSO_CLIENT_SECRET")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -f ".env.example" ] && grep -q "$var" .env.example; then
        echo -e "  ✅ $var documented in .env.example"
    else
        echo -e "  ${YELLOW}⚠️  $var not in .env.example${NC}"
    fi
done

echo
echo "=== Deployment Summary ==="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All checks passed! Ready for deployment.${NC}"
    echo
    echo "Next steps:"
    echo "1. Set environment variables on production server"
    echo "2. Transfer release: scp _build/prod/rel/eve_dmv/releases/*/eve_dmv.tar.gz user@server:/path/"
    echo "3. Run database migration: ./bin/eve_dmv eval \"EveDmv.Release.migrate()\""
    echo "4. Start application: ./bin/eve_dmv start"
    echo "5. Verify health: curl https://yourdomain.com/health"
    exit 0
else
    echo -e "${RED}❌ $FAILED checks failed. Fix issues before deploying.${NC}"
    exit 1
fi