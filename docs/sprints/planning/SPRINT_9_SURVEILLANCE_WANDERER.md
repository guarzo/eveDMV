# Sprint 9: Surveillance Profiles & Wanderer Integration

**Duration**: 2 weeks (standard)  
**Start Date**: 2025-07-24  
**End Date**: 2025-08-07  
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

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| AUTH-1 | Fix EVE SSO Token Signing Error | 3 | CRITICAL | Authentication works, no InvalidSecret errors, users can login |
| SURV-1 | Core Surveillance Profile Engine | 8 | CRITICAL | Complex filter evaluation with <200ms performance, boolean logic, real data |
| SURV-2 | Profile Management UI (LiveView) | 5 | CRITICAL | Create/edit/delete profiles, drag-drop filter builder, preview with real kills |
| SURV-3 | Real-time Alert System | 5 | CRITICAL | Visual/audio notifications, alert history, PubSub integration |
| WAND-1 | Complete Wanderer HTTP Client | 6 | CRITICAL | Auth working, chain topology/inhabitants fetched, error handling |
| WAND-2 | Wanderer SSE Real-time Updates | 4 | HIGH | Character movements, system updates processed, events broadcast |
| SURV-4 | Chain-Aware Filter Implementation | 6 | CRITICAL | "In my chain", distance filters use real Wanderer data |
| SURV-5 | Corporation Profile Sharing | 3 | HIGH | Corp profiles with permissions, member subscription |
| SURV-6 | Profile Performance Dashboard | 2 | MEDIUM | Alert statistics, filter metrics, efficiency monitoring |
| TEST-1 | Integration Testing & Documentation | 3 | HIGH | Full test coverage, user guide, API docs |

**Total Points**: 45

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

### Day 1 - [Date]
- **Started**: 
- **Completed**: 
- **Blockers**: 
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
- **Points Completed**: X/42
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

## 📊 Sprint Metrics

### Delivery Metrics
- **Planned Points**: 45
- **Completed Points**: [Y]
- **Completion Rate**: [Y/45 * 100]%
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
1. Fleet Optimizer (final major PRD feature)
2. Complete Sprint 8 UI integration work
3. Performance optimization for surveillance at scale

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