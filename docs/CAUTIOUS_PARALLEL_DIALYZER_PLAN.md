# Cautious Parallel Dialyzer Reduction Plan

## Learning from Phase 2 Failure
✅ **Parallel workstreams CAN work** - the concept is sound
❌ **Lack of coordination caused disaster** - need better safety protocols
❌ **Over-aggressive targets backfired** - need realistic goals
❌ **No dependency verification** - need cross-workstream validation

## New Cautious Parallel Strategy

### Core Safety Principles
1. **File-Level Locking**: Strict domain boundaries to prevent conflicts
2. **Dependency Coordination**: Shared function registry to prevent breaking calls
3. **Conservative Targets**: 30-40% reduction instead of 80%
4. **Continuous Integration**: Daily merges with validation
5. **Immediate Rollback**: Any workstream causing regression gets rolled back

---

## 5 Parallel Workstreams with Enhanced Safety

### Workstream Alpha: Infrastructure & Platform (Domain A)
**File Scope**: `lib/eve_dmv/platform/`, `lib/eve_dmv/external/`, `lib/eve_dmv/cache/`
**Target**: 150-200 error reduction
**Risk**: Low (isolated infrastructure modules)

**Enhanced Safety Measures**:
- **Dependency Lock**: Register all public functions in shared tracker before removal
- **Cross-reference Check**: Use `mix xref` to verify no external calls
- **Batch Size**: Max 10 functions removed per day
- **Integration Test**: Daily merge with other workstreams

### Workstream Beta: Battle Analysis Context (Domain B)  
**File Scope**: `lib/eve_dmv/contexts/battle_analysis/`, `lib/eve_dmv/contexts/combat/`
**Target**: 200-250 error reduction
**Risk**: Medium (complex domain but isolated)

**Enhanced Safety Measures**:
- **Interface Protection**: Never remove public API functions
- **Internal Only**: Focus on private functions within modules
- **Pattern Safety**: Only fix obvious type mismatches
- **Daily Validation**: Run domain-specific tests after each change

### Workstream Gamma: Intelligence & Surveillance (Domain C)
**File Scope**: `lib/eve_dmv/contexts/*intelligence*/`, `lib/eve_dmv/contexts/surveillance/`  
**Target**: 150-200 error reduction
**Risk**: Medium (core logic but well-defined boundaries)

**Enhanced Safety Measures**:
- **Algorithm Preservation**: Never change core intelligence logic
- **Spec-Only Fixes**: Focus on @spec alignment rather than behavior changes
- **Incremental Testing**: Test intelligence functions in IEx after changes
- **Documentation**: Document every algorithmic assumption

### Workstream Delta: Wormhole & Corporation (Domain D)
**File Scope**: `lib/eve_dmv/contexts/wormhole_operations/`, `lib/eve_dmv/contexts/corporation*/`
**Target**: 100-150 error reduction  
**Risk**: Low-Medium (specialized domains)

**Enhanced Safety Measures**:
- **Business Logic Lock**: Preserve all recruitment/analysis logic
- **Pattern-Only**: Focus on pattern matching and guard fixes
- **Manual Review**: All changes reviewed before commit
- **Domain Testing**: Test wormhole operations after changes

### Workstream Epsilon: LiveView & Web Interface (Domain E)
**File Scope**: `lib/eve_dmv_web/`, UI-related contexts
**Target**: 100-150 error reduction
**Risk**: Low (UI layer, clear separation)

**Enhanced Safety Measures**:
- **UI Preservation**: Never break LiveView functionality  
- **Component Safety**: Test components individually
- **PubSub Protection**: Preserve all real-time update mechanisms
- **Visual Testing**: Verify UI still renders correctly

---

## Enhanced Coordination Mechanisms

### 1. Shared Function Registry
**File**: `/workspace/.dialyzer_progress/function_registry.json`
**Purpose**: Track all public functions across workstreams

```json
{
  "public_functions": {
    "EveDmv.BattleAnalysis.detect_battles/2": {
      "owner_workstream": "beta",
      "callers": ["gamma", "delta"],
      "status": "protected"
    }
  },
  "removal_requests": {
    "EveDmv.Utils.deprecated_function/1": {
      "requesting_workstream": "alpha",
      "verification_needed": ["beta", "gamma"]
    }
  }
}
```

