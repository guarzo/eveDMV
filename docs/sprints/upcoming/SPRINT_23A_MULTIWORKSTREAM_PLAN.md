# Sprint 23A: Module Refactoring - 5 Parallel Workstream Plan

**Generated**: 2025-07-21  
**Duration**: 8 days (2025-08-18 to 2025-08-29)  
**Goal**: Eliminate all 22 modules >1000 lines through parallel workstream execution

---

## 📊 Current State Analysis (Baseline)

**Critical Discovery**: We have **22 modules >1000 lines** totaling **40,827 lines** that need refactoring.

### Top Priority Modules (Actual Line Counts)
1. `battle_analysis_service.ex` - **5,376 lines** *(reduced from 6,883 - 22% improvement already!)*
2. `cross_system_analyzer.ex` - **3,714 lines** 
3. `fleet_composition_analyzer.ex` - **3,236 lines**
4. `battle_curator.ex` - **2,692 lines**
5. `cross_system_coordinator.ex` - **2,495 lines**

### Complete Module Inventory (22 Modules >1000 lines)
| # | Module | Lines | Workstream | Target |
|---|--------|-------|------------|--------|
| 1 | battle_analysis_service.ex | 5,376 | Alpha | <400 |
| 2 | cross_system_analyzer.ex | 3,714 | Beta | <400 |
| 3 | fleet_composition_analyzer.ex | 3,236 | Alpha | <400 |
| 4 | battle_curator.ex | 2,692 | Gamma | <400 |
| 5 | cross_system_coordinator.ex | 2,495 | Beta | <400 |
| 6 | ship_performance_analyzer.ex | 2,106 | Gamma | <400 |
| 7 | outcome_analyzer.ex | 2,051 | Alpha | <400 |
| 8 | threat_scoring_engine.ex | 1,685 | Gamma | <400 |
| 9 | home_defense_analyzer.ex | 1,529 | Delta | <400 |
| 10 | combat_doctrine_analyzer.ex | 1,493 | Delta | <400 |
| 11 | character_data_loader.ex | 1,478 | Delta | <400 |
| 12 | advanced_fleet_analyzer.ex | 1,471 | Alpha | <400 |
| 13 | composition_analyzer.ex | 1,361 | Gamma | <400 |
| 14 | battle_analysis_live.ex | 1,360 | Epsilon | <400 |
| 15 | timeline_analyzer.ex | 1,331 | Delta | <400 |
| 16 | recruitment_vetter.ex | 1,316 | Epsilon | <400 |
| 17 | fleet_operations_live.ex | 1,191 | Epsilon | <400 |
| 18 | fleet_analyzer.ex | 1,164 | Epsilon | <400 |
| 19 | intelligence_correlator.ex | 1,109 | Beta | <400 |
| 20 | member_activity_analyzer.ex | 1,104 | Epsilon | <400 |
| 21 | vulnerability_scanner.ex | 1,100 | Epsilon | <400 |
| 22 | wh_vetting_analyzer.ex | 1,030 | Delta | <400 |

**Total Lines to Refactor**: 40,827 lines → Target: <8,800 lines (78% reduction)

---

## 🚀 5-Workstream Parallel Execution Plan

### **Workstream Alpha: Combat Intelligence Core** 
**Owner**: Lead Architect | **Duration**: 8 days | **Lines**: ~11,100

**Modules**:
- `battle_analysis_service.ex` (5,376 lines → <400)
- `fleet_composition_analyzer.ex` (3,236 lines → <400) 
- `outcome_analyzer.ex` (2,051 lines → <400)
- `advanced_fleet_analyzer.ex` (1,471 lines → <400)

**Refactoring Strategy**:
```
lib/eve_dmv/contexts/combat_intelligence/domain/
├── battle_analysis_service.ex (~300 lines) # Main orchestrator
├── battle_analysis/
│   ├── data_collectors/
│   │   ├── killmail_collector.ex
│   │   ├── participant_collector.ex
│   │   └── system_collector.ex
│   ├── analyzers/
│   │   ├── engagement_analyzer.ex
│   │   ├── tactical_analyzer.ex
│   │   └── outcome_analyzer.ex
│   ├── processors/
│   │   ├── battle_processor.ex
│   │   ├── timeline_processor.ex
│   │   └── metrics_processor.ex
│   └── coordinators/
│       ├── analysis_coordinator.ex
│       └── results_coordinator.ex
```

### **Workstream Beta: Intelligence Infrastructure**
**Owner**: Systems Architect | **Duration**: 7 days | **Lines**: ~7,300

**Modules**:
- `cross_system_analyzer.ex` (3,714 lines → <400)
- `cross_system_coordinator.ex` (2,495 lines → <400)
- `intelligence_correlator.ex` (1,109 lines → <400)

