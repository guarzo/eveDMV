# 🤖 AI Assistant Sprint Prompt Templates

## Sprint Completion Prompt Template

### Prompt: Complete Sprint 2

```
You are working on EVE DMV, a wormhole-focused PvP intelligence platform for EVE Online. Your task is to complete the remaining work in Sprint 2.

## Context
- **Project**: EVE DMV - Wormhole intelligence platform integrated with Wanderer map
- **Current Sprint**: Sprint 2 (Week 2 of development)
- **Sprint Status**: 52/50 story points completed, 13 points remaining

## Remaining Sprint 2 Work
According to /workspace/docs/sprints/sprint-2.md, the following features are in progress:
1. Alliance Analytics Dashboard (6 pts)
2. Value Enrichment with Real-time Pricing (4 pts)
3. Batch Profile Management Tools (3 pts)

## Key Project Files
- **Sprint Documentation**: /workspace/docs/sprints/sprint-2.md
- **Project Status**: /workspace/docs/project-management/project-status.md
- **Architecture**: /workspace/docs/architecture/DESIGN.md
- **Development Guidelines**: /workspace/CLAUDE.md

## Your Tasks
1. Review the sprint documentation to understand remaining features
2. Implement each remaining feature following the existing code patterns
3. Ensure all implementations follow the Ash Framework patterns (resources, not Ecto schemas)
4. Write appropriate tests for new functionality
5. Update the sprint documentation marking features as completed
6. Run quality checks: `mix quality.check`
7. Update PROJECT_STATUS.md with completion status

## Important Technical Notes
- This is an Elixir Phoenix 1.7.21 application
- We use Ash Framework 3.4 for resources (NOT traditional Ecto)
- Broadway handles the real-time killmail pipeline
- Follow existing patterns in lib/eve_dmv/ for new resources
- Use Wanderer-kills SSE feed for killmail data

## Definition of Done
- [ ] All 3 features implemented and working
- [ ] Tests written and passing
- [ ] Quality checks pass (format, credo, dialyzer)
- [ ] Sprint documentation updated
- [ ] Project status updated
- [ ] Ready for demo

Please complete these features one by one, testing each thoroughly before moving to the next.
```

---

## Sprint Planning Prompt Template

### Prompt: Plan and Begin Sprint 3

```
You are working on EVE DMV, a wormhole-focused PvP intelligence platform. Sprint 2 has been completed, and you need to plan and begin Sprint 3.

## Context
- **Project**: EVE DMV - Wormhole intelligence platform
- **Focus**: Wormhole corporations using Wanderer map
- **Completed**: Sprint 1 & 2 (core platform features)
- **Next Theme**: Wormhole Combat Intelligence (Sprint 3)

## Key Strategic Documents
- **Roadmap**: /workspace/docs/project-management/prioritized-roadmap.md
- **Goals & Personas**: /workspace/docs/project-management/goals-personas-usecases.md
- **WH Features Spec**: /workspace/docs/implementation/wormhole-features-specification.md
- **Previous Sprint**: /workspace/docs/sprints/sprint-2.md

## Sprint 3 Planning Tasks

### 1. Create Sprint Documentation
Create `/workspace/docs/sprints/sprint-3.md` with:
- Sprint goals and theme
- User stories with acceptance criteria
- Story point estimates
- Technical tasks breakdown
- Success metrics

### 2. According to the Roadmap, Sprint 3 Should Include:
- **Chain-Wide Surveillance** (8 pts)
  - Monitor all connected systems
  - Real-time hostile alerts
  - Chain activity timeline
  - Integration with Wanderer notifications

- **Small Gang Battle Analysis** (6 pts)
  - WH-specific engagement metrics
  - Pilot performance in small gangs
  - Doctrine effectiveness for J-space
  - Common WH fleet counters

- **Active Chain Detection** (5 pts)
  - Identify PvP vs farming groups
  - Recent engagement heat maps
  - Chain activity predictions
  - Content finder for hunters

### 3. Update Project Management Docs
- Create sprint-3-bug-fixes.md (empty template)
- Update project-status.md with Sprint 3 start
- Archive Sprint 2 documentation appropriately

### 4. Begin Implementation
Start with the highest priority feature:
1. Design the database schema/resources needed
2. Create Ash resources following existing patterns
3. Implement the basic functionality
4. Create LiveView UI components
5. Write tests

## Wanderer Integration Note
Sprint 3 heavily relies on Wanderer map integration. Key integration points:
- Chain topology data
- System inhabitants
- Fleet composition
- Real-time updates via WebSocket

## Important Reminders
- Follow wormhole-first approach (small gang, J-space focused)
- All features should integrate with Wanderer map
- Use existing patterns from Sprint 1 & 2
- Maintain backward compatibility
- Document all API changes

## Definition of Sprint Planning Complete
- [ ] Sprint 3 documentation created
- [ ] All user stories defined with points
- [ ] Technical design documented
- [ ] Project status updated
- [ ] First feature implementation started
- [ ] Sprint 2 properly archived

Please proceed with planning Sprint 3, focusing on our wormhole-first strategy and Wanderer map integration.
```

---

## Additional Helper Prompts

### Daily Standup Update Prompt
```
Please provide a daily standup update for EVE DMV Sprint [X]:
1. Check current sprint documentation in /workspace/docs/sprints/
2. Review completed work from yesterday
3. Identify work planned for today
4. Note any blockers
5. Update sprint documentation with progress
6. Update story point completion if applicable
```

### Sprint Retrospective Prompt
```
Complete a sprint retrospective for EVE DMV Sprint [X]:
1. Review /workspace/docs/sprints/sprint-[X].md
2. Analyze what went well
3. Identify what could be improved
4. Document lessons learned
5. Create action items for next sprint
6. Update sprint documentation with retrospective notes
7. Archive sprint as completed
```