### 2. Daily Integration Protocol
**Time**: End of each day
**Process**:
1. All workstreams commit their changes to separate branches
2. Run automated merge simulation
3. If conflicts detected, coordinate resolution
4. Merge to shared integration branch
5. Run full dialyzer validation on integrated code
6. If errors increase, identify and rollback problematic workstream

### 3. Cross-Workstream Communication
**Channel**: Shared progress document updated hourly
**Content**:
- Current error count per workstream
- Functions removed/modified
- Issues encountered
- Help requests

### 4. Conflict Resolution Process
**Scenario**: Workstream A wants to remove function that Workstream B calls

**Process**:
1. Workstream A logs removal request in shared registry
2. Workstream B gets notification and either:
   - Confirms function is unused: Approve removal
   - Confirms function is needed: Request preservation
   - Uncertain: Request investigation
3. If preservation requested, find alternative solution
4. Only proceed when all workstreams agree

---

## Enhanced Safety Protocols

### Before Function Removal
```bash
# 1. Check cross-workstream dependencies
./scripts/check_cross_workstream_deps.sh <module> <function>

# 2. Register removal intent
./scripts/register_removal_request.sh <workstream> <module> <function>

# 3. Wait for approval from affected workstreams
./scripts/await_removal_approval.sh <request_id>

# 4. Proceed with removal only after approval
```

### Daily Validation Gates
```bash
# 1. Individual workstream validation
mix dialyzer --format short | grep "Total errors" > workstream_alpha_count.txt

# 2. Integration testing
git checkout integration-branch
git merge workstream-alpha workstream-beta workstream-gamma workstream-delta workstream-epsilon
mix compile
mix dialyzer --format short | grep "Total errors" > integration_count.txt

# 3. Regression detection
if integration_errors > baseline_errors + 50; then
  echo "REGRESSION DETECTED - INVESTIGATING"
  ./scripts/identify_problematic_workstream.sh
fi
```

### Rollback Procedures
1. **Individual Workstream Rollback**: If one workstream causes issues
2. **Selective Integration**: Merge only successful workstreams
3. **Full Rollback**: If integration itself fails
4. **Forensic Analysis**: Understand what went wrong

---

## Realistic Targets

### Conservative Parallel Goals
| Workstream | Domain | Error Reduction | Risk Level |
|------------|--------|-----------------|------------|
| Alpha | Infrastructure | 150-200 | Low |
| Beta | Battle Analysis | 200-250 | Medium |
| Gamma | Intelligence | 150-200 | Medium |
| Delta | Wormhole/Corp | 100-150 | Low-Medium |
| Epsilon | LiveView/Web | 100-150 | Low |
| **Total** | **All Domains** | **700-950** | **Managed** |

### Success Metrics
- **Cautious Target**: 40-50% error reduction (700-950 from ~1,700)
- **Quality Gate**: Zero regression tolerance
- **Timeline**: 7-10 days with daily integration
- **Fallback**: Individual workstream success even if others fail

---

## Risk Mitigation Strategies

### Domain Isolation
- **Clear Boundaries**: Each workstream owns specific file trees
- **Interface Contracts**: Document all cross-domain function calls
- **Shared Module Handling**: Infrastructure workstream handles shared utilities only

### Progressive Integration
- **Day 1-2**: Workstreams work independently on safest changes
- **Day 3-4**: Begin daily integration testing
- **Day 5-7**: Full parallel execution with proven safety
- **Day 8-10**: Final integration and validation

### Failure Containment
- **Workstream Isolation**: Failed workstream doesn't affect others
- **Partial Success**: Accept success from 3-4 workstreams if 1-2 fail
- **Learning Integration**: Document failures for future improvement

---

## Communication Framework

### Hourly Check-ins
- Update shared progress tracker
- Log any cross-workstream dependencies discovered
- Flag potential conflicts early

### Daily Standups
- Review integration results
- Coordinate conflict resolution
- Adjust targets based on progress

### Issue Escalation
- **Minor Issues**: Workstream-level resolution
- **Cross-Dependencies**: Coordination via shared registry
- **Major Conflicts**: Full team discussion and resolution

---

## Success Probability Analysis
- **Individual Workstream Success**: 80-90% (proven approach)
- **Integration Success**: 70-80% (with enhanced coordination)
- **Overall Target Achievement**: 60-70% (realistic with safety measures)

**Philosophy**: "Parallel execution with cautious coordination - maximize speed while preventing disasters through communication and shared responsibility."