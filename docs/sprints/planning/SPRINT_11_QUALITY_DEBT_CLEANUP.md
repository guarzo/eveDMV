# Sprint 11: Quality Debt Cleanup

**Duration**: 2 weeks (standard)  
**Start Date**: 2025-07-14  
**End Date**: 2025-07-28  
**Sprint Goal**: Establish quality foundation with compilation warnings eliminated, critical Dialyzer issues reduced, and CI quality gates operational  
**Philosophy**: "If it returns mock data, it's not done."

---

## 🎯 Sprint Objective

### Primary Goal
Establish a solid quality foundation by eliminating critical technical debt and implementing quality gates that prevent future regressions.

### Success Criteria
- [ ] Zero compilation warnings
- [ ] All Credo readiness rules (R level) resolved  
- [ ] ≤85 Dialyzer errors (absolute target, not percentage)
- [ ] Test coverage reporting functional (30% minimum coverage)
- [ ] Quality gate scripts operational
- [ ] MTTR for quality regressions <4 hours

### Explicitly Out of Scope  
- Adding new features or functionality
- Performance optimization beyond fixing dead code
- Documentation improvements beyond fixing incorrect claims
- Heavy architectural refactors (moved to Sprint 12)

---

## 📊 Sprint Backlog

### Sprint 11: Foundation Quality (55 points)

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| QUAL-1 | Fix compilation warnings | 3 | HIGH | mix compile runs clean |
| QUAL-2 | Setup test coverage reporting | 2 | HIGH | mix test --cover works, 30% coverage |
| QUAL-3 | Fix Credo readiness issues (R) | 8 | HIGH | No R-level Credo warnings |
| QUAL-4A | Create Dialyzer baseline | 3 | HIGH | .dialyzer_ignore.exs for false positives |
| QUAL-4B | Fix critical Dialyzer issues | 8 | HIGH | ≤85 total Dialyzer errors |
| QUAL-5 | Convert TODO comments to tickets | 5 | MEDIUM | All TODOs tracked, not deleted |
| QUAL-7 | Create quality gate scripts | 2 | HIGH | Scripts prevent bad commits |
| QUAL-8 | Setup CI quality enforcement | 3 | HIGH | CI fails on quality violations |
| QUAL-9 | Refactor duplicate task supervisors | 8 | HIGH | Single GenericTaskSupervisor |
| QUAL-13 | Enable warnings-as-errors in CI | 1 | HIGH | Mix config updated |
| QUAL-17 | Remove debug/test code from production | 2 | HIGH | No IO.puts in production code |
| QUAL-21 | Add pre-commit hooks | 1 | HIGH | Local format/Credo checking |
| QUAL-22 | Baseline performance gate | 2 | MEDIUM | CI performance thresholds |
| QUAL-23 | Parallelize CI quality checks | 3 | MEDIUM | Credo + Dialyzer run parallel |
| QUAL-24 | Sprint ceremonies | 6 | HIGH | Kickoff, mid-sprint, retrospective |

**Total Points**: 55

### Deferred to Sprint 12: Architecture & Polish (35 points)

| Story ID | Description | Points | Priority | Moved Because |
|----------|-------------|---------|----------|---------------|
| QUAL-10 | Remove process dictionary usage | 3 | MEDIUM | Heavy refactor after foundation |
| QUAL-11 | Add structured logging format | 2 | MEDIUM | After GenericTaskSupervisor |
| QUAL-12 | Implement graceful task shutdown | 3 | MEDIUM | Architectural change |
| QUAL-14 | Add OpenTelemetry spans | 5 | LOW | After code stabilizes |
| QUAL-15 | Extract large module utilities | 5 | MEDIUM | Heavy refactor |
| QUAL-16 | Refactor massive files (>1000 lines) | 13 | HIGH | Merge conflict risk |
| QUAL-18 | Fix undefined module references | 3 | MEDIUM | Feature work |
| QUAL-19 | Implement missing route handlers | 2 | MEDIUM | Feature work |
| QUAL-20 | Clean up over-abstraction in contexts | 5 | MEDIUM | Architectural review needed |

