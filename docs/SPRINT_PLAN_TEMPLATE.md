## 🤖 AI Sprint Management Prompt

Use this prompt when closing the previous sprint and kicking off the next one:

```
I need to manage the sprint transition for [PROJECT_NAME]. Please help me:

1. CLOSE PREVIOUS SPRINT:
   - Review docs/sprints/current/[SPRINT_NAME].md
   - Update that sprint document with final status, metrics, and retrospective
   - Move it to docs/sprints/completed/
   - Update DEVELOPMENT_PROGRESS_TRACKER.md with sprint results
   - Update PROJECT_STATUS.md if major features were completed

2. START NEW SPRINT:
   - Create docs/sprints/current/SPRINT_[NUMBER]_[NAME].md from the template
   - Update DEVELOPMENT_PROGRESS_TRACKER.md with new sprint info
   - Initialize the sprint’s to‑do list

3. VERIFY DOCUMENTATION:
   - Ensure no placeholder work is marked “complete”
   - Update README.md feature statuses as needed
   - Archive any outdated materials

Current sprint number: [X]
Previous sprint: [Name and status]
New sprint focus: [Primary theme or objective]
```

---

## 📋 Sprint Document Structure

### Sprint [Number]: [Sprint Name]

- **Duration**: [e.g. 2 weeks]
- **Start Date**: [YYYY‑MM‑DD]
- **End Date**: [YYYY‑MM‑DD]
- **Sprint Goal**: [One clear, measurable objective]

---

### 🚨 CLEAN CODE COMMITMENT

- ✅ NO placeholder/stub implementations
- ✅ NO “magic” numbers
- ✅ NO random or mock data in production code
- ✅ ALL features operate on real data or are omitted

> _Philosophy_: “If it isn’t real, it isn’t done.”

---

## 🎯 Sprint Objective

**Primary Goal**

> [One sentence describing the main achievement]

**Success Criteria**

- [ ] [Specific, measurable outcome 1]
- [ ] [Specific, measurable outcome 2]
- [ ] [Specific, measurable outcome 3]

**Out of Scope**

- [Feature/work NOT in this sprint]
- [Another deferred item]

---

## 📊 Sprint Backlog

| Story ID  | Description                                | Points | Priority | Definition of Done                         |
| --------- | ------------------------------------------ | :----: | -------- | ------------------------------------------ |
| CLEANUP-1 | Remove placeholder code in `[MODULE/AREA]` |   3    | Critical | Code removed or implemented with real data |
| STORY-1   | [Brief description]                        |   5    | High     | Meets acceptance criteria                  |
| STORY-2   | [Brief description]                        |   3    | High     | Tests pass and feature works               |
| STORY-3   | [Brief description]                        |   8    | Medium   | UI/UX validated with real data             |
| STORY-4   | [Brief description]                        |   2    | Low      | Documentation updated                      |

**Placeholder Cleanup Tasks**
_(Required until codebase is clean)_

- [ ] Identify placeholder functions to remove/fix
- [ ] Replace hardcoded values with configuration or real data sources
- [ ] Remove any demo/random data generation
- [ ] Delete unimplementable stubs

**Total Points**: [Sum]

---

## 📈 Daily Progress Tracking

### Day 1 – [YYYY‑MM‑DD]

- **Started**: [Task]
- **Completed**: [Task + evidence]
- **Blockers**: [Issues]
- **Reality Check**: ✅ No mock data introduced

### Day 2 – [YYYY‑MM‑DD]

- **Started**: [Task]
- **Completed**: [Task + evidence]
- **Blockers**: [Issues]
- **Reality Check**: ✅ All automated tests passing

_(…repeat for each day…)_

---

## 🔍 Mid‑Sprint Review (Halfway Point)

**Progress Check**

- Points done: X/Y
- On track? [Yes/No]
- Scope adjustment needed? [Yes/No]

**Quality Gates**

- [ ] All features work on real data
- [ ] No regressions in existing functionality
- [ ] Automated tests green
- [ ] Static analysis clean

**Adjustments**

> [Scope changes + rationale]

---