### Bug Fix Documentation Prompt
```
Document and fix bugs for EVE DMV:
1. Review /workspace/docs/sprints/sprint-[X]-bug-fixes.md
2. For each bug:
   - Reproduce the issue
   - Document root cause
   - Implement fix
   - Write regression test
   - Update bug fix summary
3. Run full test suite
4. Update sprint bug fix documentation
```

---

## Usage Tips

1. **Context is Key**: Always provide the AI with access to project documentation
2. **Incremental Progress**: Ask for one feature at a time to maintain quality
3. **Documentation First**: Ensure docs are updated before moving to next task
4. **Test Everything**: Emphasize TDD and quality checks
5. **Maintain History**: Never delete old sprint docs, only archive

## File Structure Reminder
```
/workspace/docs/
├── sprints/
│   ├── sprint-2.md (current)
│   ├── sprint-2-bug-fixes.md
│   └── sprint-3.md (to be created)
├── project-management/
│   ├── project-status.md (keep updated)
│   ├── prioritized-roadmap.md (reference)
│   └── goals-personas-usecases.md (reference)
└── implementation/
    └── wormhole-features-specification.md (technical specs)
```

---

## Generic Sprint Planning Prompt Template

### Prompt: Review Project and Plan Next Sprint

```
You are joining the EVE DMV project as an AI assistant. Your task is to review the existing documentation and codebase, understand the project state, and plan the next sprint based on the strategic roadmap.

## Your Review Process

### 1. Project Understanding Phase
Review these key documents in order:
1. `/workspace/README.md` - Project overview and setup
2. `/workspace/CLAUDE.md` - AI assistant instructions and project conventions
3. `/workspace/docs/project-management/project-overview.md` - Comprehensive project summary
4. `/workspace/docs/project-management/goals-personas-usecases.md` - Target users and objectives
5. `/workspace/docs/project-management/prioritized-roadmap.md` - Development roadmap

### 2. Current State Analysis
Examine the current project status:
1. `/workspace/docs/project-management/project-status.md` - What's been completed
2. `/workspace/docs/sprints/` - Review all previous sprint documentation
3. Check for any sprint-X-bug-fixes.md files
4. Note which sprint was last completed

### 3. Technical Architecture Review
Understand the technical implementation:
1. `/workspace/docs/architecture/DESIGN.md` - System architecture
2. `/workspace/docs/implementation/` - Feature specifications
3. Review key code patterns in:
   - `/workspace/lib/eve_dmv/` - Core business logic (Ash resources)
   - `/workspace/lib/eve_dmv_web/live/` - LiveView modules
   - `/workspace/test/` - Testing patterns

### 4. Identify Next Sprint
Based on your review:
1. Determine which sprint number is next
2. Find the corresponding sprint plan in the roadmap
3. Check if there are any outstanding bugs or technical debt
4. Consider any shifts in project focus or priorities

### 5. Create Sprint Plan
Create `/workspace/docs/sprints/sprint-[N].md` with:

```markdown
# Sprint [N]: [Theme Name]

## Sprint Overview
- **Sprint Number**: [N]
- **Duration**: 2 weeks (Weeks [X-Y])
- **Theme**: [Brief theme description]
- **Goal**: [Primary sprint objective]

## Context from Previous Sprints
[Summary of what was completed and any relevant carryover]

## User Stories

### Story 1: [Feature Name] ([X] pts)
**As a** [persona]
**I want** [functionality]
**So that** [benefit]

**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

**Technical Tasks:**
- [ ] Create Ash resources for [entity]
- [ ] Implement LiveView for [feature]
- [ ] Add tests for [functionality]
- [ ] Update documentation

[Repeat for each story]

## Technical Considerations
- [Any special technical requirements]
- [Integration points]
- [Performance considerations]

## Success Metrics
- [How we'll measure sprint success]
- [Key performance indicators]

## Dependencies
- [External dependencies]
- [Internal prerequisites]

## Risks and Mitigation
- [Identified risks]
- [Mitigation strategies]
```

### 6. Update Project Documentation
1. Update `/workspace/docs/project-management/project-status.md`:
   - Add new sprint section
   - Update "Next Immediate Tasks"
   
2. Create `/workspace/docs/sprints/sprint-[N]-bug-fixes.md`:
   ```markdown
   # Sprint [N] Bug Fixes
   
   ## Bug Tracking
   
   [This file will track bugs discovered during Sprint [N]]
   ```

### 7. Begin Implementation
After planning is complete:
1. Review the highest priority user story
2. Check existing code patterns for similar features
3. Design the implementation approach
4. Start with database schema/Ash resources if needed
5. Follow TDD practices

## Important Project-Specific Notes
- **Framework**: Phoenix 1.7.21 with LiveView
- **Data Layer**: Ash Framework 3.4 (NOT traditional Ecto)
- **Real-time**: Broadway for killmail pipeline
- **Focus**: Wormhole corporations (J-space)
- **Integration**: Wanderer map is primary integration

## Questions to Answer During Review
1. What features were completed in the last sprint?
2. Are there any outstanding bugs or issues?
3. What's the next priority according to the roadmap?
4. Has the project focus shifted since the roadmap was created?
5. Are there any technical debts that should be addressed?
6. What patterns have been established that should be followed?

## Output Expected
1. A clear understanding of project state
2. Sprint [N] documentation created
3. Project status updated
4. Clear plan for first feature to implement
5. Any questions or clarifications needed

Please proceed with reviewing the project documentation and planning the next sprint.
```

---

*These prompts ensure consistent sprint management and maintain project momentum with proper documentation.*