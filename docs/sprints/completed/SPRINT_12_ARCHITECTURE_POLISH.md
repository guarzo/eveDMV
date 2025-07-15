# Sprint 12: Architecture & Polish

**Duration**: 2 weeks (standard)  
**Start Date**: 2025-07-14 (Ready to begin)  
**End Date**: 2025-07-28  
**Sprint Goal**: Complete architectural refactoring and polish deferred from Sprint 11  
**Philosophy**: "If it returns mock data, it's not done."
**Previous Sprint**: Sprint 11 Quality Debt Cleanup - ✅ COMPLETED (All 10 high-priority tasks finished)

---

## 🎯 Sprint Objective

### Primary Goal
Complete heavy architectural refactoring and implement advanced quality improvements building on Sprint 11's foundation.

### Success Criteria
- [ ] All massive files (>1800 lines) split into focused modules
- [ ] Process dictionary usage eliminated (replaced with ETS)
- [ ] Structured logging format implemented
- [ ] OpenTelemetry spans operational
- [ ] All undefined module references resolved
- [ ] Navigation links fully functional
- [ ] Context over-abstraction cleaned up

### Explicitly Out of Scope
- Adding new features or functionality
- Database schema changes
- Major UI/UX improvements
- Performance optimization beyond architectural fixes

---

## 📊 Sprint Backlog

### Deferred from Sprint 11 (35 points)

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| QUAL-10 | Remove process dictionary usage | 3 | HIGH | Replace with ETS tables |
| QUAL-11 | Add structured logging format | 2 | HIGH | JSON/map log format |
| QUAL-12 | Implement graceful task shutdown | 3 | HIGH | No brutal_kill timeouts |
| QUAL-14 | Add OpenTelemetry spans | 5 | MEDIUM | Tracing for task supervisors |
| QUAL-15 | Extract large module utilities | 5 | MEDIUM | Common helpers centralized |
| QUAL-16 | Refactor massive files (>1000 lines) | 13 | HIGH | Ship performance analyzer split |
| QUAL-18 | Fix undefined module references | 3 | MEDIUM | All module refs work |
| QUAL-19 | Implement missing route handlers | 2 | MEDIUM | No broken navigation links |
| QUAL-20 | Clean up over-abstraction in contexts | 5 | MEDIUM | Simpler CRUD operations |

**Total Points**: 41

---

## 📈 Daily Progress Tracking

### Day 0 - 2025-07-14 (Sprint Kickoff)
- **Started**: Sprint 12 planning, Sprint 11 retrospective completed
- **Completed**: Sprint 11 all 10 high-priority tasks ✅ DONE
- **Blockers**: None - clean foundation established
- **Reality Check**: ✅ Ready to begin architectural refactoring

### Sprint 11 Foundation Results - ✅ COMPLETED
- **Quality Gates**: ✅ Operational (scripts/quality_check.sh working)
- **GenericTaskSupervisor**: ✅ Implemented (~250 lines of duplicate code eliminated)
- **CI Infrastructure**: ✅ Parallelized and stable (quality enforcement active)
- **Test Coverage**: ✅ 11.2% baseline established (infrastructure functional)
- **Compilation**: ✅ Zero warnings with warnings-as-errors enabled
- **Credo**: ✅ Zero R-level issues (Sprint 11 goal achieved)
- **Dialyzer**: ✅ Baseline established (133 false positives filtered)

---

## 📋 TODO Items Analysis & Review

### Overview
Found **48 TODO comments** across the codebase representing systematic placeholder implementations. These were created during previous sprints to avoid Dialyzer type errors while building the UI structure.

### TODO Categories & Recommendations

#### 🔴 **High Priority - Address in Sprint 12** (7 TODOs)
**Impact**: Core functionality, user experience, foundation for other features

