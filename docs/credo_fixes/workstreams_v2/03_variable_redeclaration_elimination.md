# Workstream 3: Variable Redeclaration Elimination - MANDATORY COMPLETION

## Overview
- **Total Errors**: 70 errors (9% of all issues)
- **Priority**: HIGH - Code clarity and logic improvement
- **Completion Requirement**: MUST reduce to 0 errors
- **Time Estimate**: 2-3 hours with manual review

## MANDATORY SUCCESS CRITERIA
1. **EXACTLY 0 variable redeclaration errors** remaining after completion
2. **All tests must pass** after changes
3. **No compilation errors** introduced
4. **Improved code readability** through descriptive variable names

## Error Pattern
All errors follow: `Variable "X" was declared more than once`

## EXECUTION PROCESS - MANDATORY SYSTEMATIC APPROACH

### Phase 1: Analysis and Detection

```bash
#!/bin/bash
# variable_analysis_mandatory.sh

echo "=== VARIABLE REDECLARATION ANALYSIS ==="

# Extract all variable redeclaration errors with file and line info
grep "Variable.*was declared more than once" /workspace/credo.txt > /tmp/variable_errors.txt

echo "Found $(wc -l < /tmp/variable_errors.txt) variable redeclaration errors"

# Create analysis file
cat > /tmp/variable_analysis.md << 'EOF'
# Variable Redeclaration Analysis

## Files requiring fixes:
EOF

# Extract unique files and error counts
cut -d: -f1 /tmp/variable_errors.txt | sed 's/^\[F\] [↗→] //' | sort | uniq -c | sort -nr >> /tmp/variable_analysis.md

echo ""
echo "Most problematic variables:"
grep -o '"[^"]*"' /tmp/variable_errors.txt | sort | uniq -c | sort -nr | head -10

echo ""
echo "Analysis complete. Starting systematic fixes..."
```

### Phase 2: Systematic Pattern-Based Fixes