---

## 📈 Daily Progress Tracking

### Day 0 - 2025-07-14 (Sprint Kickoff)
- **Started**: Sprint kickoff ceremony, backlog review
- **Completed**: Team alignment on scope and priorities
- **Blockers**: None
- **Reality Check**: ✅ 55-point realistic scope agreed

### Day 1 - 2025-07-15
- **Started**: Quality assessment and foundational fixes
- **Completed**: [To be filled]
- **Blockers**: [To be filled]
- **Reality Check**: [To be filled]

### Quality Baseline Metrics
- **Compilation Warnings**: 1 (format_relative_time missing)
- **Credo Issues**: 200+ (estimated from output)
- **Dialyzer Errors**: 841 
- **TODO Comments**: 84+
- **Test Coverage**: Unknown (tool not working)
- **Files**: 3443 total, 54 test files (1.6% test ratio)
- **Large Files**: 19 files >1000 lines (from cleanup.md analysis)
- **Massive Files**: 3 files >1800 lines requiring immediate refactoring
- **Debug Code**: 10+ lines of IO.puts in production modules

---

## 🔍 Current Quality Issues Analysis

### Critical Issues (Blocking Development)
1. **Compilation Warnings**: Missing `format_relative_time/1` function
2. **Test Infrastructure**: ExCoveralls not installed/configured
3. **Type Safety**: 841 Dialyzer errors indicating serious type issues
4. **Massive Files**: ship_performance_analyzer.ex (2,099 lines) blocks IDE performance
5. **Debug Code**: IO.puts statements in production modules

### High-Impact Issues
1. **Code Style**: Massive number of Credo R-level issues
2. **Dead Code**: Multiple unused functions identified by Dialyzer
3. **Type Specifications**: Many @spec annotations are incorrect

### Technical Debt
1. **TODO Comments**: 84+ placeholder implementations (500+ LOC of mock data)
2. **Module Complexity**: Several modules exceed dependency limits
3. **Test Coverage**: Very low test file ratio (1.6%)
4. **Code Duplication**: 3 task supervisors duplicate ~100 lines each
5. **Process Dictionary Usage**: Hidden mutable state in task metadata
6. **Large Modules**: FleetAnalyzer, BattleDetector exceed 300+ lines
7. **Raw SQL Queries**: Many modules use Repo.query with string interpolation
8. **Massive Files**: 19 files >1000 lines, 3 files >1800 lines
9. **Over-Abstraction**: Complex context hierarchies for simple CRUD
10. **Undefined References**: Missing StaticData.Universe module
11. **Broken Navigation**: Missing route handlers for killmail links

---

## 🔄 Quality Improvement Strategy

### Phase 1: Foundation + Architecture (Days 1-5)
- Fix compilation warnings  
- Enable warnings-as-errors in CI
- Setup test coverage infrastructure (30% minimum)
- **Refactor GenericTaskSupervisor FIRST** (enables other fixes)
- Remove debug/test code from production modules
- Create Dialyzer baseline (.dialyzer_ignore.exs)

### Phase 2: Quality Gates & Critical Fixes (Days 6-10)
- Address critical Dialyzer errors (target ≤85)
- Fix high-impact Credo readiness issues
- Convert TODO comments to tracked tickets
- Add pre-commit hooks
- Parallelize CI quality checks

### Phase 3: Polish + Stabilization (Days 11-14)
- Complete remaining Credo fixes
- Implement quality gate scripts
- Setup CI enforcement
- Baseline performance gate
- **Stabilization buffer** (1 day for cleanup)
- Sprint retrospective ceremony

### Day 7: Mid-Sprint Check-in
- Progress review against 55-point target
- Scope adjustment if needed
- Team velocity assessment

---