**Refactoring Strategy**:
```
lib/eve_dmv/contexts/intelligence_infrastructure/domain/
├── cross_system_analyzer.ex (~200 lines) # Main interface
├── cross_system/
│   ├── analyzers/
│   │   ├── single_system_analyzer.ex
│   │   ├── multi_system_analyzer.ex
│   │   └── regional_analyzer.ex
│   ├── correlators/
│   │   ├── activity_correlator.ex
│   │   ├── threat_correlator.ex
│   │   └── pattern_correlator.ex
│   └── coordinators/
│       ├── cross_system_coordinator.ex
│       └── intelligence_coordinator.ex
```

### **Workstream Gamma: Domain Analyzers**
**Owner**: Domain Expert | **Duration**: 6 days | **Lines**: ~6,800

**Modules**:
- `battle_curator.ex` (2,692 lines → <400)
- `ship_performance_analyzer.ex` (2,106 lines → <400)
- `threat_scoring_engine.ex` (1,685 lines → <400)
- `composition_analyzer.ex` (1,361 lines → <400)

**Refactoring Strategy**: Extract curation services, performance calculators, scoring engines.

### **Workstream Delta: Specialized Operations**
**Owner**: Operations Lead | **Duration**: 5 days | **Lines**: ~6,900

**Modules**:
- `home_defense_analyzer.ex` (1,529 lines → <400)
- `combat_doctrine_analyzer.ex` (1,493 lines → <400)
- `character_data_loader.ex` (1,478 lines → <400)
- `timeline_analyzer.ex` (1,331 lines → <400)
- `wh_vetting_analyzer.ex` (1,030 lines → <400)

**Refactoring Strategy**: Extract domain-specific utilities and shared components.

### **Workstream Epsilon: Web & Shared Components**
**Owner**: Frontend Lead | **Duration**: 4 days | **Lines**: ~6,100

**Modules**:
- `battle_analysis_live.ex` (1,360 lines → <400)
- `recruitment_vetter.ex` (1,316 lines → <400)
- `fleet_operations_live.ex` (1,191 lines → <400)
- `fleet_analyzer.ex` (1,164 lines → <400)
- `member_activity_analyzer.ex` (1,104 lines → <400)
- `vulnerability_scanner.ex` (1,100 lines → <400)

**Refactoring Strategy**: Extract LiveView helpers, shared web utilities, create component libraries.

---

## 📅 Day-by-Day Execution Timeline

### **Days 1-2: Foundation & Analysis** (Aug 18-19)
**All Workstreams**:
- [ ] Dependency mapping and module structure analysis
- [ ] Create workstream-specific validation scripts
- [ ] Set up branch strategy and merge coordination

**Alpha (Combat Intelligence)**:
- [ ] Begin `battle_analysis_service.ex` extraction
- [ ] Identify data collectors, analyzers, processors patterns
- [ ] Create skeleton structure for new modules

**Beta (Intelligence Infrastructure)**:
- [ ] Start `cross_system_analyzer.ex` breakdown
- [ ] Map single vs multi-system analysis boundaries
- [ ] Extract correlator interfaces

### **Days 3-5: Core Refactoring** (Aug 20-22)
**Alpha**:
- [ ] Complete battle analysis service decomposition
- [ ] Extract fleet composition analyzer components
- [ ] Migrate outcome analyzer logic
- [ ] Integration testing for extracted modules

**Beta**:
- [ ] Finish intelligence infrastructure separation
- [ ] Complete cross-system coordination refactoring
- [ ] Validate intelligence correlator extraction

**Gamma (Domain Analyzers)**:
- [ ] Begin battle curator service extraction
- [ ] Start ship performance analyzer breakdown
- [ ] Extract threat scoring engine components

**Delta (Specialized Operations)**:
- [ ] Start home defense analyzer refactoring
- [ ] Begin combat doctrine analyzer extraction

### **Days 6-8: Integration & Finalization** (Aug 25-27)
**Alpha**:
- [ ] Integration testing and final optimization
- [ ] Performance benchmarking for extracted modules
- [ ] Documentation updates

**Beta**:
- [ ] Complete cross-system coordination refactoring
- [ ] Final integration testing
- [ ] Performance validation

**Gamma**:
- [ ] Complete all domain analyzer extractions
- [ ] Integration testing across domain boundaries
- [ ] Shared utility consolidation

**Delta**:
- [ ] Complete specialized operations refactoring
- [ ] Character data loader optimization
- [ ] Timeline analyzer modularization

**Epsilon (Web Components)**:
- [ ] Accelerated web component refactoring
- [ ] LiveView helper extraction
- [ ] Component library creation

### **Days 9-10: Validation & Quality Gates** (Aug 28-29)
**All Workstreams**:
- [ ] Final testing and quality validation
- [ ] Cross-workstream dependency verification
- [ ] Performance impact assessment
- [ ] Documentation updates and API finalization

