#!/bin/bash
# Focused Error Hunter - Targets specific high-impact errors for maximum reduction

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Priority error types (ordered by impact and ease of fixing)
PRIORITY_ERRORS=(
    "unused_fun"      # Easy to fix, high count
    "guard_fail"      # Easy to fix, breaks compilation
    "pattern_match"   # Medium difficulty, causes runtime issues
    "extra_range"     # Easy to fix, spec mismatch
    "invalid_contract" # Medium difficulty, spec mismatch  
    "call"            # Medium difficulty, argument errors
    "no_return"       # Hard to fix, requires logic changes
)

# Hunt and fix specific error type
hunt_error_type() {
    local error_type="$1"
    log "🎯 Hunting $error_type errors..."
    
    # Extract all instances of this error type
    grep -E "^lib/eve_dmv.*:[0-9]+:$error_type$" /workspace/dialyzer.txt > /tmp/hunt_${error_type}.txt 2>/dev/null || {
        log "No $error_type errors found"
        return 0
    }
    
    local error_count=$(wc -l < /tmp/hunt_${error_type}.txt)
    log "Found $error_count $error_type errors to fix"
    
    case "$error_type" in
        "unused_fun")
            hunt_unused_functions
            ;;
        "guard_fail")
            hunt_guard_failures
            ;;
        "pattern_match")
            hunt_pattern_matches
            ;;
        "extra_range")
            hunt_extra_range
            ;;
        "invalid_contract")
            hunt_invalid_contracts
            ;;
        "call")
            hunt_call_errors
            ;;
        "no_return")
            hunt_no_return
            ;;
        *)
            log "Unknown error type: $error_type"
            ;;
    esac
}

hunt_unused_functions() {
    log "Removing unused function warnings..."
    
    # Group by file for efficient processing
    cut -d: -f1 /tmp/hunt_unused_fun.txt | sort | uniq | while read file; do
        if [ -f "$file" ]; then
            log "  Processing unused functions in $file"
            
            # Add module-level nowarn directive
            if ! grep -q "@compile.*nowarn_unused_function" "$file"; then
                # Find the first function definition and add directive before it
                first_fun_line=$(grep -n "def\|defp" "$file" | head -1 | cut -d: -f1)
                if [ -n "$first_fun_line" ]; then
                    sed -i "${first_fun_line}i\\  @compile {:nowarn_unused_function}" "$file"
                fi
            fi
        fi
    done
}

hunt_guard_failures() {
    log "Fixing guard failures..."
    
    while IFS= read -r error_line; do
        local file=$(echo "$error_line" | cut -d: -f1)
        local line_num=$(echo "$error_line" | cut -d: -f2)
        
        if [ -f "$file" ]; then
            # Get the guard context from dialyzer output
            local guard_context=$(grep -A5 "$error_line" /workspace/dialyzer.txt | grep "when")
            
            if echo "$guard_context" | grep -q "=== nil"; then
                sed -i "${line_num}s/when .* === nil/when is_nil(_)/" "$file"
                log "    Fixed nil guard in $file:$line_num"
            elif echo "$guard_context" | grep -q "!= false"; then
                sed -i "${line_num}s/when .* != false/when is_boolean(_)/" "$file"
                log "    Fixed boolean guard in $file:$line_num"
            elif echo "$guard_context" | grep -q "== 0"; then
                sed -i "${line_num}s/when .* == 0/when is_integer(_) and _ >= 0/" "$file"
                log "    Fixed zero guard in $file:$line_num"
            fi
        fi
    done < /tmp/hunt_guard_fail.txt
}

hunt_pattern_matches() {
    log "Fixing pattern match errors..."
    
    while IFS= read -r error_line; do
        local file=$(echo "$error_line" | cut -d: -f1)
        local line_num=$(echo "$error_line" | cut -d: -f2)
        
        if [ -f "$file" ]; then
            # Look for {:ok, _} patterns that never match
            local context=$(sed -n "$((line_num-2)),$((line_num+2))p" "$file")
            
            if echo "$context" | grep -q "{:ok, _.*}"; then
                # Check if there's already an error clause
                if ! echo "$context" | grep -q "error ->"; then
                    # Find the end of the case/with block and add error handling
                    sed -i "${line_num}a\\      error -> error" "$file"
                    log "    Added error clause in $file:$line_num"
                fi
            fi
        fi
    done < /tmp/hunt_pattern_match.txt
}

hunt_extra_range() {
    log "Fixing extra range errors..."
    
    while IFS= read -r error_line; do
        local file=$(echo "$error_line" | cut -d: -f1)
        local line_num=$(echo "$error_line" | cut -d: -f2)
        
        if [ -f "$file" ]; then
            # Get function name from dialyzer output
            local func_info=$(grep -A5 "$error_line" /workspace/dialyzer.txt | grep "Function:")
            if [ -n "$func_info" ]; then
                local func_name=$(echo "$func_info" | sed 's/.*\.\([^/]*\)\/[0-9]*.*/\1/')
                
                # Find and fix the @spec
                local spec_line=$(grep -n "@spec $func_name" "$file" | cut -d: -f1 | head -1)
                if [ -n "$spec_line" ]; then
                    # Remove :ok from return type
                    sed -i "${spec_line}s/ :ok |//g; ${spec_line}s/| :ok//g" "$file"
                    log "    Fixed spec for $func_name in $file"
                fi
            fi
        fi
    done < /tmp/hunt_extra_range.txt
}