| Domain | File | Line | TODO | Recommendation | Effort |
|--------|------|------|------|----------------|--------|
| **Authentication** | `surveillance_profiles_live.ex` | 715 | Get from session/assigns when authentication is properly integrated | ✅ **IMPLEMENT** - Easy fix affecting UX | 1 day |
| **Market Intelligence** | `valuation_service.ex` | 14 | Implement real killmail valuation | ✅ **IMPLEMENT** - Required for ISK calculations | 2 days |
| **Market Intelligence** | `valuation_service.ex` | 25 | Implement real fleet valuation | ✅ **IMPLEMENT** - Foundation for economics | 1 day |
| **Battle Analysis** | `battle_analysis_service.ex` | 387 | Implement real battle killmail fetching | ✅ **IMPLEMENT** - Core kill analysis | 2 days |
| **Battle Analysis** | `battle_analysis_service.ex` | 394 | Implement real system kill fetching | ✅ **IMPLEMENT** - System-based queries | 1 day |
| **Battle Analysis** | `battle_analysis_service.ex` | 727 | Implement real ship classification | ✅ **IMPLEMENT** - Required for multiple features | 2 days |
| **Fleet Operations** | `composition_analyzer.ex` | 213 | Implement proper Ash query for killmail analysis | ✅ **IMPLEMENT** - Proper data access | 1 day |

**Total High Priority**: 10 days

#### 🟡 **Medium Priority - Future Sprints** (21 TODOs)
**Impact**: Feature completeness, intelligence scoring, fleet analysis

| Domain | Count | Examples | Recommendation | Effort |
|--------|-------|----------|----------------|--------|
| **Combat Intelligence Scoring** | 6 | Danger rating, hunter score, fleet command score | 📋 **CONVERT TO SPRINT IDEA** - Complete character intelligence system | 2 sprints |
| **Fleet Operations** | 4 | Fleet engagement analysis, statistics calculation | 📋 **CONVERT TO SPRINT IDEA** - Fleet engagement features | 1 sprint |
| **Surveillance Features** | 4 | Topology sync, threat analysis, activity prediction | 📋 **CONVERT TO SPRINT IDEA** - Chain monitoring system | 1 sprint |
| **Battle Analysis Advanced** | 7 | Tactical patterns, logistics ratios, turning points | 📋 **CONVERT TO SPRINT IDEA** - Advanced battle analysis | 2 sprints |

**Total Medium Priority**: 6 sprints

#### 🟢 **Low Priority - Technical Debt** (20 TODOs)
**Impact**: Nice-to-have features, advanced wormhole operations

| Domain | Count | Examples | Recommendation | Effort |
|--------|-------|----------|----------------|--------|
| **Wormhole Operations** | 18 | Mass optimization, chain intelligence, home defense | 🗑️ **REMOVE** - Complex domain-specific features | 4+ sprints |
| **Testing Infrastructure** | 3 | Test coverage for matching engine criteria | 🗑️ **REMOVE** - Test infrastructure improvements | 1 sprint |
| **Caching Systems** | 1 | Analysis cache score aggregation | 🗑️ **REMOVE OR DEFER** - Performance optimization | 2 days |

**Total Low Priority**: 5+ sprints

### 🎯 **Sprint 12 Action Plan**

#### Phase 1: TODO Comment Cleanup (Days 1-3)
1. **Remove Non-Essential TODOs**: Delete 20 wormhole operation TODOs and replace with GitHub issues
2. **Convert Medium Priority**: Create properly scoped GitHub issues for combat intelligence and fleet operations
3. **Document Decisions**: Update comments to reflect implementation decisions

#### Phase 2: High Priority Implementation (Days 4-10)
1. **Authentication Integration** - Fix session/assigns access
2. **Market Intelligence** - Implement killmail and fleet valuation 
3. **Battle Analysis Foundation** - Real killmail fetching and ship classification
4. **Fleet Operations** - Proper Ash queries for composition analysis

#### Phase 3: Quality Assurance (Days 11-14)
1. **Integration Testing** - Ensure new implementations work with existing data
2. **Performance Testing** - Validate database queries perform well
3. **Documentation Updates** - Update API documentation for implemented features

### 📊 **TODO Resolution Metrics**

#### Sprint 12 Targets:
- **TODOs Removed**: 20 low-priority items (40% reduction)
- **TODOs Implemented**: 7 high-priority items (foundation features)
- **TODOs Converted to Issues**: 21 medium-priority items (proper tracking)
- **Net TODO Reduction**: 27 items (56% reduction from 48 to 21)

#### Success Criteria:
- [ ] All authentication-related TODOs resolved
- [ ] Basic market intelligence operational
- [ ] Ship classification system working
- [ ] Battle analysis queries implemented
- [ ] All remaining TODOs have GitHub issues
- [ ] No TODO comments in production code without tracking

