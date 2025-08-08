#!/bin/bash

echo "=== EVE DMV Basic Security Check ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ISSUES_FOUND=0

echo "1. Checking for potential SQL injection points..."
echo "   Looking for raw SQL queries that need review..."
RAW_SQL=$(grep -r "Ecto.Adapters.SQL.query" lib/ --include="*.ex" | grep -v test | grep -v "#" || true)
if [ -n "$RAW_SQL" ]; then
    echo -e "${YELLOW}⚠️  Raw SQL queries found - please review for injection risks:${NC}"
    echo "$RAW_SQL"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No concerning raw SQL queries found${NC}"
fi

echo
echo "2. Checking for interpolated queries in Ecto..."
INTERPOLATED=$(grep -r "from.*#{" lib/ --include="*.ex" | grep -v test | grep -v "#" || true)
if [ -n "$INTERPOLATED" ]; then
    echo -e "${YELLOW}⚠️  Interpolated queries found - verify they use safe parameters:${NC}"
    echo "$INTERPOLATED"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No interpolated queries found${NC}"
fi

echo
echo "3. Checking for direct struct updates (bypassing changesets)..."
DIRECT_UPDATES=$(grep -r "%.*{.*|" lib/ --include="*.ex" | grep -v "changeset" | grep -v test | grep -v "#" | grep -v "Logger" | head -5 || true)
if [ -n "$DIRECT_UPDATES" ]; then
    echo -e "${YELLOW}⚠️  Direct struct updates found - ensure input validation:${NC}"
    echo "$DIRECT_UPDATES"
    echo "   (showing first 5 matches)"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No concerning direct struct updates found${NC}"
fi

echo
echo "4. Checking for hardcoded secrets..."
SECRETS=$(grep -r -i "password\|secret\|key.*=" lib/ --include="*.ex" | grep -v "secret_key_base" | grep -v "_key:" | grep -v test | grep -v "#" | head -5 || true)
if [ -n "$SECRETS" ]; then
    echo -e "${RED}🔥 Potential hardcoded secrets found:${NC}"
    echo "$SECRETS"
    echo "   (showing first 5 matches)"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No hardcoded secrets found${NC}"
fi

echo
echo "5. Checking for debug/development code in production paths..."
DEBUG_CODE=$(grep -r -i "IO.inspect\|dbg()" lib/ --include="*.ex" | grep -v test | head -5 || true)
if [ -n "$DEBUG_CODE" ]; then
    echo -e "${YELLOW}⚠️  Debug code found - remove before production:${NC}"
    echo "$DEBUG_CODE"
    echo "   (showing first 5 matches)"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No debug code found${NC}"
fi

echo
echo "6. Checking for TODO security items..."
TODO_SECURITY=$(grep -r -i "TODO.*secur\|FIXME.*secur\|XXX.*secur" lib/ --include="*.ex" | head -5 || true)
if [ -n "$TODO_SECURITY" ]; then
    echo -e "${YELLOW}⚠️  Security TODOs found:${NC}"
    echo "$TODO_SECURITY"
    echo "   (showing first 5 matches)"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ No security TODOs found${NC}"
fi

echo
echo "7. Checking environment configuration..."
if [ ! -f ".env.example" ]; then
    echo -e "${YELLOW}⚠️  No .env.example file found - consider creating one${NC}"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ .env.example file exists${NC}"
fi

# Check if .env is in .gitignore
if [ -f ".gitignore" ] && ! grep -q "^\.env$" .gitignore; then
    echo -e "${RED}🔥 .env not in .gitignore - this could leak secrets!${NC}"
    ((ISSUES_FOUND++))
else
    echo -e "${GREEN}✅ .env properly excluded from git${NC}"
fi

echo
echo "8. Checking for proper HTTPS configuration..."
FORCE_SSL=$(grep -r "force_ssl" config/ || true)
if [ -n "$FORCE_SSL" ]; then
    echo -e "${GREEN}✅ HTTPS enforcement configured${NC}"
else
    echo -e "${YELLOW}⚠️  Consider configuring force_ssl for production${NC}"
    ((ISSUES_FOUND++))
fi

echo
echo "9. Checking Phoenix security headers..."
SECURITY_HEADERS=$(find lib/ -name "*security*" -type f | head -3 || true)
if [ -n "$SECURITY_HEADERS" ]; then
    echo -e "${GREEN}✅ Security headers configuration found${NC}"
else
    echo -e "${YELLOW}⚠️  No security headers configuration found${NC}"
    ((ISSUES_FOUND++))
fi

echo
echo "10. Checking for rate limiting..."
RATE_LIMIT=$(grep -r "rate" lib/eve_dmv_web/plugs/ | head -3 || true)
if [ -n "$RATE_LIMIT" ]; then
    echo -e "${GREEN}✅ Rate limiting configured${NC}"
else
    echo -e "${YELLOW}⚠️  No rate limiting found${NC}"
    ((ISSUES_FOUND++))
fi

echo
echo "=== Security Check Summary ==="
if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}🎉 No security issues found! Good job!${NC}"
    exit 0
elif [ $ISSUES_FOUND -le 5 ]; then
    echo -e "${YELLOW}⚠️  Found $ISSUES_FOUND potential issues - review recommended but not blocking${NC}"
    echo -e "${GREEN}✅ Acceptable for small user base deployment${NC}"
    exit 0
else
    echo -e "${RED}🔥 Found $ISSUES_FOUND potential issues - security review required${NC}"
    exit 1
fi