# Sprint Planning Template & Management Guide

**Use this template for every sprint to maintain reality-based development**

---

## 🤖 AI Sprint Management Prompt

When starting a new sprint or closing a previous one, use this prompt:

```
I need to manage the sprint transition for EVE DMV. Please help me:

1. CLOSE PREVIOUS SPRINT:
   - Review /workspace/docs/sprints/current/[SPRINT_NAME].md
   - Update the sprint document with final status, metrics, and retrospective
   - Move it to /workspace/docs/sprints/completed/
   - Update /workspace/DEVELOPMENT_PROGRESS_TRACKER.md with sprint results
   - Update /workspace/PROJECT_STATUS.md if major features were completed

2. START NEW SPRINT:
   - Create new sprint document in /workspace/docs/sprints/current/SPRINT_[NUMBER]_[NAME].md
   - Use the template below to structure the sprint
   - Update /workspace/DEVELOPMENT_PROGRESS_TRACKER.md with new sprint info
   - Create initial todo list for tracking

3. VERIFY DOCUMENTATION:
   - Ensure no placeholder features are marked as "complete"
   - Update feature status in README.md if needed
   - Archive any outdated documents

Current sprint number: [X]
Previous sprint: [Name and status]
New sprint focus: [Battle Analysis / Corporation Intelligence / Performance / etc.]
```

---

## 📋 Sprint Document Structure

### Sprint [Number]: [Sprint Name]

**Duration**: 2 weeks (standard)  
**Start Date**: [YYYY-MM-DD]  
**End Date**: [YYYY-MM-DD]  
**Sprint Goal**: [One clear, measurable objective]  

### 🚨 CLEAN CODEBASE COMMITMENT
**This sprint adheres to the Clean Codebase Vision:**
- ✅ NO placeholder implementations
- ✅ NO functions returning empty data as stubs
- ✅ NO hardcoded "magic" numbers
- ✅ NO random data generation for "analysis"
- ✅ ALL features query real data or don't exist

**Philosophy**: "If it returns mock data, it's not done. If it's not done, delete it."

---

## 🎯 Sprint Objective

### Primary Goal
[One sentence describing the main achievement]

### Success Criteria
- [ ] [Specific, measurable outcome 1]
- [ ] [Specific, measurable outcome 2]
- [ ] [Specific, measurable outcome 3]

