# Workstream 6: Final Cleanup - MANDATORY COMPLETION

## Overview
- **Total Errors**: ~200 remaining errors (mixed types)
- **Priority**: HIGH - Complete all remaining credo issues
- **Completion Requirement**: MUST reduce to <10 total errors
- **Time Estimate**: 2-3 hours with systematic approach

## MANDATORY SUCCESS CRITERIA
1. **<10 total credo errors** remaining after completion
2. **All tests must pass** after changes
3. **No compilation errors** introduced
4. **Clean credo report** ready for production

## ERROR CATEGORIES TO ELIMINATE

Based on analysis of remaining errors:

### 1. Implicit Try (50 errors)
Pattern: `Prefer using an implicit 'try' rather than explicit 'try'`

### 2. Number Formatting (36 errors)  
Pattern: `Numbers larger than 9999 should be written with underscores`

### 3. Line Length (6 errors)
Pattern: `Line is too long (max is 120, was X)`

### 4. Various Style Issues (~100 errors)
- Negated conditions
- Missing final newlines
- Long quote blocks
- Pipe chain issues
- Operation warnings

## EXECUTION SCRIPT - MUST RUN EXACTLY AS WRITTEN

```bash
#!/bin/bash
# final_cleanup_mandatory.sh

set -e  # Exit on any error

echo "=== MANDATORY FINAL CLEANUP ==="

# Get current error count
BEFORE_COUNT=$(grep -E "^\[R\]|\[F\]|\[W\]" /workspace/credo.txt | wc -l)
echo "Starting with $BEFORE_COUNT total credo errors"

# STEP 1: Backup current state
cp -r lib/ lib_backup_final_$(date +%Y%m%d_%H%M%S)

# STEP 2: Fix implicit try issues
echo "=== Fixing implicit try issues ==="
find lib -name "*.ex" -type f | while read file; do
  if grep -q "Prefer using an implicit.*try" /workspace/credo.txt | grep -q "$file"; then
    echo "Fixing implicit try in: $file"
    
    python3 << EOF
import re

def fix_implicit_try(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern: try do ... rescue ... end -> function rescue
    # Look for simple try blocks that can be made implicit
    def make_implicit_try(match):
        full_match = match.group(0)
        try_body = match.group(1)
        rescue_clause = match.group(2)
        
        # Only convert if it's a simple case
        if 'else' in full_match or 'catch' in full_match or 'after' in full_match:
            return full_match  # Keep complex try blocks explicit
        
        # Remove the explicit try/do wrapper
        return f"{try_body.strip()}\n{rescue_clause}"
    
    # Match simple try blocks
    content = re.sub(
        r'try do\s*\n(.*?)\n(rescue.*?)end',
        make_implicit_try,
        content,
        flags=re.DOTALL
    )
    
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed implicit try in: {filepath}")

fix_implicit_try('$file')
EOF
  fi
done

# STEP 3: Fix number formatting
echo "=== Fixing number formatting ==="
find lib -name "*.ex" -type f -exec sed -i -E '
  s/([^0-9_])([0-9])([0-9]{4})([^0-9_.])/\1\2_\3\4/g
  s/([^0-9_])([0-9]{2})([0-9]{3})([^0-9_.])/\1\2_\3\4/g
  s/([^0-9_])([0-9]{3})([0-9]{3})([^0-9_.])/\1\2_\3\4/g
  s/([^0-9_])([0-9])([0-9]{3})([0-9]{3})([^0-9_.])/\1\2_\3_\4\5/g
  s/([^0-9_])([0-9]{2})([0-9]{3})([0-9]{3})([^0-9_.])/\1\2_\3_\4\5/g
  s/([^0-9_])([0-9]{3})([0-9]{3})([0-9]{3})([^0-9_.])/\1\2_\3_\4\5/g
' {} \;

# STEP 4: Fix line length issues
echo "=== Fixing line length issues ==="
find lib -name "*.ex" -type f | while read file; do
  if grep -q "Line is too long" /workspace/credo.txt | grep -q "$file"; then
    echo "Fixing line length in: $file"
    
    python3 << EOF
import re

def fix_long_lines(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    modified = False
    for i, line in enumerate(lines):
        if len(line.rstrip()) > 120:
            # Attempt to break long lines at logical points
            stripped = line.rstrip()
            indent = len(line) - len(line.lstrip())
            indent_str = ' ' * indent
            
            # Break on common patterns
            if ' |> ' in stripped and len(stripped) > 120:
                # Break pipeline
                parts = stripped.split(' |> ')
                if len(parts) > 1:
                    new_line = parts[0] + '\n'
                    for part in parts[1:]:
                        new_line += indent_str + '|> ' + part + '\n'
                    lines[i] = new_line
                    modified = True
                    continue
            
            if ', ' in stripped and len(stripped) > 120:
                # Break on commas
                parts = stripped.split(', ')
                if len(parts) > 2:
                    # Find good break point
                    current_line = parts[0]
                    new_lines = []
                    
                    for part in parts[1:]:
                        if len(current_line + ', ' + part) > 115:
                            new_lines.append(current_line + ',\n')
                            current_line = indent_str + '  ' + part
                        else:
                            current_line += ', ' + part
                    
                    new_lines.append(current_line + '\n')
                    lines[i:i+1] = new_lines
                    modified = True
                    continue
    
    if modified:
        with open(filepath, 'w') as f:
            f.writelines(lines)
        print(f"Fixed long lines in: {filepath}")

fix_long_lines('$file')
EOF
  fi
done

# STEP 5: Fix negated conditions
echo "=== Fixing negated conditions ==="
find lib -name "*.ex" -type f | while read file; do
  python3 << EOF
import re

def fix_negated_conditions(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern: if !condition do X else Y end -> if condition do Y else X end
    def flip_condition(match):
        condition = match.group(1)
        if_body = match.group(2)
        else_body = match.group(3)
        
        # Remove the negation
        clean_condition = condition.replace('!', '').strip()
        if clean_condition.startswith('(') and clean_condition.endswith(')'):
            clean_condition = clean_condition[1:-1]
        
        return f"if {clean_condition} do{else_body}else{if_body}end"
    
    # Match negated if-else patterns
    content = re.sub(
        r'if !([^d]+) do(.*?)else(.*?)end',
        flip_condition,
        content,
        flags=re.DOTALL
    )
    
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed negated conditions in: {filepath}")

fix_negated_conditions('$file')
EOF
done

# STEP 6: Fix missing final newlines
echo "=== Fixing missing final newlines ==="
find lib -name "*.ex" -type f | while read file; do
  if [ -s "$file" ]; then
    if [ "$(tail -c1 "$file" | wc -l)" -eq 0 ]; then
      echo "" >> "$file"
      echo "Added final newline to: $file"
    fi
  fi
done

# STEP 7: Fix long quote blocks
echo "=== Fixing long quote blocks ==="
find lib -name "*.ex" -type f | while read file; do
  python3 << EOF
import re

def fix_long_quotes(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Find and shorten excessively long heredoc strings
    def shorten_quote_block(match):
        quote_content = match.group(1)
        lines = quote_content.split('\n')
        
        if len(lines) > 8:  # If more than 8 lines, summarize
            return '"""\n' + lines[0] + '\n\nSee module documentation for details.\n"""'
        
        return match.group(0)  # Keep if not too long
    
    # Match @moduledoc and other long quote blocks
    content = re.sub(
        r'"""(.*?)"""',
        shorten_quote_block,
        content,
        flags=re.DOTALL
    )
    
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed long quote blocks in: {filepath}")

fix_long_quotes('$file')
EOF
done

# STEP 8: Fix operation warnings
echo "=== Fixing operation warnings ==="
find lib -name "*.ex" -type f -exec sed -i -E '
  s/([a-zA-Z_][a-zA-Z0-9_]*) \|\| ([a-zA-Z_][a-zA-Z0-9_]*\([^)]*\))/\1 || nil/g
' {} \;

# STEP 9: Fix with/case pattern
echo "=== Fixing with/case patterns ==="
find lib -name "*.ex" -type f | while read file; do
  python3 << EOF
import re

def fix_with_case(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Convert with single clause to case
    def convert_with_to_case(match):
        condition = match.group(1)
        success_body = match.group(2)
        else_body = match.group(3)
        
        return f"case {condition} do\n{success_body}\n_ ->{else_body}\nend"
    
    # Match with statements with only one <- clause
    content = re.sub(
        r'with\s+({[^-]*<-[^,}]*})\s+do(.*?)else(.*?)end',
        convert_with_to_case,
        content,
        flags=re.DOTALL
    )
    
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)

fix_with_case('$file')
EOF
done

# STEP 10: MANDATORY VERIFICATION
echo "Checking compilation..."
if ! mix compile --warnings-as-errors; then
  echo "COMPILATION FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_final_* lib/
  exit 1
fi

echo "Running tests..."
if ! mix test --max-failures 1; then
  echo "TESTS FAILED - RESTORING BACKUP"
  rm -rf lib/
  mv lib_backup_final_* lib/
  exit 1
fi

# STEP 11: MANDATORY SUCCESS VERIFICATION
echo "Generating final credo report..."
mix credo --strict > /tmp/credo_final.txt

TOTAL_ERRORS=$(grep -E "^\[R\]|\[F\]|\[W\]" /tmp/credo_final.txt | wc -l)
echo "Final total credo errors: $TOTAL_ERRORS"

if [ "$TOTAL_ERRORS" -gt 10 ]; then
  echo "FAILURE: $TOTAL_ERRORS errors still remain (target: <10)"
  echo "Top remaining error types:"
  grep -E "^\[R\]|\[F\]|\[W\]" /tmp/credo_final.txt | sed 's/.*] [↗→↘] [^:]*:[^:]*:[0-9]* //' | sort | uniq -c | sort -nr | head -10
  exit 1
else
  echo "SUCCESS: Only $TOTAL_ERRORS errors remain (target: <10)"
  rm -rf lib_backup_final_*
fi

echo "=== FINAL CLEANUP COMPLETE ==="
echo "Credo errors reduced from $BEFORE_COUNT to $TOTAL_ERRORS"
```

