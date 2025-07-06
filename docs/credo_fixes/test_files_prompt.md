# Test Files Code Quality Fixes

## Issues Overview - COMPLETE REMAINING WORK
- **Error Count**: 100+ errors across test files
- **Major Categories**: Single-function pipelines (35+), trailing whitespace (25+), alias organization (20+), number formatting (10+), nested module aliasing (5+)
- **Files Affected**: 
  - `test/**/*_test.exs`
  - `test/performance/*`
  - `test/manual/*`
  - `test/support/*`

## AI Assistant Prompt

Address test file code quality issues:

### 1. **Single-Function Pipelines** (HIGH PRIORITY - 35+ instances)
**Common patterns in tests**:
```elixir
# Bad
result |> assert_received()
conn |> get("/api/endpoint")
changeset |> Ecto.Changeset.get_change(:field)

# Good  
assert_received(result)
get(conn, "/api/endpoint")
Ecto.Changeset.get_change(changeset, :field)
```

### 2. **Trailing Whitespace** (CRITICAL - 25+ instances)
**Solution**: Run formatter on all test files
```bash
find test -name "*.exs" -exec mix format {} \;
```

### 3. **Alias Organization** (HIGH PRIORITY - 20+ instances)
**Test files often have many imports**:
```elixir
# Bad - disorganized imports
use ExUnit.Case
import Ecto.Query
alias EveDmv.{Factory, TestHelpers}
require Logger
alias EveDmv.Api

# Good - organized imports
use ExUnit.Case

alias EveDmv.Api
alias EveDmv.Factory
alias EveDmv.TestHelpers

require Logger

import Ecto.Query
```

### 4. **Number Formatting** (MEDIUM PRIORITY - 10+ instances)
**Large numbers in test data**:
```elixir
# Bad
damage_amount: 1000000
isk_value: 50000000
character_id: 98000001

# Good
damage_amount: 1_000_000
isk_value: 50_000_000  
character_id: 98_000_001
```

### 5. **Nested Module Aliasing** (LOW PRIORITY - 5+ instances)
**Pattern**: `Nested modules could be aliased at the top`
```elixir
# Bad - using full module path repeatedly
test "something" do
  EveDmv.Intelligence.Analyzers.FleetAnalyzer.analyze()
  EveDmv.Intelligence.Analyzers.FleetAnalyzer.calculate()
end

# Good - alias at top
alias EveDmv.Intelligence.Analyzers.FleetAnalyzer

test "something" do
  FleetAnalyzer.analyze()
  FleetAnalyzer.calculate()
end
```

## Special Test File Patterns

### **Factory Files**
```elixir
# Common pipeline issues in factories
def character_factory do
  %{
    character_id: sequence(:character_id, & &1),
    name: sequence(:name, &"Character #{&1}")
  }
  |> merge_attributes(attrs)  # Convert to: merge_attributes(base_attrs, attrs)
end
```

### **Test Helpers**  
```elixir
# Pipeline issues in assertions
def assert_killmail_valid(killmail) do
  killmail
  |> Map.get(:killmail_id)  # Convert to: Map.get(killmail, :killmail_id)
  |> assert()                # Convert to: assert(killmail_id)
end
```

### **Performance Tests**
```elixir
# Number formatting in benchmarks
Benchee.run(%{
  "small" => fn -> process_killmails(1000) end,    # Fix to: 1_000
  "medium" => fn -> process_killmails(10000) end,  # Fix to: 10_000
  "large" => fn -> process_killmails(100000) end   # Fix to: 100_000
})
```

## Implementation Steps

### **Phase 1: Automated Cleanup**
```bash
# Format all test files
mix format test/**/*.{ex,exs}
# Result: ~25 whitespace errors eliminated
```

### **Phase 2: Pipeline Conversion**
1. Focus on test assertions first
2. Then factory methods
3. Finally helper functions
```bash
# Can partially automate with careful regex
# Manual review needed for complex cases
```

### **Phase 3: Import Organization**
1. Group imports by type at file top
2. Order: `use` → `alias` → `require` → `import`
3. Alphabetize within groups
4. Add blank lines between groups

### **Phase 4: Number Formatting**
```bash
# Find large numbers
grep -r "[0-9]\{5,\}" test/
# Add underscores to all numbers > 9999
```

### **Phase 5: Module Aliasing**
Review test files for repeated full module paths and add appropriate aliases.

## Files Requiring Immediate Attention

**High Impact**:
- `test/performance/performance_test_suite.exs` - Multiple issues
- `test/manual/manual_testing_data_generator.exs` - Pipeline and formatting
- Factory files with pipeline patterns
- Integration tests with many imports

**Quick Wins**:
- All test files for whitespace removal
- Number formatting in test data
- Simple pipeline conversions

## Expected Impact

- **Current**: 100+ errors in test files
- **After formatting**: ~75 errors (25% reduction)
- **After pipelines**: ~40 errors (60% reduction)
- **After imports**: ~20 errors (80% reduction)
- **After numbers**: ~10 errors (90% reduction)
- **Final**: <5 errors (95% reduction)

Test files can be cleaned to near-zero errors with systematic approach, improving test readability and maintenance.