```bash
#!/bin/bash
# variable_fix_mandatory.sh

set -e  # Exit on any error

echo "=== MANDATORY VARIABLE REDECLARATION FIXES ==="

# STEP 1: Backup current state
cp -r lib/ lib_backup_variables_$(date +%Y%m%d_%H%M%S)

# STEP 2: Apply systematic fixes for common patterns
echo "Applying systematic fixes..."

# Fix Pattern 1: Accumulator patterns (recommendations, score, factors)
find lib -name "*.ex" -type f | while read file; do
  if grep -q "was declared more than once" /workspace/credo.txt | grep -q "$file"; then
    echo "Fixing accumulator patterns in: $file"
    
    # Create Python script to fix this specific file
    python3 << EOF
import re

def fix_variable_redeclarations(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern 1: recommendations = X; recommendations = Y; recommendations = Z
    # Convert to: initial_recommendations = X; enhanced_recommendations = Y; final_recommendations = Z
    functions = re.findall(r'(def [^d].*?(?=\n  def|\n  defp|\nend|\Z))', content, re.DOTALL)
    
    for func in functions:
        if 'recommendations =' in func:
            lines = func.split('\n')
            rec_assignments = []
            
            for i, line in enumerate(lines):
                if re.match(r'\s*recommendations\s*=', line) and 'recommendations =' in line:
                    rec_assignments.append(i)
            
            if len(rec_assignments) > 1:
                # Apply naming strategy
                replacements = [
                    'initial_recommendations',
                    'enhanced_recommendations', 
                    'tactical_recommendations',
                    'strategic_recommendations',
                    'final_recommendations'
                ]
                
                for j, line_idx in enumerate(rec_assignments):
                    if j < len(replacements):
                        old_line = lines[line_idx]
                        new_line = old_line.replace('recommendations =', f'{replacements[j]} =', 1)
                        lines[line_idx] = new_line
                        
                        # Update references to the variable in subsequent lines
                        if j < len(rec_assignments) - 1:
                            for k in range(line_idx + 1, rec_assignments[j + 1]):
                                if 'recommendations' in lines[k] and 'recommendations =' not in lines[k]:
                                    lines[k] = lines[k].replace('recommendations', replacements[j])
                        else:
                            # Last assignment, update all remaining references
                            for k in range(line_idx + 1, len(lines)):
                                if 'recommendations' in lines[k] and 'recommendations =' not in lines[k]:
                                    lines[k] = lines[k].replace('recommendations', replacements[j])
                
                # Reconstruct function
                new_func = '\n'.join(lines)
                content = content.replace(func, new_func)
    
    # Pattern 2: score = X; score = Y; score = Z  
    functions = re.findall(r'(def [^d].*?(?=\n  def|\n  defp|\nend|\Z))', content, re.DOTALL)
    
    for func in functions:
        if 'score =' in func:
            lines = func.split('\n')
            score_assignments = []
            
            for i, line in enumerate(lines):
                if re.match(r'\s*score\s*=', line) and 'score =' in line:
                    score_assignments.append(i)
            
            if len(score_assignments) > 1:
                replacements = [
                    'base_score',
                    'calculated_score',
                    'adjusted_score', 
                    'weighted_score',
                    'final_score'
                ]
                
                for j, line_idx in enumerate(score_assignments):
                    if j < len(replacements):
                        old_line = lines[line_idx]
                        new_line = old_line.replace('score =', f'{replacements[j]} =', 1)
                        lines[line_idx] = new_line
                        
                        # Update references
                        if j < len(score_assignments) - 1:
                            for k in range(line_idx + 1, score_assignments[j + 1]):
                                if 'score' in lines[k] and 'score =' not in lines[k]:
                                    lines[k] = lines[k].replace('score', replacements[j])
                        else:
                            for k in range(line_idx + 1, len(lines)):
                                if 'score' in lines[k] and 'score =' not in lines[k]:
                                    lines[k] = lines[k].replace('score', replacements[j])
                
                new_func = '\n'.join(lines)
                content = content.replace(func, new_func)
    
    # Pattern 3: factors = X; factors = Y
    functions = re.findall(r'(def [^d].*?(?=\n  def|\n  defp|\nend|\Z))', content, re.DOTALL)
    
    for func in functions:
        if 'factors =' in func:
            lines = func.split('\n')
            factor_assignments = []
            
            for i, line in enumerate(lines):
                if re.match(r'\s*factors\s*=', line) and 'factors =' in line:
                    factor_assignments.append(i)
            
            if len(factor_assignments) > 1:
                replacements = [
                    'base_factors',
                    'risk_factors',
                    'performance_factors',
                    'weighted_factors',
                    'final_factors'
                ]
                
                for j, line_idx in enumerate(factor_assignments):
                    if j < len(replacements):
                        old_line = lines[line_idx]
                        new_line = old_line.replace('factors =', f'{replacements[j]} =', 1)
                        lines[line_idx] = new_line
                        
                        # Update references
                        if j < len(factor_assignments) - 1:
                            for k in range(line_idx + 1, factor_assignments[j + 1]):
                                if 'factors' in lines[k] and 'factors =' not in lines[k]:
                                    lines[k] = lines[k].replace('factors', replacements[j])
                        else:
                            for k in range(line_idx + 1, len(lines)):
                                if 'factors' in lines[k] and 'factors =' not in lines[k]:
                                    lines[k] = lines[k].replace('factors', replacements[j])
                
                new_func = '\n'.join(lines)
                content = content.replace(func, new_func)
    
    # Only write if content changed
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed variable redeclarations in: {filepath}")

fix_variable_redeclarations('$file')
EOF
  fi
done

# STEP 3: MANDATORY VERIFICATION
echo "Checking compilation..."
if ! mix compile --warnings-as-errors; then
  echo "COMPILATION FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_variables_* lib/
  exit 1
fi

echo "Running tests..."
if ! mix test --max-failures 1; then
  echo "TESTS FAILED - RESTORING BACKUP"  
  rm -rf lib/
  mv lib_backup_variables_* lib/
  exit 1
fi

# STEP 4: MANDATORY SUCCESS VERIFICATION
mix credo --strict > /tmp/credo_after_variables.txt
REMAINING_ERRORS=$(grep -c "Variable.*was declared more than once" /tmp/credo_after_variables.txt 2>/dev/null || echo "0")
echo "Remaining variable redeclaration errors: $REMAINING_ERRORS"

if [ "$REMAINING_ERRORS" -gt 0 ]; then
  echo "FAILURE: $REMAINING_ERRORS variable redeclaration errors still remain"
  echo "Remaining errors require manual review:"
  grep "Variable.*was declared more than once" /tmp/credo_after_variables.txt | head -10
  
  echo "Creating manual fix instructions..."
  cat > /tmp/manual_variable_fixes.md << 'EOF'
# Manual Variable Fixes Required

For each remaining error:
1. Open the file and locate the function
2. Identify the pattern (accumulator, conditional building, state update)
3. Apply appropriate naming strategy:
   - Accumulator: base_X, enhanced_X, final_X
   - Conditional: initial_X, conditional_X, result_X  
   - State: current_state, updated_state, new_state
4. Update all references to use the new names
5. Verify tests still pass

EOF
  
  exit 1
else
  echo "SUCCESS: All variable redeclaration errors eliminated"
  rm -rf lib_backup_variables_*
fi

echo "=== VARIABLE REDECLARATION ELIMINATION COMPLETE ==="
```