### Explicitly Out of Scope
- [Feature/work we're NOT doing this sprint]
- [Another deferred item]

---

## 📊 Sprint Backlog

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| CLEANUP-1 | Remove placeholder functions in [module] | 3 | CRITICAL | Functions deleted or implemented with real data |
| STORY-1 | | 5 | HIGH | Queries real data, no mocks |
| STORY-2 | | 3 | HIGH | Tests pass with real data |
| STORY-3 | | 8 | MEDIUM | UI displays actual results |
| STORY-4 | | 2 | LOW | Documentation updated |

### 🧹 Placeholder Cleanup Tasks (REQUIRED)
Every sprint MUST include cleanup tasks until codebase is clean:
- [ ] Identify X placeholder functions to remove/fix
- [ ] Replace hardcoded values with static data queries
- [ ] Remove any random data generation
- [ ] Delete functions that can't be properly implemented

**Total Points**: [Sum]

---

## 📈 Daily Progress Tracking

### Day 1 - [Date]
- **Started**: [Task]
- **Completed**: [Task with evidence]
- **Blockers**: [Any issues]
- **Reality Check**: ✅ No mock data introduced

### Day 2 - [Date]
- **Started**: [Task]
- **Completed**: [Task with evidence]
- **Blockers**: [Any issues]
- **Reality Check**: ✅ All tests passing

[Continue for each day...]

---

## 🔍 Mid-Sprint Review (Day 7)

### Progress Check
- **Points Completed**: X/Y
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
- [ ] No functions returning empty arrays/maps as placeholders
- [ ] No random data generation in production code
- [ ] All ship/system lookups use static data tables
- [ ] All tests pass (`mix test`)
- [ ] Static analysis passes (`mix credo`)
- [ ] Type checking passes (`mix dialyzer`)
- [ ] No compilation warnings
- [ ] No TODO comments in completed code
- [ ] No references to non-existent modules

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

## 🔍 Manual Validation

### Validation Checklist Creation
- [ ] Create `manual_validate_sprint_[X].md` by end of sprint
- [ ] Include test cases for each implemented feature
- [ ] Add edge cases and error scenarios
- [ ] Include performance benchmarks
- [ ] Document known issues to verify fixed

### Validation Execution
- [ ] Execute full validation checklist
- [ ] Document any failures with screenshots
- [ ] Re-test after fixes
- [ ] Get sign-off from tester
- [ ] Archive results with sprint documentation

---

## 📊 Sprint Metrics

### Delivery Metrics
- **Planned Points**: [X]
- **Completed Points**: [Y]
- **Completion Rate**: [Y/X * 100]%
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
1. [Most important based on learnings]
2. [Second priority]
3. [Third priority]

### Recommended Focus
**Sprint [X+1]: [Proposed Name]**
- Primary Goal: [Based on actual capacity]
- Estimated Points: [Conservative estimate]
- Key Risks: [Identified from this sprint]

---

## 📁 Sprint Management Procedures

### Starting a Sprint
1. Copy this template to `/workspace/docs/sprints/current/SPRINT_[X]_[NAME].md`
2. Update `/workspace/DEVELOPMENT_PROGRESS_TRACKER.md` with new sprint info
3. Create todo list using TodoWrite tool
4. Review previous sprint's retrospective
5. Hold sprint planning meeting

### During the Sprint
1. Update sprint document daily with progress
2. Conduct mid-sprint review on Day 7
3. Update todo items as completed
4. Capture evidence (screenshots, test results)
5. Flag any scope changes immediately
6. Create manual validation checklist for implemented features

### 🔒 Critical Development Practices

#### Incremental Changes & Validation
1. **Make Small, Atomic Changes**
   - One feature or fix at a time
   - Commit after each working change
   - Never batch multiple unrelated changes

2. **Validate After Every Change**
   - Run `mix test` after each code change
   - Manually test the specific feature modified
   - Check that existing features still work
   - Run `mix phx.server` and test in browser

3. **Regression Testing Checklist**
   - [ ] Kill feed still displays real-time data
   - [ ] Authentication still works
   - [ ] Navigation between pages works
   - [ ] No new compilation warnings
   - [ ] No runtime errors in console

4. **Before Moving to Next Task**
   - Current feature works end-to-end
   - Tests pass
   - No regressions introduced
   - Code is committed with clear message

### Closing a Sprint
1. Complete all sections of sprint document
2. Run through completion checklist
3. Execute manual validation checklist for all features
4. Conduct retrospective
5. Move document to `/workspace/docs/sprints/completed/`
6. Update all project status documents
7. Archive any outdated documentation
8. Save manual validation results in sprint folder

### Documentation Updates Required
- `/workspace/DEVELOPMENT_PROGRESS_TRACKER.md` - Add sprint summary
- `/workspace/PROJECT_STATUS.md` - Update feature status
- `/workspace/README.md` - Update if major features added
- `/workspace/docs/README.md` - Update if docs structure changed

---

## 🚨 Common Pitfalls to Avoid

1. **Claiming Completion Without Evidence**
   - Always require screenshots or demo
   - Test in actual browser, not just unit tests
   - Verify data comes from database, not hardcoded

2. **Scope Creep**
   - Explicitly list what's NOT in scope
   - Resist adding "just one more thing"
   - Delete incomplete features rather than stub them

3. **Ignoring Technical Debt**
   - Track it, plan for it
   - Don't let it accumulate silently
   - Remove placeholder code immediately

4. **Overestimating Capacity**
   - Use actual velocity from previous sprints
   - Account for meetings, reviews, testing
   - Factor in time to remove placeholders

5. **Documentation Drift**
   - Update docs with code changes
   - Remove outdated information immediately
   - Never document features that don't work

## 🔴 PLACEHOLDER DETECTION CHECKLIST

Run these checks before closing ANY sprint:

```bash
# Check for empty return placeholders
grep -r "def.*do\s*\[\]\s*end" lib/
grep -r "def.*do\s*%{}\s*end" lib/
grep -r "def.*do\s*nil\s*end" lib/

# Check for random data generation
grep -r "Enum.random" lib/
grep -r ":rand.uniform" lib/

# Check for hardcoded values
grep -r "# TODO" lib/
grep -r "# FIXME" lib/
grep -r "# stub" lib/
grep -r "# placeholder" lib/

# Check for modulo-based logic
grep -r "% 10.*ship" lib/
grep -r "% 3.*role" lib/
```

If ANY of these return results in production code, the sprint is NOT complete.

---

**Remember**: Better to complete 3 features that actually work than claim 10 features are "done" with mock data.