## ✅ Sprint Completion Checklist

### Code Quality
- [ ] Zero compilation warnings (`mix compile`)
- [ ] Zero Credo readiness issues (`mix credo`)
- [ ] <85 Dialyzer errors (`mix dialyzer`)
- [ ] Zero TODO comments in production code
- [ ] All modules have <15 dependencies
- [ ] Test coverage reporting functional

### Infrastructure
- [ ] ExCoveralls properly configured
- [ ] Quality gate scripts created
- [ ] CI pipeline enforces quality standards
- [ ] Pre-commit hooks prevent quality regressions
- [ ] Warnings-as-errors enabled in CI
- [ ] OpenTelemetry spans implemented

### Architecture Improvements
- [ ] GenericTaskSupervisor replaces 3 duplicate supervisors
- [ ] Process dictionary usage eliminated
- [ ] ETS tables replace mutable state
- [ ] Graceful task shutdown implemented
- [ ] Large modules split into focused utilities
- [ ] Massive files refactored (ship_performance_analyzer.ex split)
- [ ] Debug/test code removed from production modules
- [ ] Over-abstracted contexts simplified

### Module & Navigation Fixes
- [ ] Undefined module references resolved
- [ ] Missing route handlers implemented
- [ ] Broken navigation links fixed
- [ ] StaticData.Universe module implemented

### Documentation
- [ ] Quality standards documented
- [ ] CLAUDE.md updated with quality commands
- [ ] Sprint retrospective completed
- [ ] Quality improvement metrics tracked

---

## 🚨 Quality Issues Breakdown

### Compilation Issues
```
lib/eve_dmv_web/live/system_live.html.heex:383:51
EveDmvWeb.FormatHelpers.format_relative_time/1 is undefined
```

### Top Credo Issue Categories
1. **Number Formatting**: 50+ instances of unformatted large numbers
2. **Pipeline Issues**: 30+ single-function pipes
3. **Module Dependencies**: 3 modules exceed 15 dependency limit
4. **Import/Alias Order**: Multiple ordering violations
5. **Nested Aliasing**: 20+ instances of nested module calls

### Top Dialyzer Issue Categories
1. **Type Specifications**: 150+ @spec supertype issues
2. **Function Calls**: 200+ never-succeeding calls
3. **Pattern Matching**: 100+ impossible patterns
4. **Dead Code**: 50+ unused functions
5. **Guard Failures**: 20+ impossible guards

### TODO Comment Distribution
- Combat Intelligence: 15 TODOs
- Wormhole Operations: 12 TODOs  
- Fleet Operations: 8 TODOs
- Surveillance: 10 TODOs
- Market Intelligence: 5 TODOs
- Other: 34 TODOs

---

## 📊 Success Metrics

### Quality Metrics (Sprint 11 Targets)
- **Compilation Warnings**: 1 → 0
- **Credo R Issues**: 200+ → 0
- **Dialyzer Errors**: 841 → ≤85 (absolute target)
- **Test Coverage**: Unknown → ≥30%
- **TODO Comments**: 84+ → All converted to tracked tickets
- **Debug Code**: 10+ IO.puts statements → 0
- **MTTR for Quality Issues**: Baseline → <4 hours

### Deferred to Sprint 12
- **Massive Files**: 3 files >1800 lines (architectural refactor)
- **Large Files**: 19 files >1000 lines (merge conflict risk)
- **Module Dependencies**: 3 violations (will resolve with file splits)
- **Undefined References**: 5+ broken refs (feature work)

### Development Velocity Impact
- **CI Build Time**: Measure before/after
- **Developer Confidence**: Subjective assessment
- **Merge Conflicts**: Track reduction in quality-related conflicts

---

## 🔄 Sprint Retrospective

### What Went Well
[To be filled during sprint]

### What Didn't Go Well
[To be filled during sprint]

### Key Learnings
[To be filled during sprint]

### Action Items for Next Sprint
[To be filled during sprint]

