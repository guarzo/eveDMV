# EVE DMV Warning Handling Guide

This guide documents how to properly handle and suppress warnings in the EVE DMV codebase. Follow these conventions to maintain code quality while pragmatically addressing unavoidable warnings.

## Quick Reference

```elixir
# File-level Credo suppression (most common)
# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies

# Skip test temporarily
@tag :skip

# Suppress module documentation
@moduledoc false

# Mark incomplete implementation
# TODO: Implement real calculation
```

## Warning Types and Suppression Strategies

### 1. Credo Warnings

#### Module Dependencies (`Credo.Check.Refactor.ModuleDependencies`)
**When to suppress**: Complex modules that legitimately need many dependencies (e.g., LiveViews, domain aggregators)

```elixir
# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies

defmodule EveDmvWeb.CharacterIntelligenceLive do
  # Complex LiveView with many legitimate dependencies
end
```

**Currently suppressed in**: 29 files including router.ex, application.ex, and most LiveViews

#### Strict Module Layout (`Credo.Check.Readability.StrictModuleLayout`)
**When to suppress**: LiveView modules where the standard layout conflicts with LiveView patterns

```elixir
# credo:disable-for-this-file Credo.Check.Readability.StrictModuleLayout

defmodule EveDmvWeb.KillFeedLive do
  use EveDmvWeb, :live_view
  # LiveView specific ordering requirements
end
```

#### Long Quote Blocks (`Credo.Check.Refactor.LongQuoteBlocks`)
**When to suppress**: Modules with necessary long documentation or error messages

```elixir
# credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks

defmodule EveDmv.SomeModule do
  @moduledoc """
  Long but necessary documentation...
  """
end
```

### 2. Compilation Warnings

#### Unused Variables
**Do NOT suppress** - Fix by prefixing with underscore:

```elixir
# Bad
def process(data, options) do
  # options not used
  data
end

# Good
def process(data, _options) do
  data
end
```

#### Pattern Match Warnings
**Do NOT suppress** - Handle all cases:

```elixir
# Bad
case result do
  {:ok, value} -> value
end

# Good
case result do
  {:ok, value} -> value
  {:error, reason} -> handle_error(reason)
end
```

### 3. Dialyzer Warnings

**Current Status**: No dialyzer suppressions in codebase (good!)

If absolutely necessary:
```elixir
# Only use when dialyzer is demonstrably wrong
@dialyzer {:no_match, some_function: 2}
```

### 4. Test Warnings

#### Skipping Tests
```elixir
# Temporary skip with reason
@tag :skip
test "flaky test that needs fixing" do
  # Test implementation
end

# Better: Fix the test or use pending
@tag :pending
test "feature not yet implemented" do
  # Test implementation
end
```

### 5. Documentation Warnings

#### Module Documentation
```elixir
# Only for internal/worker modules
@moduledoc false

# Better: Provide minimal documentation
@moduledoc """
Internal worker for processing killmails.
"""
```

## TODO Management

### Proper TODO Format
```elixir
# TODO: Implement real ship type detection
# This currently returns mock data
def detect_ship_type(_killmail) do
  %{ship_type: "Unknown", confidence: 0.0}
end
```

### Sprint-Based TODOs
```elixir
# TODO [Sprint 13]: Connect to ESI market endpoint
# Blocked by: API rate limiting strategy
def get_market_prices(_type_ids) do
  []
end
```

## Global Configuration

### Credo (.credo.exs)
Currently disabled globally:
- `Credo.Check.Warning.LazyLogging` - Performance optimization
- `Credo.Check.Refactor.MapInto` - Style preference
- `Credo.Check.Readability.PipeIntoAnonymousFunctions` - Readability choice
- `Credo.Check.Refactor.ABCSize` - Complex calculations allowed
- `Credo.Check.Refactor.CyclomaticComplexity` - Complex logic allowed

### Coverage (.coveralls.exs)
Excluded from coverage:
- Test files
- Migrations
- Generated files (gettext, telemetry)
- Build artifacts

## Best Practices

### 1. Suppress at the Narrowest Scope
- Prefer fixing over suppressing
- Use file-level suppression over global config
- Never suppress without a comment explaining why

### 2. Document Suppressions
```elixir
# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
# This module coordinates between multiple domains and requires these dependencies
```

### 3. Track Technical Debt
- Convert suppressions to TODOs with sprint targets
- Review suppressions during sprint planning
- Remove suppressions when refactoring

### 4. Quality Gates
Run quality checks before committing:
```bash
# Full quality check (same as CI)
./scripts/quality_check.sh

# Quick check (skip dialyzer)
SKIP_DIALYZER=true ./scripts/quality_check.sh

# Auto-fix issues
./scripts/quality_fix.sh
```

## Common Patterns to Avoid

### 1. Suppressing Instead of Fixing
```elixir
# Bad: Suppressing unused variable warning
def process(data, _options) do
  # credo:disable-for-next-line
  data
end

# Good: Use underscore prefix
def process(data, _options) do
  data
end
```

### 2. Blanket Suppressions
```elixir
# Bad: Suppressing all warnings for a file
# credo:disable-for-this-file

# Good: Suppress specific warnings with justification
# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
# LiveView requires multiple domain dependencies
```

### 3. Permanent "Temporary" Suppressions
```elixir
# Bad: Skip with no plan to fix
@tag :skip
test "some test" do
end

# Good: Skip with issue tracking
@tag :skip
# TODO [Sprint 13]: Fix flaky test - tracked in issue #123
test "some test" do
end
```

## Module-Specific Guidelines

### LiveView Modules
Common suppressions needed:
- `ModuleDependencies` - LiveViews often coordinate multiple domains
- `StrictModuleLayout` - LiveView lifecycle conflicts with strict ordering

### Domain Modules (Ash Resources)
- Keep suppressions minimal
- Use Ash patterns to reduce complexity
- Document any necessary suppressions

### Worker Modules
- Use `@moduledoc false` for internal workers
- Keep public API minimal
- Consider extracting to separate namespace

## Monitoring Warning Debt

### Check Current Suppressions
```bash
# Count Credo suppressions
grep -r "credo:disable" lib/ test/ | wc -l

# Find all TODOs
grep -r "TODO" lib/ test/ | wc -l

# Analyze suppressions by type
./scripts/analyze_todos.sh
```

### Sprint Planning
1. Review suppression count trends
2. Allocate time for warning cleanup
3. Prioritize suppressions in critical paths
4. Convert TODOs to tracked issues

## Emergency Suppression

When CI is blocking and you need to suppress quickly:

1. **Add minimal suppression**:
   ```elixir
   # credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
   # EMERGENCY: Suppressed to unblock CI - needs refactoring
   ```

2. **Create immediate follow-up**:
   ```elixir
   # TODO [URGENT]: Refactor to remove suppression
   # Issue: #XXX
   ```

3. **Notify team**: Post in chat about the suppression and tracking issue

## Summary

The EVE DMV project uses a pragmatic approach to warnings:
- Suppress only when necessary
- Document why suppression is needed
- Track suppressions as technical debt
- Regularly review and reduce suppressions
- Prioritize fixing over suppressing

Remember: **Every suppression is technical debt**. Use them wisely and always with a plan to remove them.