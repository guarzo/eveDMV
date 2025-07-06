# Workstream 3: Error Handling Modernization

## Overview
- **Total Errors**: 80+ errors (8.6% of all errors)
- **Complexity**: MEDIUM-HIGH - Requires understanding error semantics
- **Impact**: Better error handling, cleaner code, 8.6% error reduction
- **Time Estimate**: 4-5 hours

## Error Type to Fix

### Explicit Try Blocks (~80 errors)
```elixir
# INCORRECT - Explicit try/rescue
def process_data(input) do
  try do
    result = complex_operation(input)
    {:ok, result}
  rescue
    e in RuntimeError -> {:error, e.message}
    _ -> {:error, "Unknown error"}
  end
end

# CORRECT - Implicit error handling
def process_data(input) do
  result = complex_operation(input)
  {:ok, result}
rescue
  e in RuntimeError -> {:error, e.message}
  _ -> {:error, "Unknown error"}
end

# BETTER - Using with statement when appropriate
def process_data(input) do
  with {:ok, validated} <- validate_input(input),
       {:ok, processed} <- complex_operation(validated) do
    {:ok, processed}
  end
end
```

## Implementation Strategy

### Step 1: Categorize Try Blocks by Pattern

#### Pattern A: Simple Rescue (Convert to Implicit)
```elixir
# Files with this pattern:
# - lib/eve_dmv/contexts/*/analyzers/*.ex (20+ instances)
# - lib/eve_dmv/intelligence/analyzers/*.ex (15+ instances)

# BEFORE
def analyze(data) do
  try do
    perform_analysis(data)
  rescue
    _ -> {:error, :analysis_failed}
  end
end

# AFTER  
def analyze(data) do
  perform_analysis(data)
rescue
  _ -> {:error, :analysis_failed}
end
```

#### Pattern B: Try with Multiple Operations (Convert to With)
```elixir
# Files with this pattern:
# - lib/eve_dmv/contexts/*/domain/*.ex (15+ instances)
# - lib/eve_dmv/eve/*.ex (10+ instances)

# BEFORE
def process(input) do
  try do
    step1 = validate(input)
    step2 = transform(step1)
    step3 = persist(step2)
    {:ok, step3}
  rescue
    e -> {:error, e}
  end
end

# AFTER
def process(input) do
  with {:ok, step1} <- safe_validate(input),
       {:ok, step2} <- safe_transform(step1),
       {:ok, step3} <- safe_persist(step2) do
    {:ok, step3}
  end
end

# Where safe_* functions wrap operations in try/rescue
defp safe_validate(input) do
  {:ok, validate(input)}
rescue
  e -> {:error, e}
end
```

#### Pattern C: Complex Error Handling (Keep Explicit but Simplify)
```elixir
# Files with this pattern:
# - lib/eve_dmv/killmails/*.ex (10+ instances)
# - lib/eve_dmv/database/*.ex (10+ instances)

# These may need to stay explicit but can be simplified
```

### Step 2: File-by-File Conversion Guide

#### High Priority Files (5+ try blocks each)
1. `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex`
   - 6 try blocks
   - Mostly Pattern A (simple rescue)
   - Convert to implicit rescue

2. `lib/eve_dmv/contexts/player_profile/analyzers/combat_stats_analyzer.ex`
   - 5 try blocks
   - Mix of Pattern A and B
   - Some can use with statements

3. `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex`
   - 5 try blocks  
   - Pattern B (multiple operations)
   - Good candidate for with statements

#### Medium Priority Files (2-4 try blocks each)
- All analyzer modules in contexts/*/analyzers/
- Domain modules with business logic
- Infrastructure modules with external calls

### Step 3: Automated Detection Script

```elixir
# Save as detect_try_blocks.exs
defmodule TryBlockDetector do
  def scan_file(path) do
    content = File.read!(path)
    lines = String.split(content, "\n")
    
    try_blocks = detect_try_blocks(lines)
    
    if length(try_blocks) > 0 do
      IO.puts("\n#{path}: #{length(try_blocks)} try blocks")
      Enum.each(try_blocks, fn {line_num, context} ->
        IO.puts("  Line #{line_num}: #{context}")
      end)
    end
  end
  
  defp detect_try_blocks(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "try do") end)
    |> Enum.map(fn {line, num} -> {num, String.trim(line)} end)
  end
end

# Run on all Elixir files
Path.wildcard("lib/**/*.ex")
|> Enum.each(&TryBlockDetector.scan_file/1)
```

## Conversion Guidelines

### When to Use Implicit Rescue
- Single operation being wrapped
- Simple error transformation
- No complex error matching

### When to Use With Statements  
- Multiple sequential operations
- Each step can fail independently
- Want to handle specific error cases

### When to Keep Explicit Try
- Complex error matching patterns
- Need to handle specific exception types differently
- Cleanup code in after blocks

## Common Patterns in the Codebase

### Analyzer Pattern
```elixir
# COMMON INCORRECT PATTERN
def analyze_something(data) do
  try do
    validated = validate_data(data)
    result = perform_calculations(validated)
    format_output(result)
  rescue
    _ -> %{error: "Analysis failed"}
  end
end

# REFACTORED
def analyze_something(data) do
  validated = validate_data(data)
  result = perform_calculations(validated)
  format_output(result)
rescue
  _ -> %{error: "Analysis failed"}
end
```

### Database Operation Pattern
```elixir
# COMMON INCORRECT PATTERN  
def fetch_data(id) do
  try do
    Repo.get!(Resource, id)
  rescue
    Ecto.NoResultsError -> nil
  end
end

# REFACTORED
def fetch_data(id) do
  Repo.get(Resource, id)  # Use get instead of get!
end
```

### External API Pattern
```elixir
# KEEP EXPLICIT (but modernize)
def call_external_api(params) do
  try do
    response = HTTPoison.get!(url, headers)
    decode_response(response)
  rescue
    HTTPoison.Error -> {:error, :network_error}
    Jason.DecodeError -> {:error, :invalid_response}
  catch
    :exit, _ -> {:error, :timeout}
  end
end
```

## Testing Considerations

1. **Ensure Error Behavior Unchanged**
   - Test both success and failure paths
   - Verify error messages/types are preserved

2. **Add Tests for Error Cases**
   - Many try blocks hide untested error paths
   - Add explicit error case tests

3. **Check for Swallowed Errors**
   - Some try blocks might be hiding real issues
   - Consider logging errors before converting

## Expected Results

### Before
```
┃ [R] ↘ Prefer using an implicit `try` rather than explicit `try`.
┃       lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex:234
Total: 80+ explicit try warnings
```

### After
```
Explicit try warnings: 0
Remaining total errors: ~850 (from 930)
Code is cleaner and error handling is more idiomatic
```

## Success Criteria
1. Zero "explicit try" warnings from Credo
2. All tests pass (error behavior unchanged)
3. Error handling is more idiomatic Elixir
4. No runtime errors introduced
5. Better error visibility (less swallowing)

## Verification Commands
```bash
# Check progress
mix credo --strict | grep -c "Prefer using an implicit"

# Ensure nothing broke
mix test
mix dialyzer

# Check for swallowed errors in logs
mix phx.server # and test error paths
```

This workstream modernizes error handling throughout the codebase while reducing errors by 8.6%.