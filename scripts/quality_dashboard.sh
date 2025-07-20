#!/bin/bash

# Quality Dashboard for EVE DMV
# Provides comprehensive quality metrics and progress tracking

set -e

echo "📊 EVE DMV Quality Dashboard"
echo "============================"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get current timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo -e "${CYAN}Report generated: $TIMESTAMP${NC}"

echo -e "\n${YELLOW}🎯 Quality Targets vs Current Status${NC}"
echo "======================================"

# Test Coverage
echo -e "\n${BLUE}📈 Test Coverage:${NC}"
if command -v mix >/dev/null 2>&1; then
    if MIX_ENV=test mix coveralls 2>/dev/null | grep -q "TOTAL"; then
        COVERAGE=$(MIX_ENV=test mix coveralls 2>/dev/null | grep "TOTAL" | awk '{print $NF}' | sed 's/%//')
        TARGET_COVERAGE=70
        if [ "${COVERAGE%.*}" -ge $TARGET_COVERAGE ]; then
            echo -e "  ${GREEN}✅ Current: ${COVERAGE}% (Target: ${TARGET_COVERAGE}%)${NC}"
        elif [ "${COVERAGE%.*}" -ge 40 ]; then
            echo -e "  ${YELLOW}⚠️  Current: ${COVERAGE}% (Target: ${TARGET_COVERAGE}%)${NC}"
        else
            echo -e "  ${RED}❌ Current: ${COVERAGE}% (Target: ${TARGET_COVERAGE}%)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  Coverage data unavailable${NC}"
    fi
else
    echo -e "  ${RED}❌ Mix not available${NC}"
fi

# Credo Issues
echo -e "\n${BLUE}🔍 Code Quality (Credo):${NC}"
if mix credo --format=oneline 2>/dev/null | tail -1 | grep -q "found"; then
    CREDO_OUTPUT=$(mix credo --format=oneline 2>/dev/null | tail -1)
    
    # Extract numbers using different parsing approach
    DESIGN_ISSUES=$(echo "$CREDO_OUTPUT" | grep -o '[0-9]\+ software design' | grep -o '[0-9]\+' || echo "0")
    REFACTOR_ISSUES=$(echo "$CREDO_OUTPUT" | grep -o '[0-9]\+ refactoring' | grep -o '[0-9]\+' || echo "0")
    READABILITY_ISSUES=$(echo "$CREDO_OUTPUT" | grep -o '[0-9]\+ code readability' | grep -o '[0-9]\+' || echo "0")
    WARNING_ISSUES=$(echo "$CREDO_OUTPUT" | grep -o '[0-9]\+ warning' | grep -o '[0-9]\+' || echo "0")
    CONSISTENCY_ISSUES=$(echo "$CREDO_OUTPUT" | grep -o '[0-9]\+ consistency' | grep -o '[0-9]\+' || echo "0")
    
    TOTAL_ISSUES=$((DESIGN_ISSUES + REFACTOR_ISSUES + READABILITY_ISSUES + WARNING_ISSUES + CONSISTENCY_ISSUES))
    
    echo -e "  Total Issues: $TOTAL_ISSUES (Target: ≤50)"
    
    if [ "$WARNING_ISSUES" -gt 0 ]; then
        echo -e "  ${RED}❌ Warnings: $WARNING_ISSUES (Target: 0)${NC}"
    else
        echo -e "  ${GREEN}✅ Warnings: $WARNING_ISSUES${NC}"
    fi
    
    echo -e "  ${PURPLE}Design: $DESIGN_ISSUES${NC}"
    echo -e "  ${BLUE}Refactor: $REFACTOR_ISSUES${NC}"
    echo -e "  ${YELLOW}Readability: $READABILITY_ISSUES${NC}"
    echo -e "  ${CYAN}Consistency: $CONSISTENCY_ISSUES${NC}"
    
    if [ "$TOTAL_ISSUES" -le 50 ]; then
        echo -e "  ${GREEN}✅ Quality: EXCELLENT${NC}"
    elif [ "$TOTAL_ISSUES" -le 200 ]; then
        echo -e "  ${YELLOW}⚠️  Quality: GOOD${NC}"
    elif [ "$TOTAL_ISSUES" -le 500 ]; then
        echo -e "  ${YELLOW}⚠️  Quality: FAIR${NC}"
    else
        echo -e "  ${RED}❌ Quality: NEEDS IMPROVEMENT${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  Credo analysis unavailable${NC}"