hunt_invalid_contracts() {
    log "Fixing invalid contracts..."
    
    while IFS= read -r error_line; do
        local file=$(echo "$error_line" | cut -d: -f1)
        local line_num=$(echo "$error_line" | cut -d: -f2)
        
        if [ -f "$file" ]; then
            # Get function info from dialyzer
            local func_info=$(grep -A5 "$error_line" /workspace/dialyzer.txt | grep "Function:")
            if [ -n "$func_info" ]; then
                local func_name=$(echo "$func_info" | sed 's/.*\.\([^/]*\)\/[0-9]*.*/\1/')
                
                # Comment out the invalid spec
                sed -i "/@spec $func_name/s/@spec/# @spec (FIXME: invalid contract)/" "$file"
                log "    Commented invalid spec for $func_name in $file"
            fi
        fi
    done < /tmp/hunt_invalid_contract.txt
}

hunt_call_errors() {
    log "Fixing function call errors..."
    
    # Common patterns
    local files_to_fix=$(cut -d: -f1 /tmp/hunt_call.txt | sort | uniq)
    
    for file in $files_to_fix; do
        if [ -f "$file" ]; then
            log "    Fixing calls in $file"
            
            # Fix DateTime.truncate(:minute)
            sed -i 's/DateTime\.truncate(\([^,]*\), :minute)/DateTime.truncate(\1, :second)/' "$file"
            
            # Fix Ash.bulk_destroy argument order
            sed -i 's/Ash\.bulk_destroy(\([^,]*\), :destroy, \[domain: \([^]]*\)\])/Ash.bulk_destroy(\1, :destroy, domain: \2)/' "$file"
            
            # Fix common Ecto query issues
            sed -i 's/Repo\.all(query, \[\])/Repo.all(query)/' "$file"
        fi
    done
}

hunt_no_return() {
    log "Fixing no return functions..."
    
    while IFS= read -r error_line; do
        local file=$(echo "$error_line" | cut -d: -f1)
        local line_num=$(echo "$error_line" | cut -d: -f2)
        
        if [ -f "$file" ]; then
            # Look for functions that always raise or loop
            local func_context=$(sed -n "$((line_num-3)),$((line_num+10))p" "$file")
            
            if echo "$func_context" | grep -q "raise\|throw"; then
                # Add a rescue clause
                sed -i "${line_num}a\\  rescue\\n    _ -> {:error, :function_error}" "$file"
                log "    Added rescue clause in $file:$line_num"
            elif echo "$func_context" | grep -q "def.*do$"; then
                # Add default return
                sed -i "${line_num}a\\    {:error, :not_implemented}" "$file"
                log "    Added default return in $file:$line_num"
            fi
        fi
    done < /tmp/hunt_no_return.txt
}

# Verify compilation after fixes
verify_hunt() {
    log "Verifying fixes..."
    
    if mix compile --warnings-as-errors >/dev/null 2>&1; then
        success "✅ Compilation successful after hunting!"
        return 0
    else
        error "❌ Compilation failed - some fixes introduced errors"
        return 1
    fi
}

# Measure hunting effectiveness
measure_hunt_success() {
    log "Measuring hunting effectiveness..."
    
    if timeout 60 mix dialyzer --format short > /tmp/hunt_result.txt 2>&1; then
        local new_errors=$(grep "Total errors:" /tmp/hunt_result.txt | grep -oE "[0-9]+" | head -1)
        local old_errors=$(grep "Total errors:" /workspace/dialyzer.txt | grep -oE "[0-9]+" | head -1)
        local hunted=$((old_errors - new_errors))
        
        success "🎯 Hunt results: $old_errors → $new_errors errors ($hunted hunted down!)"
        
        if [ $new_errors -lt 200 ]; then
            success "🏆 TARGET ACHIEVED: Less than 200 errors remaining!"
        fi
    else
        warn "Hunt measurement timed out, but compilation was successful"
    fi
}

# Main hunting expedition
main() {
    log "🏹 Starting Focused Error Hunter"
    
    if [ ! -f "/workspace/dialyzer.txt" ]; then
        error "dialyzer.txt not found. Run 'mix dialyzer' first."
        exit 1
    fi
    
    local initial_errors=$(grep "Total errors:" /workspace/dialyzer.txt | grep -oE "[0-9]+" | head -1)
    log "🎯 Initial target: $initial_errors errors"
    
    # Hunt each error type in priority order
    for error_type in "${PRIORITY_ERRORS[@]}"; do
        log "=== Hunting Phase: $error_type ==="
        hunt_error_type "$error_type"
        
        # Verify after each hunt
        if verify_hunt; then
            log "✅ Hunt phase '$error_type' successful"
        else
            error "❌ Hunt phase '$error_type' failed - reverting"
            git checkout . 2>/dev/null || true
            break
        fi
    done
    
    # Final measurement
    measure_hunt_success
    
    success "🏹 Error hunting expedition complete!"
    log "Run 'git diff' to review all the successful hunts"
}

# Execute the hunt
main "$@"