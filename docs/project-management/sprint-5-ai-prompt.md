# 🤖 AI Assistant Sprint 5 Prompt

## Sprint Completion Prompt Template

### Prompt: Complete Sprint 5 - Code Quality & Technical Debt Resolution

```
You are working on EVE DMV, a wormhole-focused PvP intelligence platform for EVE Online. Your task is to complete Sprint 5, which focuses on establishing production-ready code quality, security, and maintainability standards.

## Context
- **Project**: EVE DMV - Wormhole intelligence platform integrated with real-time killmail data
- **Current Sprint**: Sprint 5 (Code Quality & Technical Debt Resolution)
- **Sprint Status**: 0/35 story points completed, all features pending
- **Previous Achievement**: 128/128 story points completed across Sprints 1-4.5
- **Critical Issue**: Current test coverage at 6.4% vs 70% minimum threshold

## Sprint 5 Scope
According to /workspace/docs/sprints/sprint-5.md, implement these 5 user stories:

1. **Security Hardening & Authentication** (8 pts) - Secure all routes and implement proper session validation
2. **Test Coverage & Quality Gates** (10 pts) - Increase coverage from 6.4% to 70% minimum
3. **Module Refactoring & Architecture** (6 pts) - Break down large modules and improve maintainability
4. **Performance Optimization** (5 pts) - Optimize queries, eliminate N+1 problems, add caching
5. **ESI Integration Reliability** (6 pts) - Proper error handling and graceful degradation

## Key Project Files
- **Sprint Documentation**: /workspace/docs/sprints/sprint-5.md
- **Project Status**: /workspace/PROJECT_STATUS.md
- **Development Guidelines**: /workspace/CLAUDE.md
- **Intelligence Modules**: /workspace/lib/eve_dmv/intelligence/
- **LiveView Components**: /workspace/lib/eve_dmv_web/live/

## Your Implementation Tasks

### Phase 1: Security Hardening (Days 1-3)
1. **Secure Authentication Routes**:
   ```
   Routes requiring auth protection:
   - /wh-vetting (WHVettingLive)
   - /surveillance (ChainSurveillanceLive)
   - /chain-intelligence (ChainIntelligenceLive)
   - /intel/:character_id (CharacterIntelligenceLive)
   ```

2. **Implementation Steps**:
   - Add `on_mount: {EveDmvWeb.AuthLive, :load_from_session}` to all sensitive routes
   - Implement proper session validation in WHVettingLive and other components
   - Move hardcoded URLs to runtime configuration in config/runtime.exs
   - Add rate limiting middleware for ESI calls
   - Implement circuit breaker pattern for external APIs

3. **Security Audit**:
   - Run security analysis with `mix deps.audit` and Sobelow
   - Fix all critical and high-severity vulnerabilities
   - Implement proper error handling without information leakage

### Phase 2: Test Coverage Implementation (Days 4-8)
1. **Test Infrastructure Setup**:
   ```elixir
   # Required test coverage areas:
   - Intelligence modules (WHVettingAnalyzer, WHFleetAnalyzer, etc.)
   - LiveView components (WHVettingLive, CharacterIntelligenceLive)
   - ESI integration services
   - Critical business logic functions
   ```

2. **Test Implementation Priority**:
   - **High Priority**: Core intelligence analyzers (WHVettingAnalyzer, HomeDefenseAnalyzer)
   - **High Priority**: LiveView mount and event handlers
   - **Medium Priority**: ESI service layer error handling
   - **Medium Priority**: Data formatting and presentation logic

3. **Mock External Services**:
   - Use Mox to mock ESI API calls
   - Mock Wanderer API integration
   - Mock Janice API for ship valuation
   - Create test fixtures for consistent data

4. **Coverage Enforcement**:
   - Configure ExCoveralls to enforce 70% minimum coverage
   - Update CI pipeline to fail on coverage drops
   - Add coverage reporting to pull requests

### Phase 3: Module Refactoring (Days 9-11)
1. **Large Module Breakdown**:
   ```elixir
   # Current large modules to refactor:
   - MemberActivityAnalyzer (1,020 lines) → split into:
     - MemberActivityAnalyzer (core logic)
     - MemberActivityMetrics (calculations)
     - MemberActivityFormatter (display logic)
   
   - HomeDefenseAnalyzer (735 lines) → split into:
     - HomeDefenseAnalyzer (core logic)
     - DefenseCapabilityAnalyzer (tactical analysis)
     - DefenseRecommendations (suggestions)
   ```

2. **Shared Component Extraction**:
   - Create VettingFormatter module for common formatting
   - Extract error handling patterns into shared utilities
   - Centralize configuration management
   - Create shared ESI response validation

3. **Code Quality Improvements**:
   - Add comprehensive @doc annotations to all public functions
   - Implement consistent error handling patterns
   - Remove code duplication through shared modules
   - Apply Credo suggestions for code quality

### Phase 4: Performance Optimization (Days 12-13)
1. **Database Optimization**:
   ```sql
   -- Add indexes for common query patterns:
   CREATE INDEX idx_killmails_character_id ON killmails_enriched(character_id);
   CREATE INDEX idx_killmails_corporation_id ON killmails_enriched(corporation_id);
   CREATE INDEX idx_killmails_timestamp ON killmails_enriched(killmail_time);
   ```

2. **ESI Call Optimization**:
   - Implement batched ESI calls to reduce N+1 queries
   - Add Redis caching for expensive ESI operations
   - Move long-running vetting analysis to Oban background jobs
   - Implement proper pagination for large datasets

3. **Memory Optimization**:
   - Stream large datasets instead of loading into memory
   - Implement lazy loading for heavy calculations
   - Add connection pooling for external API calls

### Phase 5: ESI Integration Reliability (Days 14)
1. **Comprehensive Error Handling**:
   ```elixir
   # Error scenarios to handle:
   - ESI API unavailable (503 Service Unavailable)
   - Rate limit exceeded (420 Rate Limited)
   - Authentication failures (401 Unauthorized)
   - Network timeouts and connection errors
   - Invalid or malformed responses
   ```

2. **Graceful Degradation**:
   - Fallback to cached data when ESI unavailable
   - User notifications for stale data
   - Partial functionality when some ESI endpoints fail
   - Background refresh of critical data

3. **Monitoring and Alerting**:
   - Implement Telemetry for ESI call success rates
   - Add circuit breaker monitoring
   - Create alerts for prolonged ESI failures
   - Monitor and log rate limit usage

## Critical Technical Requirements

### Testing Standards
- **Unit Tests**: All public functions must have test coverage
- **Integration Tests**: Critical workflows (vetting, surveillance) must be tested end-to-end
- **LiveView Tests**: Use Phoenix.LiveViewTest for component testing
- **Property Testing**: Use StreamData for algorithmic functions
- **Mock Strategy**: Use Mox for external API dependencies

### Security Standards
- **Authentication**: All sensitive routes require valid session
- **Authorization**: Proper user context validation
- **Rate Limiting**: ESI calls must respect rate limits
- **Circuit Breakers**: External service failures must not cascade
- **Input Validation**: All user inputs must be sanitized

### Performance Standards
- **Page Load**: <200ms (95th percentile)
- **API Response**: <100ms (95th percentile)
- **Memory Usage**: <500MB under normal load
- **Database Queries**: No N+1 query patterns
- **Caching Strategy**: Redis for expensive operations

### Code Quality Standards
- **Module Size**: Maximum 500 lines per module
- **Test Coverage**: Minimum 70% line coverage
- **Documentation**: All public functions must have @doc
- **Error Handling**: Consistent patterns across all modules
- **Credo Score**: A grade required

## Success Criteria & Definition of Done
- [ ] All 5 user stories implemented and tested (35 story points)
- [ ] Test coverage increased from 6.4% to minimum 70%
- [ ] All security vulnerabilities resolved (zero critical/high)
- [ ] No modules exceed 500 lines of code
- [ ] All ESI integration has proper error handling and circuit breakers
- [ ] Performance benchmarks meet targets (<200ms page loads)
- [ ] Rate limiting implemented for all external API calls
- [ ] Authentication enforced on all sensitive routes
- [ ] CI pipeline enforces quality gates
- [ ] Security audit passed with zero critical findings
- [ ] Quality checks pass: `mix quality.check`
- [ ] Sprint documentation updated with completion status
- [ ] PROJECT_STATUS.md updated

## Implementation Priority Order
1. **Critical**: Security hardening (affects production safety)
2. **Critical**: Test infrastructure setup (enables safe refactoring)
3. **High**: Module refactoring (improves maintainability)
4. **High**: ESI reliability (affects user experience)
5. **Medium**: Performance optimization (improves scalability)

## Quality Gates
Each phase must pass these gates before proceeding:
- **Security**: No critical vulnerabilities in security scan
- **Tests**: Coverage must not decrease below previous phase
- **Performance**: No performance regressions detected
- **Code Quality**: Credo score must remain A grade
- **Functionality**: All existing features must continue working

## Integration Points to Secure
```elixir
# Routes requiring authentication:
live "/wh-vetting", WHVettingLive
live "/surveillance", ChainSurveillanceLive  
live "/chain-intelligence", ChainIntelligenceLive
live "/intel/:character_id", CharacterIntelligenceLive

