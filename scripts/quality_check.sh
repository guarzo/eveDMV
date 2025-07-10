#!/bin/bash
set -e

# Team Delta Comprehensive Quality Check Script
# Runs all quality gates and generates detailed reports

echo "🔍 Team Delta Quality Check - Comprehensive Analysis"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quality thresholds
COVERAGE_THRESHOLD=70
MAX_CREDO_ISSUES=5
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

check_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "\n📋 ${YELLOW}$description${NC}"
    echo "Running: $cmd"
    
    if eval "$cmd"; then
        log_success "$description passed"
        return 0
    else
        log_error "$description failed"
        return 1
    fi
}

# Create quality reports directory
mkdir -p quality_reports

# Run basic quality checks first
log_info "Running basic quality checks..."

# Dependency management
check_command "mix deps.get" "Installing dependencies" || OVERALL_SUCCESS=false

# Formatting check
check_command "mix format --check-formatted" "Code formatting" || OVERALL_SUCCESS=false

# Compilation with warnings as errors
check_command "mix compile --warnings-as-errors" "Compilation" || OVERALL_SUCCESS=false

# Unused dependencies check
check_command "mix deps.unlock --check-unused" "Unused dependencies" || OVERALL_SUCCESS=false

# Security audit
check_command "mix deps.audit" "Security audit" || OVERALL_SUCCESS=false

# Credo static analysis
check_command "mix credo --strict" "Static analysis (Credo)" || OVERALL_SUCCESS=false

# Create PLT directory if it doesn't exist
mkdir -p priv/plts

# Dialyzer type checking
check_command "mix dialyzer" "Type checking (Dialyzer)" || OVERALL_SUCCESS=false

# Database setup for tests
echo -e "\n📋 ${YELLOW}Setting up test database${NC}"
if MIX_ENV=test mix ecto.create --quiet && MIX_ENV=test mix ecto.migrate --quiet; then
    log_success "Test database setup passed"
else
    log_error "Test database setup failed"
    OVERALL_SUCCESS=false
fi

# Run tests with coverage
check_command "MIX_ENV=test mix test --cover" "Tests with coverage" || OVERALL_SUCCESS=false

# Run comprehensive quality gates if basic checks pass
if [ "$OVERALL_SUCCESS" = true ]; then
    echo ""
    log_info "Running comprehensive Team Delta Quality Gates..."
    if [ -f "./scripts/quality_gates.sh" ]; then
        if ./scripts/quality_gates.sh; then
            log_success "Quality gates passed"
        else
            log_error "Quality gates failed"
        fi
    else
        log_warning "Quality gates script not found, skipping comprehensive gates"
    fi
fi