## HIGH-IMPACT FILES TO PROCESS

Based on error analysis, these files have multiple variable redeclarations:
- `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex`
- `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex`
- `lib/eve_dmv/contexts/corporation_analysis/formatters/member_activity_display_formatter.ex`
- `lib/eve_dmv/contexts/fleet_operations/analyzers/pilot_analyzer.ex`
- `lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex`

## EXECUTION INSTRUCTIONS - MUST FOLLOW EXACTLY

1. **RUN analysis**: `chmod +x variable_analysis_mandatory.sh && ./variable_analysis_mandatory.sh`
2. **RUN fixes**: `chmod +x variable_fix_mandatory.sh && ./variable_fix_mandatory.sh`
3. **VERIFY**: `mix credo --strict | grep -c "Variable.*was declared more than once" || echo "0"`
4. **CONFIRM**: Result MUST be 0

## TRANSFORMATION EXAMPLES

### Before (Variable Redeclaration)
```elixir
def generate_recommendations(data) do
  recommendations = initial_analysis(data)
  recommendations = add_tactical_recommendations(recommendations, data)
  recommendations = add_strategic_recommendations(recommendations, data)
  recommendations = finalize_recommendations(recommendations)
  recommendations
end
```

### After (Descriptive Names)
```elixir
def generate_recommendations(data) do
  initial_recommendations = initial_analysis(data)
  tactical_recommendations = add_tactical_recommendations(initial_recommendations, data)
  strategic_recommendations = add_strategic_recommendations(tactical_recommendations, data)
  final_recommendations = finalize_recommendations(strategic_recommendations)
  final_recommendations
end
```

## MANUAL REVIEW PROCESS (If Automated Fixes Incomplete)

If any errors remain after automated fixes:

```bash
# Show remaining errors
grep "Variable.*was declared more than once" /workspace/credo.txt | while read error; do
  FILE=$(echo "$error" | cut -d: -f1 | sed 's/^\[F\] [↗→] //')
  LINE=$(echo "$error" | cut -d: -f2)
  VAR=$(echo "$error" | grep -o '"[^"]*"')
  
  echo "Manual fix needed: $FILE:$LINE for variable $VAR"
  
  # Show function context
  grep -n -A 10 -B 5 "$VAR =" "$FILE" | head -20
done
```

This workstream MUST achieve 0 variable redeclaration errors. No exceptions.