---

## 🚀 Next Sprint Recommendation

This quality sprint should establish the foundation for sustainable development. The next sprint should focus on implementing one major feature with full quality standards from the start, demonstrating that we can deliver features without accumulating technical debt.

**Recommended Sprint 12: Battle Analysis Foundation**
- Primary Goal: Implement one core battle analysis feature with full test coverage
- Estimated Points: 21 (reduced due to quality overhead)
- Quality Requirements: Zero quality violations introduced

---

## 📁 Quality Command Reference

```bash
# Quality Check Suite
mix compile --warnings-as-errors  # Check compilation
mix credo --strict                # Static analysis  
mix dialyzer                      # Type checking
mix test --cover                  # Test coverage
mix format --check-formatted      # Code formatting
mix xref graph --label compile-connected  # Detect cyclic dependencies
mix deps.audit                   # Security vulnerability check

# Quality Fixes
mix format                        # Auto-fix formatting
mix credo --strict --fix          # Auto-fix some Credo issues
mix deps.clean --unused           # Remove unused dependencies

# Custom Quality Script (to be created)
./scripts/quality_check.sh        # Run all quality checks
./scripts/quality_fix.sh          # Run all auto-fixes

# Performance Baseline (new)
mix eve.performance --analyze     # CI performance thresholds

# Pre-commit Hooks (new)
pre-commit run --all-files        # Local quality checks
```

## 🏗️ Architecture Refactoring Details

### GenericTaskSupervisor Implementation
Based on ideas.md analysis, we'll create a single macro-based supervisor to replace:
- `UiTaskSupervisor` 
- `BackgroundTaskSupervisor`
- `RealtimeTaskSupervisor`

**Benefits:**
- Removes ~250 lines of duplicated code
- Consistent logging/telemetry across all supervisors
- Single source of truth for task management policies

### Process Dictionary Elimination
Replace `Process.put(:task_info, ...)` pattern with ETS tables:
- Better observability 
- No state leaks on crashes
- Dialyzer-friendly approach

### Graceful Shutdown Implementation  
Replace `Task.shutdown(task, :brutal_kill)` with:
- `DynamicSupervisor.start_child/2` with proper shutdown timeouts
- Explicit error tuple propagation
- Work preservation during shutdowns

### Dialyzer Baseline Strategy  
Create `.dialyzer_ignore.exs` to separate false positives from real issues:
- Document known false positives with rationale
- Enable incremental progress tracking  
- Allow CI gating while errors remain

### Debug Code Cleanup (Sprint 11)
Remove production debug statements from:
- `battle_detector_fixed.ex:314-358` - IO.puts in test functions
- Any remaining IO.inspect or IO.puts in lib/ directory
- Move test functions to test/ directory

### CI Parallelization (Sprint 11)
Split quality checks to reduce build time by ~40%:
- Run Credo and Dialyzer in parallel GitHub Actions jobs
- Cache `_build/test` artifacts separately
- Create reusable composite action for quality scripts

### Pre-commit Hook Implementation
Local quality gates for faster feedback:
- `mix format` auto-fix before commit
- Credo readiness checks
- Prevent trivial CI failures

## 🚀 Sprint 12 Preview: Architecture & Polish

### Deferred Heavy Refactors
**Massive File Splits** (deferred due to merge conflict risk):
- `ship_performance_analyzer.ex` (2,099 lines) → DPS/Survivability/Tactical analyzers
- `character_analysis_live.ex` (1,949 lines) → Extract business logic and components  
- `threat_scoring_engine.ex` (1,808 lines) → Split by threat domain

### Advanced Architecture
- Process dictionary → ETS tables migration
- Structured logging format (after GenericTaskSupervisor)
- Graceful task shutdown implementation
- OpenTelemetry spans and observability
- Context over-abstraction cleanup

---

**Remember**: This sprint is about creating a sustainable development environment. Every fix should include a way to prevent the same issue from happening again.