---

## 🛡️ Risk Mitigation Strategy

### **Technical Risks & Mitigations**
| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Circular Dependencies | High | Medium | Pre-refactoring dependency mapping, automated detection |
| Test Failures | High | Medium | Continuous testing after each module split |
| Performance Degradation | Medium | Low | Benchmarking before/after each major refactoring |
| Integration Issues | High | Low | Daily integration testing, interface stability |

### **Process Risks & Mitigations**
| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Workstream Conflicts | Medium | Medium | Daily standup coordination, merge windows |
| Merge Conflicts | Medium | High | Feature branch strategy, automated conflict detection |
| Scope Creep | High | Medium | Strict line count targets, no feature additions |
| Timeline Slippage | High | Low | Buffer days, scope flexibility for stretch goals |

### **Quality Risks & Mitigations**
| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Module Boundary Violations | Medium | Medium | Automated architecture validation scripts |
| Lost Functionality | High | Low | Comprehensive integration test suite |
| Documentation Drift | Low | High | Documentation updates during refactoring |
| Poor Module Design | Medium | Low | Architecture review gates, domain modeling |

---

## ✅ Validation Gates & Success Criteria

### **Daily Validation Gates**
**Each Workstream Must Pass Daily**:
```bash
# Daily validation script per workstream
./scripts/validate_workstream_alpha.sh
./scripts/validate_workstream_beta.sh
./scripts/validate_workstream_gamma.sh
./scripts/validate_workstream_delta.sh
./scripts/validate_workstream_epsilon.sh

# Cross-workstream validation
./scripts/check_circular_deps.sh
./scripts/module_size_monitor.sh
```

**Requirements**:
- [ ] All tests passing for modified modules
- [ ] No new compilation warnings
- [ ] Module line counts within targets
- [ ] No circular dependencies introduced

### **Mid-Sprint Validation Gate (Day 5 - Aug 22)**
**Critical Checkpoint**:
- [ ] ≥12 modules successfully refactored (55% of target)
- [ ] All tests passing after each refactoring
- [ ] No circular dependencies introduced
- [ ] Module boundaries clear and logical
- [ ] Workstream velocity on track for completion

**Continue Criteria**:
- ✅ >10 modules refactored (45% minimum)
- ✅ All workstreams progressing on schedule
- ✅ No major technical blockers discovered

**Pause/Reassess Criteria**:
- 🛑 <8 modules refactored (major velocity issue)
- 🛑 Test failures from refactoring work
- 🛑 Multiple workstreams behind schedule

### **Final Success Criteria (Day 10 - Aug 29)**
**Critical Requirements**:
- [ ] **0 modules >1000 lines** (critical requirement achieved)
- [ ] **<5 modules >500 lines** (stretch goal)
- [ ] **All functionality preserved** (100% test coverage maintained)
- [ ] **Quality score improved** from 55 to 65+
- [ ] **No circular dependencies** in module graph
- [ ] **Clear module boundaries** established

**Handoff Requirements for Sprint 24**:
- [ ] Clean, maintainable module architecture established
- [ ] All tests passing with refactored modules
- [ ] Foundation ready for placeholder elimination work
- [ ] Team comfortable with new module structure

---

## 🔧 Automation & Tooling

### **Validation Scripts** (To Be Created)
```bash
# Workstream-specific validation
./scripts/validate_workstream_alpha.sh    # Combat Intelligence validation
./scripts/validate_workstream_beta.sh     # Intelligence Infrastructure validation  
./scripts/validate_workstream_gamma.sh    # Domain Analyzers validation
./scripts/validate_workstream_delta.sh    # Specialized Operations validation
./scripts/validate_workstream_epsilon.sh  # Web Components validation

# Cross-workstream validation
./scripts/check_circular_deps.sh          # Dependency cycle detection
./scripts/module_size_monitor.sh          # Real-time line count tracking
./scripts/integration_test_runner.sh      # Full integration test suite
./scripts/performance_benchmark.sh        # Before/after performance comparison
```

### **Module Size Monitoring**
```bash
# Real-time monitoring script
while true; do
  large_modules=$(find lib -name "*.ex" -exec wc -l {} \; | awk '$1 > 1000' | wc -l)
  echo "$(date): ${large_modules} modules still >1000 lines"
  sleep 300  # Check every 5 minutes
done
```

### **Shared Utilities Strategy**
**Extract Common Patterns Into**:
```
lib/eve_dmv/shared/
├── query_helpers.ex           # Database query patterns
├── data_transformers.ex       # Data transformation utilities
├── validation_utils.ex        # Validation logic
├── error_handling.ex          # Error handling boilerplate
├── telemetry_helpers.ex       # Telemetry and logging
├── math_utils.ex              # Mathematical calculations
└── time_utils.ex              # Time/date utilities
```

