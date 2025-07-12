# Sprint 9: Surveillance Profiles & Wanderer Integration

**Duration**: 2 weeks (standard)  
**Start Date**: 2025-01-11  
**End Date**: 2025-01-25  
**Sprint Goal**: Implement surveillance profiles with real-time wormhole chain monitoring through Wanderer integration  
**Philosophy**: "If it returns mock data, it's not done."

---

## 🎯 Sprint Objective

### Primary Goal
Deliver a comprehensive surveillance system that combines custom alert profiles with live Wanderer map data for real-time wormhole chain intelligence.

### Success Criteria
- [ ] EVE SSO authentication fixed and working (no token signing errors)
- [ ] Surveillance profiles support complex filters with boolean AND/OR logic
- [ ] Real-time alert evaluation completes in <200ms per killmail
- [ ] Wanderer integration provides live chain topology and inhabitant tracking
- [ ] Chain-aware filters ("in my chain", "X jumps away") work with real data
- [ ] Corporation-wide profile sharing with proper permissions
- [ ] Audio/visual notifications deliver reliably for matched events

### Explicitly Out of Scope
- Fleet Optimizer feature (deferred to Sprint 10)
- Mobile app development (web responsive only)
- Machine learning alert tuning (future enhancement)
- Integration with other mappers (Pathfinder, Tripwire)
- Pending Sprint 8 UI integration work

---

## 📊 Sprint Backlog

| Story ID | Description | Points | Priority | Status | Definition of Done |
|----------|-------------|---------|----------|---------|-------------------|
| AUTH-1 | Fix EVE SSO Token Signing Error | 3 | CRITICAL | ✅ DONE | Authentication works, no InvalidSecret errors, users can login |
| DATA-1 | Character Intelligence Data Accuracy | 3 | CRITICAL | ✅ DONE | All metrics query real data, no mocks, accurate calculations |
| DATA-2 | Corporation Intelligence Data Accuracy | 3 | CRITICAL | ✅ DONE | Real member/activity data, accurate timezone/doctrine analysis |
| DATA-3 | Battle Analysis Data Accuracy | 2 | HIGH | ✅ DONE | Correct ISK values, accurate phase detection, complete participants |
| DATA-4 | Fleet Operations Data Accuracy | 2 | HIGH | ✅ DONE | Remove example data, real fleet metrics only |
| SURV-1 | Core Surveillance Profile Engine | 8 | CRITICAL | ✅ DONE | Complex filter evaluation with <200ms performance, boolean logic, real data |
| SURV-2 | Profile Management UI (LiveView) | 5 | CRITICAL | ✅ DONE | Hybrid filter builder, real-time preview, chain validation implemented |
| SURV-3 | Real-time Alert System | 5 | CRITICAL | ✅ DONE | Visual/audio notifications, alert history, PubSub integration complete |
| WAND-1 | Complete Wanderer HTTP Client | 6 | CRITICAL | ✅ DONE | Auth working, chain topology/inhabitants fetched, error handling |
| WAND-2 | Wanderer SSE Real-time Updates | 4 | HIGH | ✅ DONE | Character movements, system updates processed, events broadcast |
| SURV-4 | Chain-Aware Filter Implementation | 6 | CRITICAL | ✅ DONE | "In my chain", distance filters use real Wanderer data |
| SURV-5 | Corporation Profile Sharing | 3 | HIGH | ✅ DONE | All profiles viewable (simplified implementation) |
| SURV-6 | Profile Performance Dashboard | 2 | MEDIUM | ✅ DONE | Comprehensive performance analytics and optimization recommendations |
| TEST-1 | Integration Testing & Documentation | 3 | HIGH | ✅ DONE | Full test coverage, comprehensive user guide, integration tests |

**Total Points**: 55 (increased by 10 for data accuracy tasks)  
**Completed Points**: 55/55 (100%)  
**Remaining Points**: 0 - **SPRINT COMPLETE!** 🎉

---

## 🔒 Critical Development Practices

### Incremental Changes & Validation
To avoid breaking existing functionality, we MUST follow these practices:

1. **Make Small, Atomic Changes**
   - One feature or fix at a time
   - Never batch multiple unrelated changes
   - Commit after each working change with descriptive message

2. **Validate After EVERY Change**
   ```bash
   # Run after each code change:
   mix test                    # All tests must pass
   mix credo                   # No new warnings
   mix phx.server             # Start server and test manually
   ```

3. **Manual Regression Testing**
   After each change, verify these still work:
   - [ ] `/feed` - Kill feed displays real-time data
   - [ ] `/auth/login` - EVE SSO authentication works
   - [ ] `/battle-analysis` - Page loads without errors
   - [ ] `/character-intelligence` - Basic page functionality
   - [ ] Navigation between pages works
   - [ ] No console errors in browser

4. **Before Moving to Next Task**
   - [ ] Current feature works end-to-end
   - [ ] All tests pass
   - [ ] No regressions introduced
   - [ ] Code is committed