# Modules requiring comprehensive testing:
- EveDmv.Intelligence.WHVettingAnalyzer
- EveDmv.Intelligence.WHFleetAnalyzer
- EveDmv.Intelligence.HomeDefenseAnalyzer
- EveDmv.Intelligence.MemberActivityAnalyzer
- EveDmvWeb.Live.WHVettingLive
- EveDmvWeb.Live.CharacterIntelligenceLive
```

## Important Project Context
- **Framework**: Phoenix 1.7.21 with LiveView for real-time UI
- **Data Layer**: Ash Framework 3.4 for resources (NOT traditional Ecto)
- **Testing**: ExUnit with Phoenix.LiveViewTest for LiveView components
- **Security**: Sobelow for security analysis, proper session management
- **Performance**: Benchee for performance testing, Redis for caching
- **Current State**: Functional but with significant technical debt

## Expected Outcomes
After Sprint 5 completion:
1. **Production-Ready Security**: All routes properly secured with authentication
2. **Quality Foundation**: 70%+ test coverage with enforced quality gates
3. **Maintainable Code**: No modules >500 lines, proper documentation
4. **Reliable Integration**: Robust ESI handling with graceful degradation
5. **Optimized Performance**: Fast response times with proper caching
6. **Technical Debt Resolved**: Clean, maintainable codebase ready for future development

## Testing Strategy
```elixir
# Test structure to implement:
test/eve_dmv/intelligence/
├── wh_vetting_analyzer_test.exs
├── wh_fleet_analyzer_test.exs
├── home_defense_analyzer_test.exs
└── member_activity_analyzer_test.exs