fi

# Test Status
echo -e "\n${BLUE}🧪 Test Status:${NC}"
if MIX_ENV=test mix test --exclude integration --exclude performance 2>/dev/null | tail -5 | grep -q "failures"; then
    FAILURES=$(MIX_ENV=test mix test --exclude integration --exclude performance 2>/dev/null | tail -5 | grep "failures" | awk '{print $5}')
    if [ "$FAILURES" = "0" ]; then
        echo -e "  ${GREEN}✅ All tests passing${NC}"
    else
        echo -e "  ${RED}❌ $FAILURES test failures${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  Test status unavailable${NC}"
fi

# File Statistics
echo -e "\n${BLUE}📁 Codebase Statistics:${NC}"
TOTAL_FILES=$(find lib -name "*.ex" | wc -l)
TOTAL_LINES=$(find lib -name "*.ex" -exec cat {} \; | wc -l)
AVG_LINES=$((TOTAL_LINES / TOTAL_FILES))

echo -e "  Total files: $TOTAL_FILES"
echo -e "  Total lines: $TOTAL_LINES"
echo -e "  Average lines/file: $AVG_LINES"

# Large modules
LARGE_MODULES=$(find lib -name "*.ex" -exec wc -l {} \; | awk '$1 > 500' | wc -l)
CRITICAL_MODULES=$(find lib -name "*.ex" -exec wc -l {} \; | awk '$1 > 1000' | wc -l)

if [ "$CRITICAL_MODULES" -gt 0 ]; then
    echo -e "  ${RED}❌ Critical modules (>1000 lines): $CRITICAL_MODULES${NC}"
