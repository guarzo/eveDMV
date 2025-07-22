#!/bin/bash
# Workstream A: Database & Infrastructure Fix Script
# Sprint 23: Parsing Cleanup & Quality Completion
# 
# CRITICAL: Fix 9 unparseable files + compilation warnings
# Database/infrastructure changes affect ALL other systems

set -e

echo "🏗️  WORKSTREAM A: Database & Infrastructure Parsing Fix"
echo "Target: 9 unparseable files + ~10 compilation warnings"
echo "CRITICAL: Database systems affect all workstreams"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Workstream A assigned files
WS_A_FILES=(
    "lib/eve_dmv/database/cache_hash_manager.ex"
    "lib/eve_dmv/database/cache_invalidator.ex"  
    "lib/eve_dmv/database/cache_warmer.ex"
    "lib/eve_dmv/database/materialized_view_manager/view_query_service.ex"
    "lib/eve_dmv/database/partition_automation.ex"
    "lib/eve_dmv/database/repository.ex"
    "lib/eve_dmv/domain_events.ex"
    "lib/eve_dmv/eve/esi_request_client.ex"
    "lib/eve_dmv/logging/structured_formatter.ex"
)

# Safety functions
check_parsing() {
    echo "🔍 Checking WS-A file parsing status..."
    unparseable=0
    for file in "${WS_A_FILES[@]}"; do
        if ! mix credo "$file" >/dev/null 2>&1; then
            unparseable=$((unparseable + 1))
        fi
    done
    echo "WS-A unparseable files: $unparseable / ${#WS_A_FILES[@]}"
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

count_ws_a_warnings() {
    # Count warnings in WS-A specific files
    warnings=0
    for file in "${WS_A_FILES[@]}"; do
        file_warnings=$(mix compile "$file" 2>&1 | grep "warning:" | wc -l || echo "0")
        warnings=$((warnings + file_warnings))
    done
    echo "WS-A compilation warnings: $warnings"
    return $warnings
}

test_database_functionality() {
    echo "🗄️  Testing database functionality..."
    
    # Test basic database connectivity
    if mix run -e "
        case EveDmv.Repo.query('SELECT 1', []) do
            {:ok, _} -> IO.puts('✅ Database connectivity working')
            _ -> IO.puts('❌ Database broken'); System.halt(1)
        end
    " >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Database connectivity functional${NC}"
    else
        echo -e "${RED}❌ Database connectivity broken${NC}"
        return 1
    fi
    
    # Test repository loading
    if mix run -e "
        try do
            Code.ensure_loaded!(EveDmv.Repo)
            IO.puts('✅ Repository module loadable')
        rescue
            _ -> IO.puts('❌ Repository broken'); System.halt(1)
        end
    " >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Repository module functional${NC}"
    else
        echo -e "${RED}❌ Repository module broken${NC}"
        return 1
    fi
    
    return 0
}

# Show current status
show_status() {
    echo "📊 WORKSTREAM A STATUS"
    echo "====================="
    
    check_parsing
    unparseable=$?
    
    count_ws_a_warnings
    warnings=$?
    
    echo ""
    echo "Progress:"
    echo "• Unparseable files: $unparseable / ${#WS_A_FILES[@]} (target: 0)"
    echo "• Compilation warnings: $warnings (target: 0)"
    
    # Show which files still need work
    if [ $unparseable -gt 0 ]; then
        echo ""
        echo "Files needing parsing fixes:"
        for file in "${WS_A_FILES[@]}"; do
            if ! mix credo "$file" >/dev/null 2>&1; then
                echo "  ❌ $file"
            else
                echo "  ✅ $file"
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
    
    echo ""
    echo "⚠️  MANUAL ACTION REQUIRED:"
    echo "1. Open $file in your editor"
    echo "2. Look for common parsing errors:"
    echo "   - Missing 'end' keywords"
    echo "   - Unclosed parentheses/brackets" 
    echo "   - Malformed pipe operators |>"
    echo "   - Broken 'with' statements"
    echo "3. Fix parsing errors first, then warnings"
    echo "4. Run: ./scripts/ws_a_database_infrastructure_fix.sh validate-file $file"
    echo "5. Commit: git add $file && git commit -m 'fix: parsing/warnings in $(basename $file)'"
    echo ""
    echo "🛡️  CRITICAL: Test database functionality after changes!"
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
    
    # Test database functionality (critical for WS-A)
    if test_database_functionality; then
        echo -e "${GREEN}✅ Database functionality intact${NC}"
    else
        echo -e "${RED}❌ Database functionality broken${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 FILE VALIDATION PASSED${NC}"
    return 0
}

# Full workstream validation
validate() {
    echo "🔍 WORKSTREAM A FULL VALIDATION"
    echo ""
    
    check_parsing
    unparseable=$?
    
    count_ws_a_warnings
    warnings=$?
    
    if ! check_compilation; then
        echo -e "${RED}❌ COMPILATION FAILED${NC}"
        return 1
    fi
    
    if ! test_database_functionality; then
        echo -e "${RED}❌ DATABASE FUNCTIONALITY BROKEN${NC}"
        return 1
    fi
    
    echo ""
    echo "📊 WORKSTREAM A RESULTS:"
    echo "Unparseable files: $unparseable (target: 0)"
    echo "Compilation warnings: $warnings (target: 0)"
    
    if [ $unparseable -eq 0 ] && [ $warnings -eq 0 ]; then
        echo -e "${GREEN}🏆 WORKSTREAM A COMPLETE!${NC}"
        echo -e "${GREEN}✅ All files parseable${NC}"
        echo -e "${GREEN}✅ Zero compilation warnings${NC}"
        echo -e "${GREEN}✅ Database functionality intact${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  WORKSTREAM A INCOMPLETE${NC}"
        [ $unparseable -gt 0 ] && echo "• $unparseable files still need parsing fixes"
        [ $warnings -gt 0 ] && echo "• $warnings compilation warnings remain"
        return 1
    fi
}

# List assigned files
list_files() {
    echo "📋 WORKSTREAM A ASSIGNED FILES"
    echo "=============================="
    for i in "${!WS_A_FILES[@]}"; do
        local file="${WS_A_FILES[$i]}"
        local num=$((i + 1))
        
        # Check status
        if mix credo "$file" >/dev/null 2>&1; then
            echo "$num. ✅ $file"
        else
            echo "$num. ❌ $file (parsing errors)"
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
    "test-db")
        test_database_functionality
        ;;
    *)
        echo "🚀 Workstream A: Database & Infrastructure Fix"
        echo ""
        echo "Available commands:"
        echo "  status        - Show current progress"
        echo "  validate      - Full workstream validation"  
        echo "  validate-file <file> - Validate specific file"
        echo "  fix-file <file>      - Get help fixing specific file"
        echo "  list          - List all assigned files"
        echo "  test-db       - Test database functionality"
        echo ""
        echo "Daily workflow:"
        echo "1. ./scripts/ws_a_database_infrastructure_fix.sh list"
        echo "2. ./scripts/ws_a_database_infrastructure_fix.sh fix-file <unparseable-file>"
        echo "3. [Manual fixes in editor]"  
        echo "4. ./scripts/ws_a_database_infrastructure_fix.sh validate-file <file>"
        echo "5. [Commit successful fix]"
        echo "6. Repeat until all files fixed"
        ;;
esac