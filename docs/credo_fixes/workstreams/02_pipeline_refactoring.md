# Workstream 2: Pipeline Refactoring

## Overview
- **Total Errors**: 250+ errors (27% of all errors)
- **Complexity**: MEDIUM - Semi-automated with manual review
- **Impact**: 27% error reduction, major readability improvement
- **Time Estimate**: 3-4 hours

## Error Types to Fix

### 1. Single Function Pipelines (~150 errors)
```elixir
# INCORRECT - Using pipe for single function
data |> Map.get(:key)
socket |> assign(:loading, true)
changeset |> Ecto.Changeset.valid?()

# CORRECT - Direct function call
Map.get(data, :key)
assign(socket, :loading, true)
Ecto.Changeset.valid?(changeset)
```

### 2. Pipe Chains Not Starting with Raw Value (~100 errors)
```elixir
# INCORRECT - Starting with function call
Map.get(data, :items) |> Enum.filter(&valid?/1) |> Enum.map(&transform/1)

# CORRECT - Starting with raw value
data
|> Map.get(:items)
|> Enum.filter(&valid?/1)
|> Enum.map(&transform/1)

# OR - If single source, no pipe needed
items = Map.get(data, :items)
items |> Enum.filter(&valid?/1) |> Enum.map(&transform/1)
```

## Implementation Instructions

### Step 1: Automated Single-Function Pipeline Fixes

```bash
# Create a sed script for common patterns
cat > fix_single_pipelines.sh << 'EOF'
#!/bin/bash

# Pattern 1: Simple function calls with single argument
find lib test -name "*.ex" -o -name "*.exs" | xargs sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\) |> \([A-Z][a-zA-Z0-9_.]*\)(\(:[a-zA-Z_][a-zA-Z0-9_]*\))/\2(\1, \3)/g'

# Pattern 2: Function calls with no arguments  
find lib test -name "*.ex" -o -name "*.exs" | xargs sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\) |> \([A-Z][a-zA-Z0-9_.]*\)()/\2(\1)/g'

# Common LiveView patterns
find lib -name "*_live.ex" | xargs sed -i 's/socket |> assign(/assign(socket, /g'
find lib -name "*_live.ex" | xargs sed -i 's/socket |> put_flash(/put_flash(socket, /g'
find lib -name "*_live.ex" | xargs sed -i 's/socket |> push_event(/push_event(socket, /g'

echo "Automated fixes complete. Manual review required for complex cases."
EOF

chmod +x fix_single_pipelines.sh
./fix_single_pipelines.sh
```

### Step 2: Manual Pattern Recognition and Fixes

#### LiveView Patterns (High Frequency)
```elixir
# INCORRECT patterns in handle_event/3
def handle_event("save", params, socket) do
  socket
  |> assign(:loading, true)
  
  validated_params
  |> create_record()
  
  socket
  |> put_flash(:info, "Saved!")
  |> assign(:loading, false)
end

# CORRECT
def handle_event("save", params, socket) do
  socket = assign(socket, :loading, true)
  
  create_record(validated_params)
  
  socket
  |> put_flash(:info, "Saved!")
  |> assign(:loading, false)
end
```

#### Test Patterns
```elixir
# INCORRECT in tests
test "something" do
  result |> assert()
  conn |> get("/api/endpoint")
  response |> json_response(200)
end

# CORRECT
test "something" do
  assert result
  get(conn, "/api/endpoint")
  json_response(response, 200)
end
```

#### Analyzer Patterns
```elixir
# INCORRECT in analyzers
def analyze(data) do
  data
  |> validate_input()
  
  processed
  |> calculate_metrics()
  
  results
  |> format_output()
end

# CORRECT
def analyze(data) do
  validate_input(data)
  
  processed
  |> calculate_metrics()
  |> format_output()
end
```

### Step 3: Fix Pipe Chain Starting Points

```elixir
# Tool to identify and fix pipe chain issues
defmodule PipeChainFixer do
  def analyze_file(path) do
    File.read!(path)
    |> Code.string_to_quoted()
    |> find_bad_pipe_chains()
    |> Enum.each(&IO.puts/1)
  end
  
  defp find_bad_pipe_chains(ast) do
    # AST traversal to find pipes starting with function calls
    # Return list of line numbers and suggested fixes
  end
end
```

## Files Requiring Most Attention

### Critical Files (10+ pipeline errors each)
1. `lib/eve_dmv_web/live/surveillance_live.ex` - 15 errors
2. `lib/eve_dmv_web/live/player_profile_live.ex` - 12 errors  
3. `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex` - 11 errors
4. `lib/eve_dmv/contexts/player_profile/analyzers/combat_stats_analyzer.ex` - 10 errors

### Module Categories by Error Density
1. **LiveView modules** (~40 errors) - Socket piping patterns
2. **Analyzer modules** (~35 errors) - Data transformation pipelines
3. **Test files** (~30 errors) - Assertion pipelines
4. **Repository modules** (~25 errors) - Query building pipelines
5. **Service modules** (~20 errors) - Business logic pipelines

## Common Patterns to Fix

### Pattern 1: LiveView Socket Updates
```elixir
# Find all: socket |> assign(
# Replace with: assign(socket,

# Find all: socket |> put_flash(
# Replace with: put_flash(socket,
```

### Pattern 2: Ecto Operations  
```elixir
# Find all: changeset |> Ecto.Changeset.
# Evaluate each - many should be direct calls
```

### Pattern 3: Test Assertions
```elixir
# Find all: |> assert
# Replace with direct assert calls
```

### Pattern 4: Map/List Operations
```elixir
# Find all: data |> Map.get(
# Replace with: Map.get(data,

# Find all: list |> Enum.
# Evaluate - single operations should be direct calls
```

## Verification Steps

1. **Compile Check**: `mix compile --warnings-as-errors`
2. **Test Suite**: `mix test`
3. **Credo Progress**: 
   ```bash
   mix credo --strict | grep -c "pipeline is only one function"
   mix credo --strict | grep -c "Pipe chain should start"
   ```

## Expected Results

### Before
```
┃ [R] ↗ Use a function call when a pipeline is only one function long.
┃       lib/eve_dmv_web/live/surveillance_live.ex:125
┃ [F] → Pipe chain should start with a raw value.
┃       lib/eve_dmv/analyzers/fleet_analyzer.ex:234
Total: 250+ pipeline errors
```

### After  
```
Pipeline errors: 0
Remaining total errors: ~680 (from 930)
```

## Guidelines for Manual Review

1. **Preserve Multi-Step Pipelines** - Don't break up legitimate multi-step transformations
2. **Keep Semantic Meaning** - Some single pipes are used for consistency in a pipeline-heavy module
3. **Consider Context** - In pipeline-heavy modules, consistency might override the rule
4. **Test Thoroughly** - Pipeline changes can subtly affect behavior

## Success Metrics
- Zero "single function pipeline" warnings
- Zero "pipe chain should start with raw value" warnings  
- All tests passing
- No runtime errors
- Improved code readability scores

This workstream will significantly improve code readability while reducing error count by 27%.