### 🔍 **TODO Review Questions for Discussion**

1. **Wormhole Operations**: These 18 TODOs represent a complete feature. Should we:
   - Remove all and create epic for future development?
   - Keep 3-4 most important and remove the rest?
   - Convert to issues but mark as "future enhancement"?

2. **Combat Intelligence**: The 6 scoring TODOs are tightly coupled. Should we:
   - Implement basic versions in Sprint 12?
   - Create a complete intelligence scoring epic?
   - Focus on one scoring type (danger rating) as foundation?

3. **Market Intelligence**: These 2 TODOs are foundational. Should we:
   - Implement with external API integration (Janice)?
   - Create simple internal price estimation first?
   - Focus on EVE market data integration?

4. **Battle Analysis**: These 7 TODOs range from basic to advanced. Should we:
   - Implement all basic queries in Sprint 12?
   - Focus on killmail fetching and ship classification only?
   - Create progressive enhancement roadmap?

5. **Testing TODOs**: These 3 TODOs are in test files. Should we:
   - Remove them entirely (testing is supporting work)?
   - Implement them to improve test coverage?
   - Convert to testing improvement issues?

---

## 🔄 Architecture Improvement Strategy

### Phase 1: Core Architecture (Days 1-5)
- **Process Dictionary → ETS Migration** (QUAL-10)
- **Structured Logging Implementation** (QUAL-11) 
- **Graceful Task Shutdown** (QUAL-12)
- **Fix Undefined Module References** (QUAL-18)

### Phase 2: Massive File Refactoring (Days 6-10)
- **ship_performance_analyzer.ex Split** (QUAL-16, highest priority)
- **character_analysis_live.ex Extraction** (QUAL-16 continued)
- **threat_scoring_engine.ex Domain Split** (QUAL-16 continued)
- **Extract Large Module Utilities** (QUAL-15)

### Phase 3: Polish & Observability (Days 11-14)
- **OpenTelemetry Spans Implementation** (QUAL-14)
- **Missing Route Handlers** (QUAL-19)
- **Context Over-abstraction Cleanup** (QUAL-20)
- **Integration Testing and Stabilization**

### Day 7: Mid-Sprint Review
- Progress against massive file refactoring
- Team capacity and merge conflict management
- Scope adjustment if needed

---

## 🏗️ Detailed Refactoring Plans

### Massive File Splits (QUAL-16: 13 points)

#### ship_performance_analyzer.ex (2,099 lines)
**Split into focused analyzers:**

```elixir
# New structure
lib/eve_dmv/contexts/battle_analysis/domain/
├── analyzers/
│   ├── dps_analyzer.ex           # Damage calculation and effectiveness
│   ├── survivability_analyzer.ex # Tank and defensive metrics
│   └── tactical_analyzer.ex      # Positioning and engagement patterns
└── ship_performance_coordinator.ex # Orchestrates the analyzers
```

**Migration strategy:**
1. Create analyzer interfaces/behaviors
2. Extract DPS logic first (lowest coupling)
3. Extract survivability logic
4. Extract tactical logic last (highest coupling)
5. Create coordinator that calls all analyzers
6. Update all references to use coordinator

#### character_analysis_live.ex (1,949 lines)
**Extract into components:**

```elixir
# New structure
lib/eve_dmv_web/live/character_analysis/
├── character_analysis_live.ex    # Main LiveView (orchestration only)
├── components/
│   ├── character_header.ex       # Character info display
│   ├── statistics_panel.ex       # Stats and metrics
│   ├── recent_activity.ex        # Activity feed
│   └── threat_assessment.ex      # Threat scoring display
└── helpers/
    ├── character_data_formatter.ex
    └── statistics_calculator.ex
```

#### threat_scoring_engine.ex (1,808 lines)
**Split by threat domain:**

```elixir
# New structure
lib/eve_dmv/contexts/combat_intelligence/domain/threat_scoring/
├── combat_threat_scorer.ex       # Combat-related threats
├── intelligence_threat_scorer.ex # Surveillance threats
├── fleet_threat_scorer.ex        # Fleet composition threats
└── threat_scoring_coordinator.ex # Orchestrates scoring
```

