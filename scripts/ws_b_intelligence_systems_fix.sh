#!/bin/bash
# Workstream B: Intelligence Systems Fix Script
# Sprint 23: Parsing Cleanup & Quality Completion
# 
# CRITICAL: Fix 10 unparseable files + compilation warnings
# Intelligence systems are core analysis functionality

set -e

echo "🧠 WORKSTREAM B: Intelligence Systems Parsing Fix"
echo "Target: 10 unparseable files + ~12 compilation warnings"
echo "CRITICAL: Intelligence systems provide core analysis features"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Workstream B assigned files
WS_B_FILES=(
    "lib/eve_dmv/intelligence/advanced_analytics.ex"
    "lib/eve_dmv/intelligence/analyzers/asset_analyzer.ex"
    "lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex"
    "lib/eve_dmv/intelligence/analyzers/member_activity_pattern_analyzer/timezone_analyzer.ex"
    "lib/eve_dmv/intelligence/analyzers/statistical_analyzer.ex"
    "lib/eve_dmv/intelligence/analyzers/wh_vetting_analyzer.ex"
    "lib/eve_dmv/intelligence/cache_cleanup_worker.ex"
    "lib/eve_dmv/intelligence/core/cache_helper.ex"
    "lib/eve_dmv/intelligence/core/supervisor.ex"
    "lib/eve_dmv/intelligence/intelligence_scoring/recruitment_scoring.ex"
)

# Safety functions
check_parsing() {
    echo "🔍 Checking WS-B file parsing status..."
    unparseable=0
    for file in "${WS_B_FILES[@]}"; do
        if ! mix credo "$file" >/dev/null 2>&1; then
            unparseable=$((unparseable + 1))
        fi
    done
    echo "WS-B unparseable files: $unparseable / ${#WS_B_FILES[@]}"
    return $unparseable
}

check_compilation() {
    echo "🔍 Checking compilation status..."
    if ! mix compile --warnings-as-errors >/dev/null 2>&1; then
        echo -e "${RED}❌ COMPILATION FAILED${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ COMPILATION CLEAN${NC}"
    return 0
}

count_ws_b_warnings() {
    # Count warnings in WS-B specific files
    warnings=0
    for file in "${WS_B_FILES[@]}"; do
        if [ -f "$file" ]; then
            file_warnings=$(mix compile "$file" 2>&1 | grep "warning:" | wc -l || echo "0")
            warnings=$((warnings + file_warnings))
        fi
    done
    echo "WS-B compilation warnings: $warnings"
    return $warnings
}

test_intelligence_functionality() {
    echo "🧠 Testing intelligence functionality..."
    
    # Test intelligence module loading
    if mix run -e "
        try do
            # Test various intelligence modules can load
            modules = [
                EveDmv.Intelligence,
                EveDmv.Intelligence.AnalysisScheduler
            ]
            Enum.each(modules, &Code.ensure_loaded!/1)
            IO.puts('✅ Intelligence modules loadable')
        rescue
            error -> IO.puts('❌ Intelligence modules broken: #{inspect(error)}'); System.halt(1)
        end
    " >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Intelligence modules functional${NC}"
    else
        echo -e "${RED}❌ Intelligence modules broken${NC}"
        return 1
    fi
    
    # Test analytics functionality
    if mix run -e "
        try do
            # Test analytics module loading  
            Code.ensure_loaded!(EveDmv.Analytics.BattleDetector)
            IO.puts('✅ Analytics integration working')
        rescue
            error -> IO.puts('❌ Analytics broken: #{inspect(error)}'); System.halt(1)
        end
    " >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Analytics integration functional${NC}"
    else
        echo -e "${RED}❌ Analytics integration broken${NC}"
        return 1
    fi
    
    return 0
}

# Show current status
show_status() {
    echo "📊 WORKSTREAM B STATUS"
    echo "====================="
    
    check_parsing
    unparseable=$?
    
    count_ws_b_warnings
    warnings=$?
    
    echo ""
    echo "Progress:"
    echo "• Unparseable files: $unparseable / ${#WS_B_FILES[@]} (target: 0)"
    echo "• Compilation warnings: $warnings (target: 0)"
    
    # Show which files still need work
    if [ $unparseable -gt 0 ]; then
        echo ""
        echo "Files needing parsing fixes:"
        for file in "${WS_B_FILES[@]}"; do
            if [ -f "$file" ]; then
                if ! mix credo "$file" >/dev/null 2>&1; then
                    echo "  ❌ $file"
                else
                    echo "  ✅ $file"
                fi
            else
                echo "  ⚠️  $file (file not found)"
            fi
        done
    fi
}

# Fix individual file
fix_file() {
    local file="$1"
    
    if [ -z "$file" ]; then
        echo "Usage: fix_file <filepath>"
        return 1
    fi
    
    echo "🔧 FIXING FILE: $file"
    echo ""
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ File not found: $file${NC}"
        return 1
    fi
    
    # Show current parsing status
    if mix credo "$file" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ File already parseable by Credo${NC}"
    else
        echo -e "${RED}❌ File has parsing errors${NC}"
    fi
    
    # Show compilation warnings for this file
    file_warnings=$(mix compile "$file" 2>&1 | grep "warning:" | wc -l || echo "0")
    echo "Compilation warnings in file: $file_warnings"
    
    # Show specific warnings if any
    if [ "$file_warnings" -gt 0 ]; then
        echo ""
        echo "Compilation warnings in $file:"
        mix compile "$file" 2>&1 | grep "warning:" | head -3
    fi
    
    echo ""
    echo "⚠️  MANUAL ACTION REQUIRED:"
    echo "1. Open $file in your editor"
    echo "2. Look for intelligence-specific parsing errors:"
    echo "   - Complex analysis function definitions"
    echo "   - Statistical calculation blocks"
    echo "   - Data processing pipelines"
    echo "   - Supervisor/worker definitions"
    echo "3. Common fixes for intelligence modules:"
    echo "   - Fix broken with/case statements in analyzers"
    echo "   - Fix pipe operators in data processing"
    echo "   - Fix GenServer definitions in supervisors/workers"
    echo "4. Run: ./scripts/ws_b_intelligence_systems_fix.sh validate-file $file"
    echo "5. Commit: git add $file && git commit -m 'fix: parsing/warnings in $(basename $file)'"
    echo ""
    echo "🧠 CRITICAL: Test intelligence functionality after changes!"
}

