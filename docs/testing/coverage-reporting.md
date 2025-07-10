# Test Coverage Reporting

This document explains how test coverage is measured, reported, and enforced in the EVE DMV project.

## Current Coverage Status

**Current Coverage: 4.4%**

The project uses [ExCoveralls](https://github.com/parroty/excoveralls) for comprehensive test coverage analysis.

## Coverage Commands

### Local Development

```bash
# Generate HTML coverage report (opens in browser)
mix test.coverage

# Console coverage report  
mix test.coverage.console

# JSON coverage report (for CI/tooling)
mix test.coverage.json

# Simple test run with basic coverage
mix test --cover
```

### HTML Reports

The HTML coverage report provides:
- Line-by-line coverage visualization
- Module-by-module breakdown
- Coverage heatmaps
- Uncovered code highlighting

Access the report at `cover/excoveralls.html` after running `mix test.coverage`.

## CI/CD Integration

### Coverage Threshold Enforcement

Our CI pipeline enforces a minimum coverage threshold:

- **Current Minimum**: 4.0%
- **Target Goal**: 70% (Sprint 5 objective)
- **Enforcement**: CI fails if coverage drops below minimum

### Automated PR Comments

Every pull request automatically gets a coverage comment that includes:

- 📊 **Overall coverage percentage** with color-coded badge
- 📈 **Coverage summary table** (lines covered/total/relevant)
- 🎯 **Coverage goals** and current status
- 📋 **File-level coverage details** (worst performing files)
- 🔍 **Module-type analysis** (Intelligence, API clients, LiveView)
- 💡 **Improvement suggestions** and best practices

The comment is automatically updated when new commits are pushed to the PR.

### Codecov Integration

Coverage reports are uploaded to [Codecov](https://codecov.io) for:
- Historical coverage tracking
- Coverage diff visualization
- Integration with GitHub checks
- Team coverage analytics

## Coverage Configuration

### Excluded Files

The following files are excluded from coverage calculation:

```elixir
skip_files: [
  "test/",                    # Test files themselves
  "_build/",                  # Compiled artifacts  
  "deps/",                    # Dependencies
  "config/",                  # Configuration files
  "priv/repo/migrations/",    # Database migrations
  "test/support/",            # Test support modules
  "lib/eve_dmv_web/gettext.ex",  # Auto-generated
  "lib/eve_dmv_web/endpoint.ex"  # Framework boilerplate
]
```

### Configuration Options

```elixir
# mix.exs
excoveralls: [
  minimum_coverage: 4.0,                     # Minimum threshold
  output_dir: "cover",                       # Output directory
  stop_on_missing_beam_file: false,         # Continue on missing files
  treat_no_relevant_lines_as_covered: true  # Handle edge cases
]
```

## Coverage Improvement Strategies

### High-Impact Areas (Focus First)

1. **Intelligence Modules** (`lib/eve_dmv/intelligence/`)
   - Character analysis algorithms
   - Home defense calculations
   - Member activity tracking
   - Threat assessment logic

2. **Market Integration** (`lib/eve_dmv/market/`)
   - Price fetching strategies
   - Rate limiting logic
   - Cache management
   - API client reliability

3. **Data Processing** (`lib/eve_dmv/killmails/`)
   - Pipeline transformations
   - Data enrichment
   - Validation logic
   - Error handling

### Testing Best Practices

1. **Unit Tests**: Focus on pure functions and business logic
2. **Integration Tests**: Test module interactions and data flow
3. **LiveView Tests**: Test user interactions and state management
4. **Mock External Dependencies**: ESI clients, databases, external APIs
5. **Test Error Paths**: Exception handling and edge cases

### Low-Priority Areas

- Auto-generated files (migrations, gettext)
- Framework boilerplate (endpoint, router basics)
- Simple data structures and schemas
- Configuration modules

## Coverage Targets by Module Type

| Module Type | Current | Target | Priority |
|-------------|---------|--------|----------|
| Intelligence | ~15% | 80% | High |
| Market Services | ~10% | 75% | High |
| API Clients | ~5% | 70% | Medium |
| LiveView | ~0% | 60% | Medium |
| Killmail Processing | ~0% | 85% | High |
| Surveillance | ~8% | 70% | Medium |

## Monitoring and Alerts

### GitHub Actions

- ✅ **Coverage threshold check** - Fails CI if below minimum
- 📊 **Coverage comment** - Updates PR with detailed report  
- ☁️ **Codecov upload** - Historical tracking and analysis
- 🔄 **Automatic updates** - Re-runs on every push

### Local Monitoring

```bash
# Quick coverage check
mix test.coverage.console | tail -1

# Coverage trending (compare with main branch)
git checkout main && mix test.coverage.console | tail -1
git checkout your-branch && mix test.coverage.console | tail -1
```

## Contributing to Coverage

When adding new features:

1. **Write tests first** (TDD approach)
2. **Aim for 80%+ coverage** on new modules
3. **Test both happy path and edge cases**
4. **Mock external dependencies** appropriately
5. **Update existing tests** if modifying behavior

When reviewing PRs:

1. **Check coverage impact** in the automated comment
2. **Verify new code has reasonable coverage**
3. **Ensure critical paths are tested**
4. **Validate test quality** (not just quantity)

## Troubleshooting

### Common Issues

**"Missing beam file" errors**
- Run `mix compile` before coverage analysis
- Check that all dependencies are installed

**Coverage appears too low**
- Verify excluded files configuration
- Check for macro-generated code
- Review test discovery patterns

**CI coverage differs from local**
- Ensure same Elixir/OTP versions
- Check environment-specific configuration
- Verify database setup is identical

**HTML report not opening**
- Check file permissions on `cover/` directory
- Verify web browser default associations
- Try opening `cover/excoveralls.html` manually

### Getting Help

1. Check the [ExCoveralls documentation](https://github.com/parroty/excoveralls)
2. Review our test patterns in `test/support/`
3. Ask in team chat about coverage strategy
4. Reference existing well-tested modules for patterns