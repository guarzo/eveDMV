# EVE DMV Team Style Guide

**Version**: 1.1
**Date**: 2025-12-19

---

## 🎯 Philosophy

> "Code is read far more often than it is written."

Our style guide prioritizes **readability**, **consistency**, and **maintainability** over personal preferences.

---

## 📋 Code Standards

### Function Design

**✅ DO:**
```elixir
# Keep functions focused and under 30 lines
def calculate_threat_score(character_id, options \\ []) do
  with {:ok, data} <- fetch_combat_data(character_id),
       {:ok, scores} <- calculate_dimensional_scores(data) do
    {:ok, aggregate_scores(scores)}
  end
end

# Use descriptive function names
def analyze_wormhole_mass_efficiency(fleet_composition)
def validate_killmail_structure(killmail_data)
```

**❌ DON'T:**
```elixir
# Avoid overly long functions
def do_everything(data) do
  # 100+ lines of mixed logic
end

# Avoid unclear names
def process(x), def handle(data)
```

### Error Handling

**✅ DO:**
```elixir
# Use our standardized error handling
alias EveDmv.Utils.ErrorHandling

def risky_operation(params) do
  ErrorHandling.safe_execute("character analysis", fn ->
    perform_analysis(params)
  end)
end

# Consistent error patterns
case fetch_data() do
  {:ok, data} -> process_data(data)
  {:error, reason} -> ErrorHandling.handle_with_error({:error, reason}, "data fetch")
end
```

**❌ DON'T:**
```elixir
# Inconsistent error handling
try do
  risky_thing()
rescue
  _ -> nil  # Silent failures
end
```

### Data Transformations

**✅ DO:**
```elixir
# Use utility functions for common transformations
alias EveDmv.Utils.DataTransform

character_id = DataTransform.safe_to_integer(params["character_id"])
percentage = DataTransform.safe_percentage(kills, total_events)
clean_params = DataTransform.compact_map(params, [:name, :corporation_id])
```

### Database Queries

**✅ DO:**
```elixir
# Use query helpers for common patterns
alias EveDmv.Utils.QueryHelpers

query
|> QueryHelpers.character_filter(character_id)
|> QueryHelpers.time_range_query(:inserted_at, start_time, end_time)
|> QueryHelpers.apply_ordering(params, :killmail_time)
|> QueryHelpers.safe_limit(per_page)
```

---

## 🏗️ Module Organization

### Context Structure
```
lib/eve_dmv/contexts/
├── battle_analysis/           # Battle-related operations
│   ├── domain/               # Core business logic
│   ├── infrastructure/       # External dependencies
│   └── analyzers/           # Analysis engines
├── character_intelligence/   # Character analysis
└── surveillance/            # Profile matching
```

### File Naming
- **Modules**: `PascalCase` (e.g., `ThreatScoringEngine`)
- **Files**: `snake_case.ex` (e.g., `threat_scoring_engine.ex`)
- **Tests**: `*_test.exs` (e.g., `threat_scoring_engine_test.exs`)

---

## 🧪 Testing Standards

### Test Structure
```elixir
defmodule EveDmv.ThreatScoringEngineTest do
  use EveDmv.DataCase, async: true
  
  alias EveDmv.ThreatScoringEngine
  
  describe "calculate_threat_score/2" do
    test "calculates score for valid character" do
      # Arrange
      character_id = create_test_character()
      
      # Act
      {:ok, result} = ThreatScoringEngine.calculate_threat_score(character_id)
      
      # Assert
      assert result.overall_score > 0
      assert result.threat_level in [:low, :medium, :high, :critical]
    end
  end
end
```

### Test Data
- Use `test/support/test_data_helpers.ex` for consistent test data
- Always use factories/helpers, never hardcoded values
- Tests should be deterministic and isolated

---

## 📦 Dependencies

### Approved Libraries
- **Ash Framework**: Resource management and APIs
- **Broadway**: Stream processing
- **Credo**: Static analysis
- **ExUnit**: Testing framework
- **Jason**: JSON handling
- **HTTPoison**: HTTP client