## ✅ Sprint Completion Checklist

### Code Quality

- [ ] No placeholder or stub code
- [ ] No magic numbers or hardcoded values
- [ ] No random/demo data in production
- [ ] Automated tests pass
- [ ] Static analysis (lint/type checks) clean
- [ ] No compiler/runtime warnings
- [ ] README and docs updated

### Documentation

- [ ] DEVELOPMENT_PROGRESS_TRACKER.md updated
- [ ] PROJECT_STATUS.md updated
- [ ] API/docs current

### Testing Evidence

- [ ] Manual testing performed
- [ ] Validation checklist created/executed
- [ ] Test coverage maintained/improved
- [ ] Performance benchmarks collected

---

## 🔍 Manual Validation

### Checklist Creation

- [ ] Create `manual_validate_sprint_[X].md`
- [ ] List test cases for each feature
- [ ] Include edge/error cases
- [ ] Document performance checks

### Execution

- [ ] Run full validation
- [ ] Log any failures + screenshots
- [ ] Re-test after fixes
- [ ] Sign‑off from QA
- [ ] Archive results

---

## 📊 Sprint Metrics

**Delivery Metrics**

- Planned Points: [X]
- Completed Points: [Y]
- Velocity: [Y/X * 100]%
- Features Delivered: [List]
- Bugs Fixed: [Count]

**Quality Metrics**

- Test Coverage: [X]%
- Warnings: 0
- Tech Debt Removed: [Lines of stub code deleted]
- Manual Verification Rate: [X/Y]

---

## 🔄 Sprint Retrospective

### What Went Well

1. [Success with evidence]
2. [Another win]
3. [Process improvement]

### What Didn’t Go Well

1. [Pain point]
2. [Underestimated work]
3. [Technical debt discovered]

### Key Learnings

1. [Insight]
2. [Process tweak]
3. [Estimation note]

### Action Items for Next Sprint

- [ ] [Specific improvement]
- [ ] [Process change]
- [ ] [Debt to address]

---

## 🚀 Next Sprint Recommendation

**Capacity Assessment**

- Actual velocity: [X]
- Suggested next sprint size: [Y]

**Technical Priorities**

1. [Top priority]
2. [Second priority]
3. [Third priority]

**Proposed Sprint [X+1]: [Name]**

- Goal: [Primary objective]
- Estimated Points: [Conservative estimate]
- Key Risks: [Identified from this sprint]

---

## 📁 Sprint Management Procedures

### Starting a Sprint

1. Copy this template to `docs/sprints/current/SPRINT_[X]_[NAME].md`
2. Update `DEVELOPMENT_PROGRESS_TRACKER.md`
3. Generate initial to‑do list
4. Review previous retrospective
5. Hold planning meeting

### During the Sprint

1. Update daily progress in the sprint doc
2. Conduct mid‑sprint review
3. Mark to‑dos as completed
4. Capture test evidence
5. Flag scope changes promptly
6. Build manual validation checklist

### Closing a Sprint

1. Complete all sprint‑doc sections
2. Run completion checklist
3. Execute manual validation
4. Conduct retrospective
5. Archive sprint doc to `docs/sprints/completed/`
6. Update status docs
7. Store validation results

---

## 🚨 Common Pitfalls to Avoid

1. **Completion Without Evidence**
   - Always require test or demo proof
2. **Scope Creep**
   - Define out‑of‑scope clearly
   - Don’t add “just one more thing”
3. **Tech Debt Ignored**
   - Track and plan for it
4. **Overestimated Capacity**
   - Base estimates on real velocity
5. **Documentation Drift**
   - Sync docs with code changes immediately

---

## 🔴 PLACEHOLDER DETECTION

Run before closing sprint:

```bash
# Find stub returns
grep -R "return \[\]" src/
grep -R "return nil" src/

# Find random/demo data
grep -R "random" src/

# Find placeholder comments
grep -R "TODO" src/
grep -R "FIXME" src/
```

If any stub or demo code remains, the sprint is not complete.

---

_Better to finish 3 real features than claim 10 “done” with mock data._
