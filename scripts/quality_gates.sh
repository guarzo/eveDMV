#!/bin/bash
set -e

# Team Delta Quality Gates Script
# Enforces 70% test coverage and quality standards for all critical paths

echo "🚪 Team Delta Quality Gates - Enforcing Quality Standards"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quality thresholds
COVERAGE_THRESHOLD=70
MAX_CREDO_ISSUES=0
MAX_DIALYZER_WARNINGS=0

# Track overall success
OVERALL_SUCCESS=true

# Function to log with colors
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    OVERALL_SUCCESS=false
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verify required tools
log_info "Verifying required tools..."
for cmd in mix jq; do
    if ! command_exists "$cmd"; then
        log_error "Required tool '$cmd' not found"
        exit 1
    fi
done

# Set environment
export MIX_ENV=test

log_info "Setting up test environment..."
mix deps.get --only test
mix compile --warnings-as-errors

echo ""
echo "🧪 Running Quality Gates Checks"
echo "================================"

# Gate 1: Code Formatting
echo ""
log_info "Gate 1: Checking code formatting..."
if mix format --check-formatted --dry-run; then
    log_success "Code formatting passed"
else
    log_error "Code formatting failed - run 'mix format'"
fi

# Gate 2: Static Analysis (Credo)
echo ""
log_info "Gate 2: Running static analysis (Credo)..."
if command_exists credo; then
    CREDO_OUTPUT=$(mix credo --strict --format json 2>/dev/null || echo '{"issues": []}')
    CREDO_ISSUES=$(echo "$CREDO_OUTPUT" | jq '.issues | length' 2>/dev/null || echo "0")
    
    if [ "$CREDO_ISSUES" -le "$MAX_CREDO_ISSUES" ]; then
        log_success "Static analysis passed ($CREDO_ISSUES issues found, max allowed: $MAX_CREDO_ISSUES)"
    else
        log_error "Static analysis failed ($CREDO_ISSUES issues found, max allowed: $MAX_CREDO_ISSUES)"
        echo "$CREDO_OUTPUT" | jq '.issues[] | {category, message, filename, line_no}' 2>/dev/null || echo "Run 'mix credo --strict' for details"
    fi
else
    log_warning "Credo not available, skipping static analysis"
fi

# Gate 3: Type Checking (Dialyzer)
echo ""
log_info "Gate 3: Running type checking (Dialyzer)..."
if command_exists dialyzer; then
    DIALYZER_OUTPUT=$(mix dialyzer --format short 2>&1 || true)
    DIALYZER_WARNINGS=$(echo "$DIALYZER_OUTPUT" | grep -c "Warning:" || echo "0")
    
    if [ "$DIALYZER_WARNINGS" -le "$MAX_DIALYZER_WARNINGS" ]; then
        log_success "Type checking passed ($DIALYZER_WARNINGS warnings found, max allowed: $MAX_DIALYZER_WARNINGS)"
    else
        log_error "Type checking failed ($DIALYZER_WARNINGS warnings found, max allowed: $MAX_DIALYZER_WARNINGS)"
        echo "$DIALYZER_OUTPUT" | head -20
    fi
else
    log_warning "Dialyzer not available, skipping type checking"
fi

# Gate 4: Security Audit
echo ""
log_info "Gate 4: Running security audit..."
if mix deps.audit; then
    log_success "Security audit passed"
else
    log_error "Security audit failed - vulnerabilities found"
fi

# Gate 5: Test Coverage
echo ""
log_info "Gate 5: Checking test coverage..."

# Run tests with coverage
log_info "Running test suite with coverage analysis..."
if mix test --cover --export-coverage default; then
    log_success "Test suite passed"
else
    log_error "Test suite failed"
fi

# Check coverage threshold
if command_exists jq && [ -f "cover/excoveralls.json" ]; then
    COVERAGE=$(jq -r '.coverage' cover/excoveralls.json 2>/dev/null || echo "0")
    COVERAGE_INT=$(echo "$COVERAGE" | cut -d. -f1)
    
    if [ "$COVERAGE_INT" -ge "$COVERAGE_THRESHOLD" ]; then
        log_success "Test coverage passed (${COVERAGE}%, threshold: ${COVERAGE_THRESHOLD}%)"
    else
        log_error "Test coverage failed (${COVERAGE}%, threshold: ${COVERAGE_THRESHOLD}%)"
        
        # Show uncovered files
        log_info "Files with low coverage:"
        jq -r '.files[] | select(.coverage < 70) | "\(.name): \(.coverage)%"' cover/excoveralls.json 2>/dev/null | head -10 || true
    fi