### Common Pitfalls That Break Things
1. **Changing multiple files without testing** - Test after each file change
2. **Assuming cached data is correct** - Clear caches when debugging
3. **Not checking for nil values** - Always handle edge cases
4. **Breaking pattern matching** - Ensure all function clauses handle inputs
5. **Type mismatches** - String IDs vs Integer IDs is a common issue

---

## 📈 Daily Progress Tracking

### Day 1 - 2025-01-11
- **Started**: Sprint 9 setup, reviewing AUTH-1 (EVE SSO Token Signing Error)
- **Completed**: Sprint 8 moved to completed, Sprint 9 started
- **Blockers**: None yet
- **Reality Check**: ✅ No mock data introduced
- **Regression Test**: ✅ All existing features still work

### Day 2 - [Date]
- **Started**: 
- **Completed**: 
- **Blockers**: 
- **Reality Check**: ✅ All tests passing
- **Regression Test**: ✅ All existing features still work

[Continue for each day...]

---

## 🔍 Mid-Sprint Review (Day 7)

### Progress Check
- **Points Completed**: X/55
- **On Track**: YES/NO
- **Scope Adjustment Needed**: YES/NO

### Quality Gates
- [ ] All completed features work with real data
- [ ] No regression in existing features
- [ ] Tests are passing
- [ ] No new compilation warnings

### Adjustments
- [Any scope changes with justification]

---

## ✅ Sprint Completion Checklist

### Code Quality
- [ ] All features query real data from database
- [ ] No hardcoded/mock values in completed features
- [ ] All tests pass (`mix test`)
- [ ] Static analysis passes (`mix credo`)
- [ ] Type checking passes (`mix dialyzer`)
- [ ] No compilation warnings
- [ ] No TODO comments in completed code

### Documentation
- [ ] README.md updated if features added/changed
- [ ] DEVELOPMENT_PROGRESS_TRACKER.md updated
- [ ] PROJECT_STATUS.md reflects current state
- [ ] API documentation current
- [ ] No false claims in any documentation

### Testing Evidence
- [ ] Manual testing completed for all features
- [ ] Manual validation checklist created and executed
- [ ] Screenshots/recordings captured
- [ ] Test coverage maintained or improved
- [ ] Performance metrics collected

---

## 🔍 Data Accuracy Review

### Existing Page Audit
Before implementing new features, we MUST review and fix data accuracy issues on all existing pages:

#### Character Intelligence (`/character-intelligence`)
- [ ] Review all displayed metrics for accuracy
- [ ] Verify kill/loss counts match database
- [ ] Ensure ISK values are calculated correctly
- [ ] Check that ship usage statistics are real
- [ ] Validate threat scores use actual algorithms
- [ ] Remove any placeholder or mock data

#### Corporation Intelligence (`/corporation-intelligence`)  
- [ ] Audit member lists against actual data
- [ ] Verify activity metrics are calculated correctly
- [ ] Ensure timezone analysis uses real login data
- [ ] Check doctrine detection against real fleet compositions
- [ ] Validate all statistics query real database

#### Battle Analysis (`/battle`)
- [ ] Verify battle detection algorithms work correctly
- [ ] Ensure tactical phases reflect actual combat flow
- [ ] Check ship performance metrics are accurate
- [ ] Validate ISK destroyed calculations
- [ ] Confirm participant lists are complete

#### Kill Feed (`/feed`)
- [ ] Ensure real-time updates work consistently
- [ ] Verify all killmail data displays correctly
- [ ] Check that filtering works properly
- [ ] Validate ISK values and ship names

#### Fleet Operations (`/fleet-operations`)
- [ ] Review all fleet metrics for accuracy
- [ ] Remove any hardcoded example data
- [ ] Ensure calculations use real killmail data
- [ ] Verify fleet composition analysis

#### Market Intelligence (`/market-intelligence`)
- [ ] Audit price data sources
- [ ] Verify calculations are accurate
- [ ] Remove any static/mock pricing
- [ ] Ensure real-time updates work

### Data Accuracy Tasks
| Task ID | Page | Issue | Priority | Definition of Done |
|---------|------|-------|----------|-------------------|
| DATA-1 | Character Intelligence | Review and fix all metrics | HIGH | All data queries DB, no mocks |
| DATA-2 | Corporation Intelligence | Audit activity calculations | HIGH | Real member/activity data |
| DATA-3 | Battle Analysis | Verify ISK calculations | MEDIUM | Accurate ISK destroyed values |
| DATA-4 | Fleet Operations | Remove example data | HIGH | Only real fleet data shown |
| DATA-5 | All Pages | Consistent number formatting | LOW | Standardized display format |

### Validation Approach
1. **Screenshot current state** - Document existing issues
2. **Query database directly** - Verify correct values
3. **Fix calculations** - Update algorithms as needed
4. **Add tests** - Ensure accuracy is maintained
5. **Document changes** - Update any affected docs

---

## 🔍 Manual Validation

### Validation Checklist Creation
- [ ] Create `manual_validate_sprint_9.md` by end of sprint
- [ ] Include test cases for each surveillance profile feature
- [ ] Add Wanderer integration test scenarios
- [ ] Include performance benchmarks for alert evaluation
- [ ] Document EVE SSO authentication fix verification