# Generate quality metrics report if mix is available
echo ""
log_info "Generating quality metrics report..."
if command -v mix >/dev/null 2>&1; then
    # Check if the metrics collector module exists
    if mix run -e "Code.ensure_loaded!(EveDmv.Quality.MetricsCollector)" 2>/dev/null; then
        mix run -e "
        try do
          metrics = EveDmv.Quality.MetricsCollector.collect_metrics()
          report = EveDmv.Quality.MetricsCollector.generate_quality_report(metrics)
          
          # Save JSON report
          File.write!(\"quality_reports/metrics_report.json\", Jason.encode!(report, pretty: true))
          
          # Save HTML report  
          html_report = EveDmv.Quality.MetricsCollector.export_metrics(:html, metrics)
          File.write!(\"quality_reports/metrics_report.html\", html_report)
          
          # Save CSV report
          csv_report = EveDmv.Quality.MetricsCollector.export_metrics(:csv, metrics)
          File.write!(\"quality_reports/metrics_report.csv\", csv_report)
          
          IO.puts(\"Quality Score: #{report.overall_score}/100 (Grade: #{report.grade})\")
          IO.puts(\"Summary: #{report.summary}\")
          
          if length(report.recommendations) > 0 do
            IO.puts(\"\\nRecommendations:\")
            Enum.each(report.recommendations, fn rec -> IO.puts(\"- #{rec}\") end)
          end
        rescue
          e -> IO.puts(\"Error generating metrics: #{inspect(e)}\")
        end
        " && log_success "Quality metrics report generated in quality_reports/"
    else
        log_warning "Quality metrics collector not available, skipping detailed metrics"
    fi
else
    log_warning "Mix not available, skipping detailed metrics collection"
fi

# Run additional quality checks
echo ""
log_info "Running additional quality validations..."

# Check for TODO/FIXME comments in critical files
echo ""
log_info "Scanning for TODO/FIXME items in critical code..."
TODO_COUNT=$(grep -r "TODO\|FIXME" lib/ --include="*.ex" 2>/dev/null | wc -l || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    log_warning "Found $TODO_COUNT TODO/FIXME items in codebase"
    grep -r "TODO\|FIXME" lib/ --include="*.ex" 2>/dev/null | head -5 || true
else
    log_success "No TODO/FIXME items found in critical code"
fi

# Check for hardcoded credentials or secrets
echo ""
log_info "Scanning for potential secrets..."
SECRET_PATTERNS=("password" "secret_key" "api_key" "token" "credential")
SECRET_FOUND=false

for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -r -i "$pattern" lib/ --include="*.ex" 2>/dev/null | grep -v "def\|#" | head -1 >/dev/null 2>&1; then
        log_warning "Potential secret pattern '$pattern' found in code"
        SECRET_FOUND=true
    fi
done

if [ "$SECRET_FOUND" = false ]; then
    log_success "No obvious secrets found in codebase"
fi

# Check test file naming conventions
echo ""
log_info "Validating test file naming conventions..."
if [ -d "test" ]; then
    INVALID_TEST_FILES=$(find test/ -name "*.exs" ! -name "*_test.exs" 2>/dev/null | wc -l || echo "0")
    if [ "$INVALID_TEST_FILES" -gt 0 ]; then
        log_warning "Found $INVALID_TEST_FILES test files not following naming convention"
        find test/ -name "*.exs" ! -name "*_test.exs" 2>/dev/null | head -3 || true
    else
        log_success "All test files follow naming conventions"
    fi
else
    log_warning "No test directory found"
fi

# Check for large files that might need refactoring
echo ""
log_info "Checking for large files that might need refactoring..."
if [ -d "lib" ]; then
    LARGE_FILES=$(find lib/ -name "*.ex" -exec wc -l {} + 2>/dev/null | awk '$1 > 300 {print $2}' | wc -l || echo "0")
    if [ "$LARGE_FILES" -gt 0 ]; then
        log_warning "Found $LARGE_FILES files with >300 lines that might need refactoring"
        find lib/ -name "*.ex" -exec wc -l {} + 2>/dev/null | awk '$1 > 300 {print $1, $2}' | head -3 || true
    else
        log_success "No overly large files detected"
    fi
else
    log_warning "No lib directory found"
fi

# Check mix.exs for proper version constraints
echo ""
log_info "Checking dependency version constraints..."
if [ -f "mix.exs" ] && grep -q "~>" mix.exs; then
    log_success "Using proper version constraints in mix.exs"
else
    log_warning "Consider using ~> version constraints in mix.exs"
fi

# Generate final summary
echo ""
echo "📋 Quality Check Summary"
echo "========================"

if [ -f "quality_reports/metrics_report.json" ]; then
    log_info "Detailed reports available in quality_reports/"
    echo "  - metrics_report.json (machine readable)"
    echo "  - metrics_report.html (human readable)"
    echo "  - metrics_report.csv (spreadsheet format)"
fi

if [ "$OVERALL_SUCCESS" = true ]; then
    log_success "🎉 All quality checks passed! Code meets Team Delta standards."
    echo ""
    echo "Ready for:"
    echo "✅ Code review"
    echo "✅ Merge to main branch"
    echo "✅ Production deployment"
    exit 0
else
    log_error "❌ Quality checks failed. Please address issues above."
    echo ""
    echo "Before merging:"
    echo "🔧 Fix failing quality gates"
    echo "📝 Address code quality issues"
    echo "🧪 Ensure all tests pass"
    echo "📊 Meet coverage requirements"
    exit 1
fi