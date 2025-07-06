# Workstream 5: Quick Style Fixes

## Overview
- **Total Errors**: 100+ errors (10.7% of all errors)
- **Complexity**: LOW - Mostly automated
- **Impact**: Immediate 10.7% error reduction, better consistency
- **Time Estimate**: 1-2 hours (mostly automated)

## Error Types to Fix

### 1. Number Formatting (~40 errors)
```elixir
# INCORRECT
damage_amount = 1000000
isk_value = 50000000
character_id = 98000001

# CORRECT
damage_amount = 1_000_000
isk_value = 50_000_000
character_id = 98_000_001
```

### 2. @impl Annotations (~30 errors)
```elixir
# INCORRECT
@impl true
def handle_call(request, from, state)

# CORRECT  
@impl GenServer
def handle_call(request, from, state)

# OR for custom behaviours
@impl EveDmv.Intelligence.Analyzer
def analyze(data, opts)
```

### 3. Trailing Whitespace (~20 errors)
```elixir
# INCORRECT
def some_function(arg) do·· 
  process(arg)··
end

# CORRECT
def some_function(arg) do
  process(arg)
end
```

### 4. Predicate Function Names (2 errors)
```elixir
# INCORRECT
def is_valid_user(user)
def is_active(character)

# CORRECT
def valid_user?(user)
def active?(character)
```

### 5. Other Style Issues (~8 errors)
- Long lines (>120 characters)
- File endings without newline
- Unnecessary parentheses

## Implementation Instructions

### Step 1: Automated Number Formatting

```bash
# Find and fix large numbers
find lib test -name "*.ex*" -exec sed -i -E '
  # 7+ digit numbers
  s/([^0-9])([0-9])([0-9]{3})([0-9]{3})([0-9]+)([^0-9])/\1\2_\3_\4_\5\6/g
  # 6 digit numbers
  s/([^0-9])([0-9]{3})([0-9]{3})([^0-9])/\1\2_\3\4/g
  # 5 digit numbers  
  s/([^0-9])([0-9]{2})([0-9]{3})([^0-9])/\1\2_\3\4/g
' {} \;

# Common EVE IDs that need formatting
grep -r "90000000\|95000000\|98000000" lib test
```

### Step 2: Fix @impl Annotations

```elixir
# Save as fix_impl_annotations.exs
defmodule ImplFixer do
  @behaviour_patterns %{
    "GenServer" => ["handle_call", "handle_cast", "handle_info", "init"],
    "Supervisor" => ["init"],
    "Phoenix.LiveView" => ["mount", "handle_event", "handle_info"],
    "Ecto.Type" => ["type", "cast", "load", "dump"],
    "Broadway" => ["handle_message", "handle_batch"]
  }
  
  def fix_file(path) do
    content = File.read!(path)
    
    # Detect behaviour/use statements
    behaviour = detect_behaviour(content)
    
    # Replace @impl true with specific behaviour
    fixed = Regex.replace(~r/@impl true/, content, "@impl #{behaviour}")
    
    File.write!(path, fixed)
  end
  
  defp detect_behaviour(content) do
    # Logic to detect which behaviour is implemented
    # based on function names and use/behaviour statements
  end
end
```

### Step 3: Remove Trailing Whitespace

```bash
# Simple and safe
find lib test -name "*.ex*" -exec sed -i 's/[[:space:]]*$//' {} \;

# Add final newlines where missing
find lib test -name "*.ex*" -exec sed -i -e '$a\' {} \;
```

### Step 4: Fix Predicate Names

```bash
# Only 2 instances - fix manually
# lib/eve_dmv/some_module.ex - is_valid_user -> valid_user?
# lib/eve_dmv/other_module.ex - is_active -> active?
```

## File Groups by Error Type

### Number Formatting Hotspots
- `test/**/*_test.exs` - Test data with large IDs
- `lib/eve_dmv/intelligence/ship_database.ex` - Ship IDs and prices
- `lib/eve_dmv_web/live/*_live.ex` - Character/Corporation IDs
- `test/support/factories.ex` - Factory data

### @impl Annotation Locations  
- `lib/eve_dmv/intelligence/analyzers/*.ex` - Custom analyzer behaviour
- `lib/eve_dmv/**/gen_server_modules.ex` - GenServer callbacks
- `lib/eve_dmv_web/live/*.ex` - LiveView callbacks
- `lib/eve_dmv/workers/*.ex` - Worker behaviours

### Common Number Patterns in EVE Online

```elixir
# Character IDs (need underscores)
character_id: 95_325_123  # Not 95325123

# Corporation IDs  
corporation_id: 98_234_567  # Not 98234567

# ISK values
wallet_balance: 1_500_000_000  # Not 1500000000

# Damage amounts
total_damage: 125_000  # Not 125000

# System IDs (5 digits - need underscore)
solar_system_id: 30_002  # Not 30002
```

## Verification Script

```bash
#!/bin/bash
# verify_style_fixes.sh

echo "=== Style Fix Verification ==="

echo -n "Large numbers without underscores: "
grep -r "[^_\.]1[0-9]\{4,\}" lib test | grep -v "_test" | wc -l

echo -n "@impl true occurrences: "
grep -r "@impl true" lib | wc -l

echo -n "Trailing whitespace: "
grep -r "[[:space:]]$" lib test | wc -l

echo -n "is_ predicate functions: "
grep -r "def is_" lib | wc -l

echo -n "Long lines (>120 chars): "
grep -r ".\{121,\}" lib | wc -l
```

## Module-Specific Fixes

### Test Files
```elixir
# Common in test factories
def character_factory do
  %{
    character_id: sequence(:character_id, &(90_000_000 + &1)),
    corporation_id: 98_000_000 + Enum.random(1..999),
    alliance_id: 99_000_000 + Enum.random(1..99)
  }
end
```

### LiveView Files
```elixir
# Common in LiveView assigns
socket
|> assign(:character_id, 95_123_456)
|> assign(:kill_value, 1_500_000_000)
```

### Analyzer Files
```elixir
# Update behavior implementations
@behaviour EveDmv.Intelligence.Analyzer

@impl EveDmv.Intelligence.Analyzer
def analyze(character_id, opts) do
  # ...
end
```

## Expected Results

### Before
```
┃ [R] → Numbers larger than 9999 should be written with underscores.
┃ [R] → `@impl true` should be `@impl MyBehaviour`.
┃ [R] ↗ There should be no trailing white-space at the end of a line.
Total: 100+ style errors
```

### After
```
Style errors: 0
Remaining total errors: ~830 (from 930)
Codebase is more consistent and readable
```

## Success Criteria
1. Zero number formatting warnings
2. Zero @impl true warnings
3. Zero trailing whitespace warnings
4. Zero predicate naming warnings
5. All files properly formatted
6. Tests still pass

## Common Pitfalls

1. **Don't format non-numeric strings** - "User90000" should not become "User90_000"
2. **Preserve version numbers** - "1.12.0" not "1.12_0"
3. **Check regex boundaries** - Ensure numbers in strings aren't affected
4. **Test after formatting** - Some number changes might affect tests

This workstream provides quick wins with minimal risk and improves codebase consistency.