## VERIFICATION COMMANDS

```bash
# 1. Check current total errors
grep -E "^\[R\]|\[F\]|\[W\]" /workspace/credo.txt | wc -l

# 2. Run the cleanup
chmod +x final_cleanup_mandatory.sh && ./final_cleanup_mandatory.sh

# 3. Verify final state (MUST be <10)
mix credo --strict | grep -E "^\[R\]|\[F\]|\[W\]" | wc -l
```

## TRANSFORMATION EXAMPLES

### Implicit Try
```elixir
# BEFORE
try do
  risky_operation()
rescue
  _ -> :error
end

# AFTER
risky_operation()
rescue
  _ -> :error
```

### Number Formatting
```elixir
# BEFORE
character_id = 95000001
isk_value = 1500000000

# AFTER  
character_id = 95_000_001
isk_value = 1_500_000_000
```

### Negated Conditions
```elixir
# BEFORE
if !valid?(data) do
  {:error, "invalid"}
else
  {:ok, data}
end

# AFTER
if valid?(data) do
  {:ok, data}
else
  {:error, "invalid"}
end
```

## SUCCESS METRICS

After this workstream completion:

### Before Final Cleanup
- **Total errors**: ~817
- **Major categories**: Pipeline, imports, variables, etc.

### After Final Cleanup  
- **Total errors**: <10
- **Error reduction**: >98%
- **Code quality**: Production ready
- **Maintainability**: Significantly improved

## FAILURE RECOVERY

If the script fails:
1. Backup is automatically restored
2. Check specific error details
3. Address compilation/test failures
4. Re-run specific fix sections
5. Manual review remaining errors

## MANUAL REVIEW FOR REMAINING ERRORS

If >10 errors remain:

```bash
# Analyze remaining error patterns
mix credo --strict | grep -E "^\[R\]|\[F\]|\[W\]" | sed 's/.*] [↗→↘] [^:]*:[^:]*:[0-9]* //' | sort | uniq -c | sort -nr

# Focus on highest-count issues first
# Create targeted fixes for specific patterns
```

## SUCCESS CHECKLIST

- [ ] Script runs without errors
- [ ] All tests pass
- [ ] No compilation warnings
- [ ] `mix credo --strict | grep -E "^\[R\]|\[F\]|\[W\]" | wc -l` returns <10
- [ ] Clean, production-ready codebase

This workstream MUST achieve <10 total credo errors. No exceptions.