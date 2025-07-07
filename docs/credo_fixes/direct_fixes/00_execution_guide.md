# Direct Fix Execution Guide - NO SCRIPTS

## WHY THIS APPROACH

The previous script-based workstreams failed because:
1. Scripts don't actually execute or fail silently
2. Complex regex patterns don't match real code
3. No visibility into what's actually being fixed

This approach provides **exact line-by-line fixes** that can be manually verified.

## EXECUTION ORDER

Work through these documents in order:

1. **01_pipeline_manual_fixes.md** (241 errors)
   - Simple single-function pipeline conversions
   - Just change `x |> func()` to `func(x)`

2. **02_implicit_try_fixes.md** (50 errors)
   - Remove `try do` and `end`, keep the rescue clause
   - Makes code cleaner

3. **03_variable_redeclaration_fixes.md** (70 errors)
   - Rename repeated variables with descriptive names
   - `recommendations` → `initial_recommendations` → `final_recommendations`

4. **04_alias_and_import_fixes.md** (158 errors)
   - Reorder imports: use → alias → require → import
   - Alphabetize aliases

5. **05_remaining_fixes.md** (~100 errors)
   - Number formatting: add underscores
   - @impl annotations: specify behavior
   - Line length: break long lines
   - Misc fixes

## HOW TO WORK EFFICIENTLY

### For Each Document:

1. **Open the document** in one window
2. **Open the target file** in your editor
3. **Use Cmd+L (or Ctrl+G)** to jump to line numbers
4. **Make the exact change** shown
5. **Save after each file** (not each change)
6. **Run `mix compile`** after each file to catch errors

### Time Estimates:

- Pipeline fixes: 30-45 minutes (many similar changes)
- Implicit try: 15-20 minutes (straightforward)
- Variable redeclaration: 20-30 minutes (requires reading context)
- Import ordering: 20-30 minutes (just reordering)
- Remaining fixes: 20-30 minutes (various types)

**Total: ~2-3 hours of focused work**

## VERIFICATION CHECKPOINTS

### After Each Document:

```bash
# Check compilation
mix compile

# Count specific error type (adjust grep pattern)
grep -c "Use a function call when a pipeline" /workspace/credo.txt
```

### After All Documents:

```bash
# Final compilation check
mix compile --warnings-as-errors

# Run tests
mix test

# Check total remaining errors
wc -l /workspace/credo.txt
```

## COMMON PATTERNS TO REMEMBER

### Pipeline Fix:
```elixir
# FROM: value |> Module.function(args)
# TO:   Module.function(value, args)
```

### Implicit Try:
```elixir
# FROM: try do ... rescue ... end
# TO:   ... rescue ...
```

### Variable Renaming:
```elixir
# FROM: x = a; x = b; x = c
# TO:   x1 = a; x2 = b; x3 = c
```

### Import Order:
```elixir
use First
alias Second
require Third  
import Fourth
```

## WHAT SUCCESS LOOKS LIKE

Starting point: **791 errors** in credo.txt

After completing all documents:
- Errors should be **< 50**
- All major categories eliminated
- Clean compilation
- All tests passing

## IF YOU GET STUCK

1. **Compilation error**: Undo the last change, re-read the instruction
2. **Can't find the line**: The file may have been edited; search for the pattern
3. **Pattern doesn't match**: Look for similar code nearby
4. **Tests fail**: The fix might have changed behavior; review the change

## IMPORTANT NOTES

- These are **real line numbers** from the actual credo.txt file
- Make **exactly** the changes shown - don't improvise
- If a line has already been fixed, skip it
- Some files appear multiple times - that's normal

## START NOW

Begin with `01_pipeline_manual_fixes.md` and work systematically through each document. This approach WILL reduce the credo errors because it addresses the actual issues with specific fixes.