elif [ "$LARGE_MODULES" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠️  Large modules (>500 lines): $LARGE_MODULES${NC}"
else
    echo -e "  ${GREEN}✅ All modules reasonably sized${NC}"
fi

# TODO Analysis
echo -e "\n${BLUE}📝 TODO Analysis:${NC}"
TODO_COUNT=$(grep -r "TODO" lib --include="*.ex" | wc -l 2>/dev/null || echo "0")
PLACEHOLDER_TODOS=$(grep -r -i "TODO.*implement\|TODO.*placeholder\|TODO.*stub" lib --include="*.ex" | wc -l 2>/dev/null || echo "0")

echo -e "  Total TODOs: $TODO_COUNT"
if [ "$PLACEHOLDER_TODOS" -gt 0 ]; then
    echo -e "  ${RED}❌ Placeholder TODOs: $PLACEHOLDER_TODOS (Critical)${NC}"
else
    echo -e "  ${GREEN}✅ No placeholder TODOs${NC}"
fi

if [ "$TODO_COUNT" -le 25 ]; then
    echo -e "  ${GREEN}✅ TODO count: EXCELLENT${NC}"
elif [ "$TODO_COUNT" -le 50 ]; then
    echo -e "  ${YELLOW}⚠️  TODO count: GOOD${NC}"
else
    echo -e "  ${RED}❌ TODO count: TOO HIGH${NC}"
fi

# Security & Dependencies
echo -e "\n${BLUE}🔒 Security & Dependencies:${NC}"
if mix deps.audit 2>/dev/null | grep -q "No vulnerabilities found"; then
    echo -e "  ${GREEN}✅ No security vulnerabilities${NC}"
else
    VULNS=$(mix deps.audit 2>/dev/null | grep -c "Vulnerability found" || echo "0")
    if [ "$VULNS" -gt 0 ]; then
        echo -e "  ${RED}❌ Security vulnerabilities: $VULNS${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Security scan incomplete${NC}"
    fi
fi

# CI/CD Status
echo -e "\n${BLUE}🚀 CI/CD Health:${NC}"
if [ -f ".github/workflows/ci.yml" ]; then
    echo -e "  ${GREEN}✅ CI pipeline configured${NC}"
    
    # Check for quality gates
    if grep -q "continue-on-error: true" .github/workflows/ci.yml; then
        echo -e "  ${RED}❌ Quality gates disabled (continue-on-error)${NC}"
    else
        echo -e "  ${GREEN}✅ Quality gates enabled${NC}"
    fi
    
    # Check coverage threshold
    if grep -q "minimum_coverage.*40" mix.exs; then
        echo -e "  ${GREEN}✅ Coverage threshold: 40%+${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Coverage threshold not configured${NC}"
    fi
else
    echo -e "  ${RED}❌ No CI pipeline found${NC}"
fi

# Overall Health Score
echo -e "\n${YELLOW}🏆 Overall Quality Score${NC}"
echo "========================"

SCORE=0
MAX_SCORE=100

# Test coverage (0-25 points)
if [ "${COVERAGE:-0}" ]; then
    COVERAGE_SCORE=$((COVERAGE * 25 / 100))
    SCORE=$((SCORE + COVERAGE_SCORE))
    echo -e "Coverage (25): ${COVERAGE_SCORE}/25"
fi

# Credo issues (0-25 points) 
if [ "$TOTAL_ISSUES" -le 50 ]; then
    CREDO_SCORE=25
elif [ "$TOTAL_ISSUES" -le 200 ]; then
    CREDO_SCORE=20
elif [ "$TOTAL_ISSUES" -le 500 ]; then
    CREDO_SCORE=15
else
    CREDO_SCORE=5
fi
SCORE=$((SCORE + CREDO_SCORE))
echo -e "Code Quality (25): ${CREDO_SCORE}/25"

# Test failures (0-20 points)
if [ "${FAILURES:-0}" -eq 0 ]; then
    TEST_SCORE=20
else
    TEST_SCORE=0
fi
SCORE=$((SCORE + TEST_SCORE))
echo -e "Test Status (20): ${TEST_SCORE}/20"

# TODOs (0-15 points)
if [ "$TODO_COUNT" -le 25 ]; then
    TODO_SCORE=15
elif [ "$TODO_COUNT" -le 50 ]; then
    TODO_SCORE=10
else
    TODO_SCORE=5
fi
SCORE=$((SCORE + TODO_SCORE))
echo -e "TODO Hygiene (15): ${TODO_SCORE}/15"

# Module size (0-15 points)
if [ "$CRITICAL_MODULES" -eq 0 ]; then
    MODULE_SCORE=15
elif [ "$LARGE_MODULES" -le 5 ]; then
    MODULE_SCORE=10
else
    MODULE_SCORE=5
fi
SCORE=$((SCORE + MODULE_SCORE))
echo -e "Module Size (15): ${MODULE_SCORE}/15"

echo -e "\n${CYAN}TOTAL SCORE: $SCORE/$MAX_SCORE${NC}"

if [ "$SCORE" -ge 80 ]; then
    echo -e "${GREEN}🏆 EXCELLENT - Production ready!${NC}"
elif [ "$SCORE" -ge 60 ]; then
    echo -e "${YELLOW}👍 GOOD - Minor improvements needed${NC}"
elif [ "$SCORE" -ge 40 ]; then
    echo -e "${YELLOW}⚠️  FAIR - Significant improvements needed${NC}"
else
    echo -e "${RED}❌ POOR - Major quality issues to address${NC}"
fi

# Action Items
echo -e "\n${YELLOW}📋 Recommended Actions${NC}"
echo "======================="

if [ "${FAILURES:-0}" -gt 0 ]; then
    echo -e "🚨 ${RED}CRITICAL: Fix $FAILURES test failures${NC}"
fi

if [ "$PLACEHOLDER_TODOS" -gt 0 ]; then
    echo -e "🚨 ${RED}CRITICAL: Implement $PLACEHOLDER_TODOS placeholder functions${NC}"
fi

if [ "$WARNING_ISSUES" -gt 0 ]; then
    echo -e "🚨 ${RED}CRITICAL: Fix $WARNING_ISSUES Credo warnings${NC}"
fi

if [ "$CRITICAL_MODULES" -gt 0 ]; then
    echo -e "⚠️  ${YELLOW}HIGH: Refactor $CRITICAL_MODULES large modules (>1000 lines)${NC}"
fi

if [ "${COVERAGE:-0}" -lt 70 ]; then
    echo -e "📈 ${BLUE}MEDIUM: Increase test coverage to 70%${NC}"
fi

if [ "$TOTAL_ISSUES" -gt 50 ]; then
    echo -e "🔧 ${BLUE}MEDIUM: Reduce Credo issues to ≤50${NC}"
fi

echo -e "\n${GREEN}✅ Quality dashboard complete!${NC}"
echo ""
echo -e "${YELLOW}💡 Tip: Run this dashboard daily to track progress${NC}"
echo -e "${YELLOW}💡 Add to CI pipeline for automated quality monitoring${NC}"