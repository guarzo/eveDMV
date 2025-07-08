# Sprint 5.5: Technical Debt & Architecture Cleanup

## Sprint Overview
- **Sprint Number**: 5.5 (Prep Sprint)
- **Duration**: 1 week
- **Theme**: Code quality, test coverage, and architectural improvements
- **Goal**: Clean up technical debt and prepare codebase for Sprint 6 integrations

## Context
Before proceeding with Sprint 6's external integrations, we need to:
1. Fix all compilation errors and warnings
2. Address Credo issues (strict mode)
3. Ensure all tests pass
4. Fix dialyzer issues
5. Consider architectural improvements from feedback.md

## User Stories

### Story 1: Fix Compilation Errors & Warnings (3 pts)
**As a** Developer
**I want** clean compilation with no warnings
**So that** the codebase is stable and maintainable

**Acceptance Criteria:**
- [ ] Zero compilation errors
- [ ] Zero compilation warnings
- [ ] mix compile --warnings-as-errors passes
- [ ] All unused variables properly prefixed with _

**Technical Tasks:**
- [ ] Fix undefined variable errors in ParticipationAnalyzer
- [ ] Fix unused variable warnings across all contexts
- [ ] Fix duplicate function clause warnings
- [ ] Update all function signatures to handle unused params

**Known Issues to Fix:**
- `ParticipationAnalyzer`: undefined `fleet_activities` and `base_data` variables
- `CorporationAnalyzer.init/1`: unused `opts` variable
- `EffectivenessCalculator`: unused `total_participants` variable
- `ParticipationAnalyzer`: duplicate `format_hour/1` clauses

### Story 2: Address Credo Strict Mode Issues (3 pts)
**As a** Code Reviewer
**I want** all Credo issues resolved
**So that** code quality is consistently high

**Acceptance Criteria:**
- [ ] mix credo --strict passes with no issues
- [ ] All duplicated variable declarations fixed
- [ ] Module dependencies properly structured
- [ ] Cyclomatic complexity reduced where needed

**Technical Tasks:**
- [ ] Fix "Variable declared more than once" issues
- [ ] Resolve module dependency warnings
- [ ] Refactor high complexity functions
- [ ] Add credo:disable comments only where absolutely necessary

**Known Issues:**
- Multiple "warnings" variable declarations in threat analyzers
- Multiple "issues" variable declarations in database analyzers
- ErrorHandler and Error module circular dependencies

### Story 3: Comprehensive Test Coverage (4 pts)
**As a** QA Engineer
**I want** all tests passing with good coverage
**So that** we can deploy with confidence

**Acceptance Criteria:**
- [ ] mix test passes with 0 failures
- [ ] Test coverage > 80% for new modules
- [ ] All new bounded contexts have tests
- [ ] Integration tests for key workflows

**Technical Tasks:**
- [ ] Write tests for BattleAnalysisService
- [ ] Write tests for ChainIntelligenceService
- [ ] Write tests for new analyzers in bounded contexts
- [ ] Fix any broken tests from refactoring
- [ ] Add integration tests for surveillance workflows

### Story 4: Dialyzer Type Checking (2 pts)
**As a** Platform Engineer
**I want** dialyzer passing with no warnings
**So that** type safety is enforced

**Acceptance Criteria:**
- [ ] mix dialyzer passes cleanly
- [ ] All @spec annotations correct
- [ ] No unmatched return warnings
- [ ] Type specifications for all public functions

**Technical Tasks:**
- [ ] Run mix dialyzer and document all warnings
- [ ] Fix type specification mismatches
- [ ] Add missing @spec annotations
- [ ] Update PLT if needed

### Story 5: Initial Architecture Improvements (3 pts)
**As a** Tech Lead
**I want** cleaner architectural boundaries
**So that** the codebase is more maintainable

**Acceptance Criteria:**
- [ ] Document architectural improvement plan
- [ ] Implement quick wins from feedback.md
- [ ] Clean up deep nesting in lib/eve_dmv
- [ ] Group related modules better

**Technical Tasks:**
- [ ] Flatten config/ directory structure
- [ ] Move constants/isk.ex to pricing context
- [ ] Consolidate utils/ functions into proper domains
- [ ] Archive obsolete catch-all folders
- [ ] Document future umbrella app migration plan

### Story 6: Documentation & Cleanup (2 pts)
**As a** New Developer
**I want** clear, up-to-date documentation
**So that** I can onboard quickly

**Acceptance Criteria:**
- [ ] README.md updated with current setup
- [ ] CLAUDE.md reflects new contexts
- [ ] Outdated sprint docs archived
- [ ] API documentation current

**Technical Tasks:**
- [ ] Update setup instructions in README
- [ ] Document new bounded contexts in CLAUDE.md
- [ ] Archive completed sprint documentation
- [ ] Update API endpoint documentation
- [ ] Create architecture decision records (ADRs)

## Technical Debt Inventory

### Critical Issues (Must Fix)
1. **Compilation Errors**
   - ParticipationAnalyzer undefined variables
   - Module compilation failures

2. **Test Failures**
   - New modules lack test coverage
   - Integration tests may be broken

### High Priority Issues
1. **Credo Warnings**
   - Duplicate variable declarations
   - High cyclomatic complexity
   - Module dependencies

2. **Code Organization**
   - Deep directory nesting
   - Scattered configuration files
   - Mixed concerns in modules

### Medium Priority Issues
1. **Type Safety**
   - Missing @spec annotations
   - Dialyzer warnings

2. **Documentation**
   - Outdated setup guides
   - Missing architectural docs

## Success Metrics
- Zero compilation warnings/errors
- Zero Credo issues in strict mode
- 100% test pass rate
- Zero dialyzer warnings
- Clean CI/CD pipeline (all green)

## Sprint Burndown Tracking
Total Story Points: 17

### Day 1-2 Target (6 pts)
- [ ] Fix all compilation errors (3 pts)
- [ ] Start Credo fixes (1.5/3 pts)
- [ ] Document all test failures (0.5/4 pts)

### Day 3-4 Target (7 pts)
- [ ] Complete Credo fixes (1.5/3 pts)
- [ ] Write missing tests (3.5/4 pts)
- [ ] Fix dialyzer issues (2/2 pts)

### Day 5 Target (4 pts)
- [ ] Architecture improvements (3/3 pts)
- [ ] Documentation updates (1/2 pts)
- [ ] Final cleanup and review (1/2 pts)

## Definition of Done
- [ ] All compilation warnings and errors resolved
- [ ] mix credo --strict passes
- [ ] mix test passes with no failures
- [ ] mix dialyzer passes
- [ ] Documentation updated
- [ ] CI/CD pipeline fully green
- [ ] Code review completed
- [ ] No new technical debt introduced

## Notes
This sprint focuses entirely on quality and stability. No new features should be added. Any discovered bugs should be fixed immediately as part of the relevant story.

After this sprint, we'll have a rock-solid foundation for Sprint 6's external integrations.