# Validate individual file
validate_file() {
    local file="$1"
    
    if [ -z "$file" ]; then
        echo "Usage: validate_file <filepath>"
        return 1
    fi
    
    echo "🔍 VALIDATING FILE: $file"
    echo ""
    
    # Test individual file compilation
    if mix compile "$file" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ File compiles successfully${NC}"
    else
        echo -e "${RED}❌ File compilation failed${NC}"
        return 1
    fi
    
    # Test Credo parsing
    if mix credo "$file" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ File parseable by Credo${NC}"
    else
        echo -e "${RED}❌ File still has parsing errors${NC}"
        return 1
    fi
    
    # Check for warnings
    file_warnings=$(mix compile "$file" 2>&1 | grep "warning:" | wc -l || echo "0")
    if [ "$file_warnings" -eq 0 ]; then
        echo -e "${GREEN}✅ No compilation warnings${NC}"
    else
        echo -e "${YELLOW}⚠️  $file_warnings compilation warnings remain${NC}"
    fi
    
    # Test full system compilation
    if check_compilation; then
        echo -e "${GREEN}✅ System compilation clean${NC}"
    else
        echo -e "${RED}❌ System compilation broken${NC}"
        return 1
    fi
    
    # Test intelligence functionality (critical for WS-B)
    if test_intelligence_functionality; then
        echo -e "${GREEN}✅ Intelligence functionality intact${NC}"
    else
        echo -e "${RED}❌ Intelligence functionality broken${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 FILE VALIDATION PASSED${NC}"
    return 0
}

# Full workstream validation
validate() {
    echo "🔍 WORKSTREAM B FULL VALIDATION"
    echo ""
    
    check_parsing
    unparseable=$?
    
    count_ws_b_warnings
    warnings=$?
    
    if ! check_compilation; then
        echo -e "${RED}❌ COMPILATION FAILED${NC}"
        return 1
    fi
    
    if ! test_intelligence_functionality; then
        echo -e "${RED}❌ INTELLIGENCE FUNCTIONALITY BROKEN${NC}"
        return 1
    fi
    
    echo ""
    echo "📊 WORKSTREAM B RESULTS:"
    echo "Unparseable files: $unparseable (target: 0)"
    echo "Compilation warnings: $warnings (target: 0)"
    
    if [ $unparseable -eq 0 ] && [ $warnings -eq 0 ]; then
        echo -e "${GREEN}🏆 WORKSTREAM B COMPLETE!${NC}"
        echo -e "${GREEN}✅ All files parseable${NC}"
        echo -e "${GREEN}✅ Zero compilation warnings${NC}"
        echo -e "${GREEN}✅ Intelligence functionality intact${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  WORKSTREAM B INCOMPLETE${NC}"
        [ $unparseable -gt 0 ] && echo "• $unparseable files still need parsing fixes"
        [ $warnings -gt 0 ] && echo "• $warnings compilation warnings remain"
        return 1
    fi
}

# List assigned files
list_files() {
    echo "📋 WORKSTREAM B ASSIGNED FILES"
    echo "=============================="
    for i in "${!WS_B_FILES[@]}"; do
        local file="${WS_B_FILES[$i]}"
        local num=$((i + 1))
        
        # Check file exists and status
        if [ -f "$file" ]; then
            if mix credo "$file" >/dev/null 2>&1; then
                echo "$num. ✅ $file"
            else
                echo "$num. ❌ $file (parsing errors)"
            fi
        else
            echo "$num. ⚠️  $file (file not found)"
        fi
    done
}

# Main execution
case "${1:-status}" in
    "status")
        show_status
        ;;
    "validate")
        validate
        ;;
    "validate-file")
        validate_file "$2"
        ;;
    "fix-file")
        fix_file "$2"
        ;;
    "list")
        list_files
        ;;
    "test-intelligence")
        test_intelligence_functionality
        ;;
    *)
        echo "🚀 Workstream B: Intelligence Systems Fix"
        echo ""
        echo "Available commands:"
        echo "  status        - Show current progress"
        echo "  validate      - Full workstream validation"  
        echo "  validate-file <file> - Validate specific file"
        echo "  fix-file <file>      - Get help fixing specific file"
        echo "  list          - List all assigned files"
        echo "  test-intelligence    - Test intelligence functionality"
        echo ""
        echo "Daily workflow:"
        echo "1. ./scripts/ws_b_intelligence_systems_fix.sh list"
        echo "2. ./scripts/ws_b_intelligence_systems_fix.sh fix-file <unparseable-file>"
        echo "3. [Manual fixes in editor]"  
        echo "4. ./scripts/ws_b_intelligence_systems_fix.sh validate-file <file>"
        echo "5. [Commit successful fix]"
        echo "6. Repeat until all files fixed"
        ;;
esac