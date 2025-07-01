# Test Coverage Implementation Prompt for AI Assistant

## Mission: Implement Strategic Test Coverage for EVE DMV Codebase

You are an AI assistant tasked with implementing comprehensive test coverage for the EVE DMV Elixir/Phoenix application. The codebase currently has ~10% test coverage and needs strategic improvement focusing on the highest-risk, business-critical areas first.

## Current Context
- **Language**: Elixir/Phoenix with Ash Framework
- **Testing Framework**: ExUnit with Ecto.Adapters.SQL.Sandbox
- **Current Coverage**: **3.9% overall** (assessed 2025-07-01)
- **Target Architecture**: Real-time killmail processing, EVE Online integration, surveillance system
- **Test Dependencies**: ✅ ExCoveralls, Bypass, Mox configured in mix.exs
- **Coverage Command**: `MIX_ENV=test mix coveralls`

## Primary Objectives

### Phase 1: Critical Security & Data Integrity (Target: 25% coverage)
**Priority: CRITICAL - Complete within 1 week**

1. **Authentication System** (`lib/eve_dmv/users/`) - 0% → 80%
   ```elixir
   # Focus areas:
   # - EVE SSO OAuth2 flow edge cases
   # - Token refresh and expiration handling
   # - Session security and character linking
   # - Invalid character ID scenarios
   ```

2. **Killmail Pipeline** (`lib/eve_dmv/killmails/`) - 20% → 70%
   ```elixir
   # Focus areas:
   # - SSE connection failures and reconnection logic
   # - Malformed killmail data validation
   # - Bulk database operation error handling
   # - Memory management under high load
   ```

### Phase 2: Core Business Logic (Target: 35% coverage)
**Priority: HIGH - Complete within 2-3 weeks**

3. **Surveillance Engine** (`lib/eve_dmv/surveillance/`) - 0% → 60%
   ```elixir
   # Focus areas:
   # - Complex filter matching accuracy
   # - ETS table management and recovery
   # - High-volume killmail processing
   # - Memory leak prevention
   ```

4. **ESI Client Integration** (`lib/eve_dmv/eve/`) - 30% → 65%
   ```elixir
   # Focus areas:
   # - Circuit breaker state transitions
   # - API failure handling and retries
   # - Rate limiting compliance
   # - Bulk request optimization
   ```

### Phase 3: Feature Reliability (Target: 40% coverage)
**Priority: MEDIUM - Complete within 4 weeks**

5. **Market Services** (`lib/eve_dmv/market/`) - 25% → 60%
6. **LiveView Components** (`lib/eve_dmv_web/live/`) - 15% → 45%

## Implementation Guidelines

### Testing Patterns to Follow
```elixir
# 1. Use Ecto Sandbox for database isolation
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(EveDmv.Repo)
end

# 2. Mock external API calls
setup do
  bypass = Bypass.open()
  Application.put_env(:eve_dmv, :esi_base_url, "http://localhost:#{bypass.port}")
  {:ok, bypass: bypass}
end

# 3. Test both success and failure scenarios
test "handles ESI API failures gracefully" do
  # Test circuit breaker activation
  # Test retry logic
  # Test fallback behavior
end

# 4. Property-based testing for complex logic
use ExUnitProperties
property "surveillance filter matching is consistent" do
  check all(killmail <- killmail_generator(),
            filters <- filter_generator()) do
    # Test filter logic consistency
  end
end
```

### Critical Test Scenarios to Implement

#### Authentication Tests
- [ ] Valid EVE SSO OAuth2 flow
- [ ] Invalid authorization codes
- [ ] Token refresh on expiration
- [ ] Multiple character account linking
- [ ] Session hijacking prevention
- [ ] Rate limiting on auth endpoints

#### Killmail Pipeline Tests  
- [ ] SSE connection drop and reconnection
- [ ] Malformed JSON killmail handling
- [ ] Database constraint violations
- [ ] Memory usage under sustained load
- [ ] Backpressure handling
- [ ] Duplicate killmail filtering