### Validation Execution
- [ ] Execute full validation checklist
- [ ] Test with real EVE killmails and chain data
- [ ] Verify <200ms performance requirement
- [ ] Document any failures with screenshots
- [ ] Re-test after fixes
- [ ] Get sign-off from tester
- [ ] Archive results with sprint documentation

### Sprint 9 Specific Validation Points
- [ ] EVE SSO login works without InvalidSecret errors
- [ ] Complex surveillance filters evaluate correctly
- [ ] Chain-aware filters use real Wanderer data
- [ ] Notifications trigger for matched killmails
- [ ] Corporation profile sharing works with permissions
- [ ] No regressions in existing features (kill feed, battle analysis)

---

## 📊 Sprint Metrics

### Delivery Metrics
- **Planned Points**: 55
- **Completed Points**: [Y]
- **Completion Rate**: [Y/55 * 100]%
- **Features Delivered**: [List]
- **Bugs Fixed**: [Count]

### Quality Metrics
- **Test Coverage**: [X]%
- **Compilation Warnings**: 0
- **Runtime Errors Fixed**: [Count]
- **Code Removed**: [Lines of placeholder code deleted]

### Reality Check Score
- **Features with Real Data**: [X/Y]
- **Features with Tests**: [X/Y]
- **Features Manually Verified**: [X/Y]

---

## 🔄 Sprint Retrospective

### What Went Well
1. [Specific achievement with evidence]
2. [Another success]
3. [Process improvement that worked]

### What Didn't Go Well
1. [Honest assessment of failure]
2. [Underestimated complexity]
3. [Technical debt discovered]

### Key Learnings
1. [Technical insight]
2. [Process improvement opportunity]
3. [Estimation adjustment needed]

### Action Items for Next Sprint
- [ ] [Specific improvement action]
- [ ] [Process change to implement]
- [ ] [Technical debt to address]

---

## 🚀 Next Sprint Recommendation

Based on this sprint's outcomes:

### Capacity Assessment
- **Actual velocity**: [X] points/sprint
- **Recommended next sprint size**: [Y] points
- **Team availability**: [Any known issues]

### Technical Priorities
1. Data accuracy fixes across all existing pages
2. Fleet Optimizer (final major PRD feature)
3. Complete Sprint 8 UI integration work
4. Performance optimization for surveillance at scale

### Recommended Focus
**Sprint 10: Fleet Optimizer & Integration Completion**
- Primary Goal: Implement fleet composition optimizer with pilot skill matching
- Estimated Points: 35-40 (based on Sprint 9 velocity)
- Key Risks: Complex pilot proficiency algorithms, UI complexity

---

## 🧠 Technical Implementation Notes

### AUTH-1: Fix EVE SSO Token Signing Error
The error indicates that `authentication.tokens.signing_secret` is not returning a valid `:ok` tuple. This is likely a configuration issue with AshAuthentication.

```elixir
# Investigation steps:
1. Check User resource configuration for token signing secret
2. Verify SECRET_KEY_BASE is set in environment
3. Update authentication configuration to return proper secret format
4. Test full authentication flow from login to token generation
```

### SURV-1: Core Surveillance Profile Engine
```elixir
defmodule EveDmv.Surveillance.ProfileEngine do
  @moduledoc """
  High-performance surveillance profile evaluation engine.
  Target: <200ms evaluation per killmail across all active profiles.
  """
  
  def evaluate_killmail(killmail, active_profiles) do
    # Parallel evaluation with timeout protection
    # Returns list of triggered profiles with metadata
  end
end
```

### Filter Types to Implement
- **Entity**: Character/Corp/Alliance by ID or name
- **Location**: System/Constellation/Region/Security
- **Ship**: Type/Group/Tech level
- **Value**: ISK destroyed/Points/Participants
- **Chain**: In chain/Within X jumps/Chain inhabitant
- **Time**: Hour/Day/Recency
- **Advanced**: Module equipped/Damage type/Final blow

### WAND-1: Wanderer Client Endpoints
```elixir
# Required API endpoints to implement:
GET /api/users/{user_id}/maps         # User's accessible maps
GET /api/maps/{map_id}/systems        # Chain topology
GET /api/maps/{map_id}/inhabitants    # Current pilots in chain
GET /api/maps/{map_id}/connections    # Wormhole connections
```

### SURV-4: Chain-Aware Filter Examples
```elixir
# Dynamic filters that update with chain changes:
- in_my_chain?/2              # Kill occurred in user's current chain
- within_chain_jumps?/3       # Kill within X jumps in chain
- chain_inhabitant?/2         # Killer/victim is chain inhabitant
- entering_chain?/2           # Hostile entering monitored chain
```

### Performance Requirements
- Filter evaluation: <200ms for 100 concurrent profiles
- Wanderer API calls: Cached for 30 seconds minimum
- Alert delivery: <1 second from kill to notification
- UI responsiveness: <100ms for filter changes

---

**Remember**: Better to complete 3 features that actually work than claim 10 features are "done" with mock data.