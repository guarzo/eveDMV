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
**Philosophy**: "If it returns mock data, it's not done."

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
| STORY-1 | | 5 | HIGH | Queries real data, no mocks |
| STORY-2 | | 3 | HIGH | Tests pass with real data |
| STORY-3 | | 8 | MEDIUM | UI displays actual results |
| STORY-4 | | 2 | LOW | Documentation updated |

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
- [ ] All tests pass
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
- [ ] Screenshots/recordings captured
- [ ] Test coverage maintained or improved
- [ ] Performance metrics collected

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

### Closing a Sprint
1. Complete all sections of sprint document
2. Run through completion checklist
3. Conduct retrospective
4. Move document to `/workspace/docs/sprints/completed/`
5. Update all project status documents
6. Archive any outdated documentation

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

2. **Scope Creep**
   - Explicitly list what's NOT in scope
   - Resist adding "just one more thing"

3. **Ignoring Technical Debt**
   - Track it, plan for it
   - Don't let it accumulate silently

4. **Overestimating Capacity**
   - Use actual velocity from previous sprints
   - Account for meetings, reviews, testing

5. **Documentation Drift**
   - Update docs with code changes
   - Remove outdated information immediately

---

**Remember**: Better to complete 3 features that actually work than claim 10 features are "done" with mock data.