# Automated Credo Fixes - High Impact Quick Wins

## Overview
- **Total Automated Fixes Available**: 440+ errors (48% of remaining work)
- **Impact**: Can reduce errors from 925 → ~485 with automated tools
- **Time**: Should take 1-2 hours for complete automated cleanup

## Category 1: Trailing Whitespace - 220 Errors

### **Automated Solution**
```bash
# Run Elixir formatter to fix all whitespace issues
mix format

# Alternative: Use editor/IDE automated whitespace removal
# Most editors can "trim trailing whitespace on save"
```

### **Files Affected**
- Every module in the codebase has trailing whitespace
- Particularly heavy in: intelligence modules, database layer, web components
- Test files also affected

### **Expected Result**
- 220 errors eliminated immediately
- ~24% reduction in total error count

## Category 2: Single-Function Pipelines - 223 Errors

### **Pattern to Fix**
```elixir
# Bad - single function pipeline
data |> SomeModule.function()

# Good - direct function call  
SomeModule.function(data)
```

### **Automated Solution**
Can be largely automated with find/replace patterns:
```bash
# Search pattern: (\w+) \|> (\w+\.\w+)\(\)
# Replace: $2($1)

# More complex pattern: (\w+) \|> (\w+\.\w+)\(([^)]*)\)
# Replace: $2($1, $3)
```

### **Files Most Affected**
- Intelligence analyzer modules: 60+ instances
- Database operations: 40+ instances  
- Infrastructure/utilities: 50+ instances
- Web layer: 30+ instances
- Test files: 40+ instances

### **Manual Review Needed**
Some pipelines may need manual review for:
- Complex function arguments
- Nested function calls
- Context-dependent transformations

## Category 3: Alias Organization - 121 Errors

### **Patterns to Fix**
```elixir
# Bad - alias after require
require Logger
alias EveDmv.SomeModule

# Good - alias before require  
alias EveDmv.SomeModule
require Logger

# Bad - grouped aliases
alias EveDmv.{ModuleA, ModuleB}

# Good - individual aliases
alias EveDmv.ModuleA  
alias EveDmv.ModuleB
```

### **Automated Solution**
```bash
# Can be automated with careful regex patterns
# 1. Extract all alias/require/import statements
# 2. Sort: alias first, then require, then import
# 3. Alphabetize within each group
# 4. Expand grouped aliases to individual lines
```

### **Files Affected**
- All major modules with imports
- Particularly: web layer, intelligence engine, context modules

## Implementation Plan

### **Phase 1: Whitespace (Easy Win)**
```bash
mix format
# Result: 925 → 705 errors (24% reduction)
```

### **Phase 2: Pipeline Conversion (Semi-Automated)**
1. **Automated**: Simple single-argument cases (150+ instances)
2. **Manual Review**: Complex cases (70+ instances)
```bash
# Simple automation possible for ~67% of cases
# Result: 705 → ~555 errors (additional 16% reduction)
```

### **Phase 3: Import Organization (Automated)**
```bash
# Custom script to reorganize imports
# Result: 555 → ~434 errors (additional 13% reduction)
```

### **Total Automated Impact**
- **Starting**: 925 errors
- **After automation**: ~434 errors  
- **Reduction**: 53% of all errors eliminated
- **Remaining**: 491 errors requiring manual fixes

## Automated Fix Script Template

```bash
#!/bin/bash
# Credo Automated Fixes

echo "Starting automated credo fixes..."

# Phase 1: Format all files
echo "Phase 1: Fixing whitespace and formatting..."
mix format
echo "✅ Whitespace fixed"

# Phase 2: Simple pipeline fixes (would need custom script)
echo "Phase 2: Converting simple single-function pipelines..."
# find lib -name "*.ex" -exec sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\) |> \([A-Z][a-zA-Z0-9_]*\.[a-z][a-zA-Z0-9_]*\)()/\2(\1)/g' {} \;
echo "⚠️ Pipeline conversion needs manual review"

# Phase 3: Import organization (would need custom script)  
echo "Phase 3: Organizing imports..."
echo "⚠️ Import organization needs custom tooling"

echo "Running credo to check progress..."
mix credo --strict | tail -10
```

## Expected Results After Automation

**Before**: 925 total errors
**After Phase 1**: ~705 errors (format fixes)
**After Phase 2**: ~555 errors (pipeline fixes)  
**After Phase 3**: ~434 errors (import fixes)

**Remaining manual work**: ~434 errors requiring logic review and code refactoring

This automated approach provides maximum impact with minimal manual effort, leaving only the complex logic and architectural issues for manual resolution.