### Process Dictionary Elimination (QUAL-10: 3 points)

**Current pattern:**
```elixir
# Bad: Hidden mutable state
Process.put(:task_info, %{description: desc, start_time: now})
```

**New ETS-based approach:**
```elixir
# Good: Observable, crash-safe
:ets.insert(:task_metadata, {self(), %{description: desc, start_time: now}})

# Cleanup on task completion
:ets.delete(:task_metadata, self())
```

### Structured Logging (QUAL-11: 2 points)

**Implement consistent log format:**
```elixir
# Before
Logger.info("Task #{task_id} completed in #{duration}ms")

# After
Logger.info("Task completed", %{
  task_id: task_id,
  duration_ms: duration,
  status: :completed,
  supervisor: __MODULE__
})
```

### OpenTelemetry Integration (QUAL-14: 5 points)

**Add spans to task supervisors:**
```elixir
def start_task(fun, desc, timeout) do
  OpenTelemetry.with_span "task.execute", %{
    "task.description" => desc,
    "task.timeout" => timeout,
    "supervisor.module" => __MODULE__
  } do
    # Existing task logic
  end
end
```

---

## ✅ Sprint Completion Checklist

### Architecture Improvements
- [ ] Process dictionary usage eliminated
- [ ] ETS tables replace mutable state  
- [ ] Graceful task shutdown implemented
- [ ] Structured logging format consistent
- [ ] OpenTelemetry spans operational

### File Structure
- [ ] ship_performance_analyzer.ex split into 3 focused modules
- [ ] character_analysis_live.ex extracted into components
- [ ] threat_scoring_engine.ex split by domain
- [ ] Large module utilities centralized
- [ ] All file splits maintain functionality

### Navigation & References
- [ ] Undefined module references resolved
- [ ] Missing route handlers implemented
- [ ] Broken navigation links fixed
- [ ] All pages load without errors

### Quality Maintenance
- [ ] All new code follows Sprint 11 quality gates
- [ ] Test coverage maintained or improved
- [ ] No new Credo or Dialyzer issues introduced
- [ ] CI builds remain green throughout sprint

### TODO Resolution
- [ ] 20 low-priority TODOs removed (wormhole operations, testing, caching)
- [ ] 7 high-priority TODOs implemented (authentication, market intelligence, battle analysis)
- [ ] 21 medium-priority TODOs converted to GitHub issues
- [ ] Net TODO reduction of 56% (48 → 21 items)
- [ ] All remaining TODOs have proper issue tracking

---

## 📊 Success Metrics

### Code Structure
- **Massive Files**: 3 files >1800 lines → 0
- **Large Files**: 19 files >1000 lines → <10
- **Module Dependencies**: Reduced through utility extraction
- **Code Duplication**: Eliminated through centralized helpers
- **TODO Comments**: 48 items → 21 items (56% reduction)
- **Untracked Work**: 0 TODOs without GitHub issues

### Architecture Quality
- **Process Dictionary Usage**: Eliminated
- **Task Shutdown**: 100% graceful (no brutal_kill)
- **Logging Consistency**: Structured format across all modules
- **Observability**: OpenTelemetry spans operational

### User Experience
- **Broken References**: 0 undefined modules
- **Navigation**: 0 broken links
- **Page Load**: All pages functional
- **Performance**: No regressions from refactoring

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

**Sprint 13: Feature Development with Quality**
- Primary Goal: Implement one major feature using the new quality foundation
- Focus: Demonstrate sustainable development without accumulating technical debt
- Quality Requirements: Maintain all Sprint 11 & 12 quality standards

---

## 📁 Architecture Command Reference

```bash
# File Structure Validation
find lib/ -name "*.ex" -exec wc -l {} + | sort -nr | head -20  # Check largest files
mix xref graph --label compile-connected                       # Verify no cycles

# Architecture Testing
mix test --only architecture     # Test new module boundaries
mix test --only integration      # Test refactored components
mix test --only telemetry        # Test OpenTelemetry spans

# Performance Validation
mix eve.performance --analyze    # Ensure no regressions
mix dialyzer                     # Verify type safety maintained
```

---

**Remember**: This sprint builds on Sprint 11's foundation. Every architectural change should improve maintainability and developer experience while preserving functionality.