---

## 📊 Metrics & Tracking

### **Progress Tracking**
| Metric | Baseline | Day 3 Target | Day 5 Target | Day 8 Target | Final Target |
|--------|----------|--------------|--------------|--------------|--------------|
| Modules >1000 lines | 22 | 18 | 11 | 3 | 0 |
| Modules >500 lines | 35 | 32 | 28 | 20 | <5 |
| Total lines in large modules | 40,827 | 32,000 | 20,000 | 10,000 | <8,800 |
| Average module size (top 22) | 1,855 | 1,400 | 900 | 500 | <400 |

### **Quality Metrics**
- **Code Coverage**: Maintain 70%+ throughout refactoring
- **Cyclomatic Complexity**: Reduce average complexity by 30%
- **Code Duplication**: Reduce duplication through shared utilities
- **Module Cohesion**: Improve cohesion scores through clear boundaries

### **Performance Metrics**
- **Query Performance**: No degradation in critical paths
- **Memory Usage**: Monitor for memory leaks from module restructuring
- **Response Times**: Maintain <100ms for critical operations

---

## 🔄 Branch Strategy & Merge Coordination

### **Branch Structure**
```
main
├── sprint-23-alpha-combat-intelligence
├── sprint-23-beta-infrastructure  
├── sprint-23-gamma-analyzers
├── sprint-23-delta-operations
└── sprint-23-epsilon-web
```

### **Merge Windows**
- **Day 3 PM**: Alpha → main (battle_analysis_service completed)
- **Day 5 PM**: Beta → main (cross_system_analyzer completed)  
- **Day 7 PM**: Gamma, Delta → main (domain analyzers completed)
- **Day 9 PM**: Epsilon → main (web components completed)
- **Day 10 AM**: Final integration and validation

### **Conflict Resolution**
1. **Daily sync meetings** at 9 AM for all workstream leads
2. **Merge conflict prevention** through interface contracts
3. **Automated merge testing** before each merge window
4. **Rollback procedures** for failed integrations

---

## 🎯 Success Indicators by Workstream

### **Alpha Success (Combat Intelligence)**
- `battle_analysis_service.ex`: 5,376 → <400 lines (93% reduction)
- Clear separation of data collection, analysis, and processing
- All battle analysis functionality preserved
- Performance benchmarks maintained

### **Beta Success (Intelligence Infrastructure)**  
- `cross_system_analyzer.ex`: 3,714 → <400 lines (89% reduction)
- Single vs multi-system analysis clearly separated
- Intelligence correlation properly modularized
- Cross-system coordination streamlined

### **Gamma Success (Domain Analyzers)**
- All 4 modules reduced to <400 lines each
- Domain-specific logic properly encapsulated
- Shared utilities extracted and reused
- Clear interfaces between analyzers

### **Delta Success (Specialized Operations)**
- All 5 modules reduced to <400 lines each  
- Character data loading optimized
- Timeline analysis modularized
- Wormhole operations properly structured

### **Epsilon Success (Web Components)**
- All 6 LiveView modules reduced to <400 lines each
- Shared web utilities created
- Component library established
- UI logic properly separated from business logic

---

## 📋 Pre-Sprint Checklist

### **Before Starting Sprint 23**
- [ ] All Sprint 21 validation gates passed
- [ ] Current test suite at 100% pass rate
- [ ] No critical compilation errors
- [ ] Workstream leads assigned and briefed
- [ ] Branch strategy implemented
- [ ] Validation scripts created and tested
- [ ] Baseline metrics captured
- [ ] Risk mitigation plans reviewed

### **Team Readiness**
- [ ] All workstream leads understand refactoring strategy
- [ ] Dependency mapping completed
- [ ] Module boundary contracts defined
- [ ] Integration test suite verified
- [ ] Performance benchmarking tools ready

---

## 🚀 Sprint 24 Handoff Preparation

### **Architecture Foundation for Sprint 24**
- **Clean module structure** with clear boundaries
- **Shared utilities** eliminating code duplication  
- **Stable interfaces** ready for placeholder elimination
- **Comprehensive test coverage** for confident refactoring

### **Sprint 24 Dependencies Met**
- All large modules refactored into maintainable components
- Module architecture supports feature completion work
- Quality foundation established for placeholder elimination
- Team familiar with new codebase organization

---

*This parallel workstream approach reduces Sprint 23 timeline from 10 days to 8 days while managing complexity through specialized teams and clear boundaries. Each workstream can proceed independently while coordination gates prevent integration issues.*

**Plan Status**: Ready for execution  
**Risk Level**: Medium (managed through parallel execution and validation gates)  
**Success Probability**: High (based on previous refactoring success with battle_analysis_service.ex)