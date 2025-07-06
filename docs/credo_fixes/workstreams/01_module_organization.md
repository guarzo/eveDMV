# Workstream 1: Module Organization Fixes

## Overview
- **Total Errors**: 380+ errors (41% of all errors)
- **Complexity**: LOW - Mostly automated fixes
- **Impact**: Immediate 41% error reduction
- **Time Estimate**: 2-3 hours with automation

## Error Types to Fix

### 1. Alias Alphabetization (~200 errors)
```elixir
# INCORRECT
alias EveDmv.Repo
alias EveDmv.Api
alias EveDmv.Result

# CORRECT  
alias EveDmv.Api
alias EveDmv.Repo
alias EveDmv.Result
```

### 2. Import/Alias/Require Ordering (~100 errors)
```elixir
# INCORRECT
require Logger
alias EveDmv.Api
import Ecto.Query

# CORRECT
import Ecto.Query
alias EveDmv.Api  
require Logger
```

### 3. Module Attribute Ordering (~50 errors)
```elixir
# INCORRECT
@behaviour SomeBehaviour
@moduledoc "Documentation"
defstruct [:field]
@type t :: %__MODULE__{}

# CORRECT
@moduledoc "Documentation"
@behaviour SomeBehaviour
@type t :: %__MODULE__{}
defstruct [:field]
```

### 4. Grouped Alias Expansion (~30 errors)
```elixir
# INCORRECT
alias EveDmv.{Api, Repo, Result}

# CORRECT
alias EveDmv.Api
alias EveDmv.Repo
alias EveDmv.Result
```

## Implementation Instructions

### Step 1: Run Automated Fixer Script
```elixir
# Save as fix_module_organization.exs
defmodule ModuleOrganizationFixer do
  def fix_file(file_path) do
    content = File.read!(file_path)
    
    # Extract different sections
    {moduledoc, rest} = extract_moduledoc(content)
    {behaviours, rest} = extract_behaviours(rest)
    {uses, rest} = extract_uses(rest)
    {imports, rest} = extract_imports(rest)
    {aliases, rest} = extract_aliases(rest)
    {requires, rest} = extract_requires(rest)
    {types, rest} = extract_types(rest)
    {defstruct, rest} = extract_defstruct(rest)
    
    # Fix aliases
    sorted_aliases = aliases |> expand_grouped_aliases() |> sort_alphabetically()
    
    # Reconstruct in correct order
    fixed_content = [
      moduledoc,
      behaviours,
      uses,
      imports,
      sorted_aliases,
      requires,
      types,
      defstruct,
      rest
    ] |> Enum.filter(&(&1 != "")) |> Enum.join("\n")
    
    File.write!(file_path, fixed_content)
  end
  
  # Helper functions to extract and process each section...
end

# Run on all Elixir files
Path.wildcard("lib/**/*.ex")
|> Enum.each(&ModuleOrganizationFixer.fix_file/1)
```

### Step 2: Manual Review Checklist
After running the automated fixer:
1. Verify module compilation: `mix compile --force`
2. Check for any semantic changes in module loading
3. Review complex modules with multiple behaviours
4. Ensure no functional imports were reordered incorrectly

### Step 3: File-by-File Approach
Process files in this order for maximum impact:

#### High Priority (50+ errors each)
- `lib/eve_dmv/contexts/surveillance/domain/surveillance_profile.ex`
- `lib/eve_dmv/contexts/player_profile/analyzers/combat_stats_analyzer.ex`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex`
- `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex`

#### Medium Priority (20-50 errors each)
- All files in `lib/eve_dmv/contexts/*/analyzers/`
- All files in `lib/eve_dmv/intelligence/analyzers/`
- All files in `lib/eve_dmv_web/live/`

#### Low Priority (< 20 errors each)
- Infrastructure modules
- Test files
- Support modules

## Expected Results

### Before
```
Checking 398 source files...
┃ [R] ↗ The alias `EveDmv.Repo` is not alphabetically ordered
┃ [R] ↗ alias must appear before require
┃ [R] ↗ Avoid grouping aliases in '{ ... }'
Total: 380+ module organization errors
```

### After
```
Checking 398 source files...
Module organization: ✓ All clean
Remaining errors: ~550 (from 930)
```

## Success Criteria
1. Zero alias alphabetization warnings
2. Zero import/alias/require ordering warnings  
3. Zero grouped alias warnings
4. Zero module attribute ordering warnings
5. All modules compile successfully
6. All tests pass

## Common Pitfalls to Avoid
1. **Don't reorder function-dependent imports** - Some imports define macros used later
2. **Preserve use statements order** - They often have dependencies
3. **Keep related aliases together** - Even if not perfectly alphabetical, logical grouping matters
4. **Watch for compile-time dependencies** - Some aliases are used in module attributes

## Verification Commands
```bash
# Check this workstream's progress
mix credo --strict | grep -E "(alphabetically|must appear before|grouping aliases|defstruct)"

# Ensure nothing broke
mix compile --warnings-as-errors
mix test
```

This workstream provides the highest impact for the least effort - a 41% error reduction with mostly automated fixes.