### Adding New Dependencies
1. Discuss with team first
2. Check for existing alternatives
3. Consider maintenance burden
4. Update documentation

---

## 🔧 Code Quality Tools

### Required Tools
```bash
# Format code
mix format

# Check style
mix credo --strict

# Run tests
mix test

# Type checking (when available)
mix dialyzer
```

### Pre-commit Hooks
```bash
# Install hooks
./scripts/setup_pre_commit.sh

# Manual run
pre-commit run --all-files
```

---

## 📝 Documentation

### Module Documentation
```elixir
defmodule EveDmv.ThreatScoringEngine do
  @moduledoc """
  Calculates threat scores for EVE Online characters based on combat data.
  
  This module analyzes killmail history to produce multi-dimensional threat
  assessments used for fleet intelligence and recruitment screening.
  
  ## Example
  
      {:ok, assessment} = ThreatScoringEngine.calculate_threat_score(character_id)
      assessment.threat_level
      # => :high
  """
  
  @doc """
  Calculates comprehensive threat score for a character.
  
  ## Parameters
  - `character_id` - EVE character ID to analyze
  - `options` - Analysis options (see Options section)
  
  ## Options
  - `:analysis_window_days` - Days of history to analyze (default: 90)
  - `:include_detailed_breakdown` - Include scoring breakdown (default: true)
  
  ## Returns
  `{:ok, threat_assessment}` with comprehensive analysis or `{:error, reason}`
  """
  def calculate_threat_score(character_id, options \\ [])
end
```

### Function Documentation
- Document public functions with `@doc`
- Include examples for complex functions
- Document parameters and return values
- Explain side effects if any

---

## 🚀 Performance Guidelines

### Database
- Use database indexes effectively
- Prefer `Ash.bulk_create` for large inserts
- Use `Ecto.Adapters.SQL.Sandbox` in tests
- Monitor query performance with telemetry

### Memory
- Avoid loading large datasets into memory
- Use streaming for data processing
- Close resources properly
- Profile memory usage in production

### Caching
- Use `QueryCache` for expensive operations
- Cache static data appropriately
- Set reasonable TTL values
- Monitor cache hit rates

---

## 🔒 Security

### Data Handling
- Validate all user inputs
- Use parameterized queries
- Never log sensitive data
- Sanitize outputs

### Authentication
- Use EVE SSO for authentication
- Validate tokens properly
- Handle token refresh correctly
- Implement proper authorization

---

## 🌟 Best Practices

### General
1. **Single Responsibility**: Functions do one thing well
2. **Pure Functions**: Avoid side effects when possible
3. **Explicit**: Make dependencies and effects clear
4. **Consistent**: Follow established patterns
5. **Tested**: Write tests for all public functions

### Elixir-Specific
1. Use pattern matching effectively
2. Prefer `with` for happy path scenarios  
3. Use `case` for complex branching
4. Leverage the pipe operator for data transformation
5. Handle errors explicitly, avoid silent failures

### EVE DMV-Specific
1. Use Ash resources for data modeling
2. Follow context boundaries
3. Use telemetry for monitoring
4. Implement proper error recovery
5. Consider real-time requirements

---

## 📊 Quality Metrics

Our targets:
- **Credo Issues**: <500 total
- **Test Coverage**: >40% (minimum), targeting improvement
- **Function Length**: <30 lines preferred, <50 lines maximum
- **Code Duplication**: <5%
- **Documentation**: All public functions documented

---

## 🔄 Continuous Improvement

### Code Reviews
- All changes require review
- Focus on readability and maintainability
- Suggest improvements, don't just find problems
- Share knowledge and best practices

### Refactoring
- Refactor when you touch code
- Extract common patterns
- Improve naming when unclear
- Remove dead code

### Learning
- Stay updated with Elixir/Phoenix best practices
- Share interesting patterns with the team
- Document lessons learned
- Contribute back to open source when possible

---

## ❓ Questions?

For questions about this style guide:
1. Check existing code examples
2. Ask in team chat
3. Discuss in code review
4. Update this guide when patterns emerge

---

**Last Updated**: 2025-12-19
**Contributors**: EVE DMV Development Team