#### Surveillance Engine Tests
- [ ] Complex filter tree compilation
- [ ] ETS table corruption recovery
- [ ] High-volume matching performance
- [ ] Filter logic edge cases
- [ ] Memory management with 1000+ profiles
- [ ] Real-time notification accuracy

### Performance and Load Testing
```elixir
# Include performance assertions
test "surveillance matching handles 1000 killmails/minute" do
  killmails = generate_killmails(1000)
  
  {time, _result} = :timer.tc(fn ->
    SurveillanceEngine.process_batch(killmails)
  end)
  
  assert time < 60_000_000 # Less than 60 seconds
end
```

## CI/CD Integration Requirements

Create a GitHub Actions workflow with **ratcheting coverage goals**:

### Coverage Ratcheting Strategy
```yaml
# .github/workflows/test-coverage-ratchet.yml
name: Test Coverage Ratchet

on: [push, pull_request]

jobs:
  test-coverage:
    runs-on: ubuntu-latest
    steps:
      - name: Run tests with coverage
        run: mix test --cover
      
      - name: Check coverage ratchet
        run: |
          # Compare current coverage to stored baseline
          # Fail if coverage decreases
          # Update baseline if coverage increases
```

### Coverage Milestones
- **Baseline**: 3.9% (current as of 2025-07-01)
- **Week 1**: 25% minimum (Phase 1 complete)
- **Week 2**: 30% minimum  
- **Week 3**: 35% minimum (Phase 2 complete)
- **Week 4**: 40% minimum (Phase 3 complete)
- **Maintenance**: Never allow coverage to drop below achieved level

## Implementation Checklist

### Pre-Implementation
- [x] Set up ExCoveralls with proper configuration ✅ Complete
- [x] Configure test database with proper sandboxing ✅ Complete  
- [x] Install testing dependencies (Bypass, Mox, ExUnitProperties) ✅ Complete
- [ ] Create test data generators for complex structs

### During Implementation
- [ ] Write tests for each critical module identified
- [ ] Include both unit and integration tests
- [ ] Add property-based tests for complex logic
- [ ] Mock external API dependencies appropriately
- [ ] Test error scenarios and edge cases extensively

### Post-Implementation
- [ ] Set up coverage ratcheting in CI
- [ ] Add coverage badges to README
- [ ] Document testing patterns for future contributors
- [ ] Schedule regular coverage reviews

## Success Metrics

### Technical Metrics
- **Coverage**: 3.9% → 40% overall (10x improvement target)
- **Critical Modules**: All identified high-risk areas >60% coverage
- **CI Stability**: Green test suite with coverage ratcheting
- **Performance**: No regression in test suite execution time

### Business Metrics
- **Reliability**: Reduced production errors in tested modules
- **Confidence**: Ability to deploy with confidence
- **Maintainability**: Easier refactoring with test safety net
- **Onboarding**: New developers can contribute safely

## Risk Mitigation

### High-Risk Areas Requiring Special Attention
1. **Memory Management**: ETS tables could grow unbounded
2. **Database Constraints**: Bulk operations may violate FK constraints  
3. **External Dependencies**: API failures could cascade
4. **Real-time Processing**: SSE drops could cause data loss
5. **Authentication Security**: OAuth flow vulnerabilities

### Testing Anti-Patterns to Avoid
- Don't test implementation details, test behavior
- Don't create brittle tests that break on refactoring
- Don't ignore test performance - keep suite fast
- Don't test external APIs directly - use mocks
- Don't write tests just for coverage metrics

## Immediate Action Items

1. ~~**Set up proper test configuration**~~ ✅ **COMPLETE** - ExCoveralls working, baseline established at 3.9%
2. **Start with Authentication** - Highest security impact (currently 0% coverage)
3. **Create data generators** - For consistent test data
4. **Begin with critical path testing** - Focus on user-facing flows
5. **Implement coverage ratcheting** - Prevent coverage regression

Remember: **Quality over quantity**. Better to have 40% high-quality, meaningful test coverage than 80% superficial coverage that doesn't catch real bugs.