test/eve_dmv_web/live/
├── wh_vetting_live_test.exs
├── character_intelligence_live_test.exs
└── auth_live_test.exs

test/support/
├── fixtures.ex (test data)
├── mocks.ex (external API mocks)
└── test_helpers.ex (shared utilities)
```

Please implement these features following the existing Ash Framework patterns and maintaining the high code quality standards. Focus on security first, then testing infrastructure, followed by systematic refactoring and optimization. Quality over speed is the priority for this sprint.
```

---

## Usage Instructions

1. **Copy the prompt above** when starting Sprint 5 implementation
2. **Provide context** by ensuring the AI has access to all project documentation
3. **Monitor progress** through test coverage metrics and quality gates
4. **Prioritize security** - all security vulnerabilities must be resolved first
5. **Enforce quality gates** - each phase must meet quality standards before proceeding

## File Structure for Implementation
```
/workspace/test/
├── eve_dmv/intelligence/ (intelligence module tests)
├── eve_dmv_web/live/ (LiveView component tests)
└── support/ (test fixtures and helpers)

/workspace/lib/eve_dmv/
├── intelligence/ (modules to refactor)
├── esi/ (reliability improvements)
└── shared/ (extracted common utilities)
```

## Quality Metrics Dashboard
Track these metrics throughout implementation:
- **Test Coverage**: Target 70% (from current 6.4%)
- **Security Score**: Zero critical vulnerabilities
- **Performance**: <200ms page loads
- **Module Size**: Maximum 500 lines
- **Code Quality**: Credo A grade

---

*This prompt ensures systematic implementation of quality improvements while maintaining functionality and establishing production-ready standards.*