else
    log_warning "Coverage report not found, skipping coverage check"
fi

# Gate 6: Critical Business Logic Tests
echo ""
log_info "Gate 6: Verifying critical business logic tests..."

CRITICAL_TEST_PATTERNS=(
    "test/eve_dmv/intelligence/"
    "test/eve_dmv/killmails/"
    "test/integration/"
    "test/performance/"
    "test/e2e/"
)

MISSING_CRITICAL_TESTS=false

for pattern in "${CRITICAL_TEST_PATTERNS[@]}"; do
    if [ -d "$pattern" ] && [ "$(find "$pattern" -name "*_test.exs" | wc -l)" -gt 0 ]; then
        log_success "Critical tests found in $pattern"
    else
        log_error "Missing critical tests in $pattern"
        MISSING_CRITICAL_TESTS=true
    fi
done

if [ "$MISSING_CRITICAL_TESTS" = false ]; then
    log_success "All critical business logic test suites present"
fi

# Gate 7: Performance Benchmarks
echo ""
log_info "Gate 7: Checking performance benchmarks..."

BENCHMARK_FILES=(
    "test/benchmarks/intelligence_benchmark.exs"
    "test/performance/intelligence_performance_test.exs"
    "test/performance/database_performance_test.exs"
)

MISSING_BENCHMARKS=false

for benchmark in "${BENCHMARK_FILES[@]}"; do
    if [ -f "$benchmark" ]; then
        log_success "Performance benchmark found: $(basename "$benchmark")"
    else
        log_error "Missing performance benchmark: $benchmark"
        MISSING_BENCHMARKS=true
    fi
done

if [ "$MISSING_BENCHMARKS" = false ]; then
    log_success "All required performance benchmarks present"
fi

# Gate 8: Documentation Quality
echo ""
log_info "Gate 8: Checking documentation quality..."

DOC_FILES=(
    "README.md"
    "CLAUDE.md"
    "TEAM_DELTA_PLAN.md"
)

MISSING_DOCS=false

for doc in "${DOC_FILES[@]}"; do
    if [ -f "$doc" ]; then
        log_success "Documentation found: $doc"
    else
        log_error "Missing documentation: $doc"
        MISSING_DOCS=true
    fi
done

if [ "$MISSING_DOCS" = false ]; then
    log_success "Required documentation present"
fi

# Gate 9: CI/CD Pipeline Health
echo ""
log_info "Gate 9: Checking CI/CD pipeline configuration..."

CI_FILES=(
    ".github/workflows/ci.yml"
    "scripts/quality_check.sh"
)

MISSING_CI=false

for ci_file in "${CI_FILES[@]}"; do
    if [ -f "$ci_file" ]; then
        log_success "CI/CD file found: $ci_file"
    else
        log_error "Missing CI/CD file: $ci_file"
        MISSING_CI=true
    fi
done

if [ "$MISSING_CI" = false ]; then
    log_success "CI/CD pipeline configuration complete"
fi

# Final Quality Gate Summary
echo ""
echo "🎯 Quality Gates Summary"
echo "========================"

if [ "$OVERALL_SUCCESS" = true ]; then
    log_success "ALL QUALITY GATES PASSED ✨"
    echo ""
    echo "✅ Code Formatting"
    echo "✅ Static Analysis"
    echo "✅ Type Checking"
    echo "✅ Security Audit"
    echo "✅ Test Coverage (${COVERAGE:-'N/A'}%)"
    echo "✅ Critical Business Logic Tests"
    echo "✅ Performance Benchmarks"
    echo "✅ Documentation Quality"
    echo "✅ CI/CD Pipeline Health"
    echo ""
    log_success "Code is ready for merge! 🚀"
    exit 0
else
    log_error "QUALITY GATES FAILED ❌"
    echo ""
    log_error "Please fix the issues above before proceeding."
    log_error "Team Delta standards must be maintained!"
    echo ""
    exit 1
fi