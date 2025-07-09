# Sprint 5: System Intelligence & Universal Search

**Duration**: 2 weeks  
**Start Date**: 2025-01-13  
**End Date**: 2025-01-27  
**Sprint Goal**: Build working System Intelligence pages with citadel/structure tracking and universal search functionality  
**Philosophy**: "If it returns mock data, it's not done."

---

## 🎯 Sprint Objective

### Primary Goal
Deliver a working System Intelligence feature that analyzes solar system activity, structure kills, and danger assessment, plus a universal search system for seamless navigation.

### Success Criteria
- [ ] System overview pages load real activity data from killmails_raw table
- [ ] Citadel and structure kill tracking with proper categorization
- [ ] System danger assessment algorithm using real killmail statistics
- [ ] Universal search with auto-completion for characters, corporations, alliances, and systems
- [ ] Updated index page with universal search replacing character intel links
- [ ] All data comes from killmail/participant tables (no mocks)

### Explicitly Out of Scope
- Visual system maps or sovereignty data (statistics and data focus only)
- Popular routes analysis (wormhole focus doesn't need route tracking)
- ESI integration for structure ownership details
- Mobile deployable tracking (citadels/structures priority)
- Advanced search filtering beyond basic name matching

---

## 📊 Sprint Backlog

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| SYS-1 | Create system overview page with activity statistics | 5 | HIGH | Queries real killmail data, displays system stats |
| SYS-2 | System danger assessment algorithm | 3 | HIGH | Calculates danger score from kill/activity ratios |
| SYS-3 | System activity heatmap/statistics display | 3 | HIGH | Shows hourly/daily activity patterns |
| SYS-4 | Alliance/corp presence analysis per system | 3 | HIGH | Lists dominant entities in each system |
| SYS-5 | Structure/citadel kills tracking section | 4 | HIGH | Identifies and displays structure kills with types |
| SYS-6 | System search functionality | 2 | MEDIUM | Basic system name search with routing |
| SEARCH-1 | Universal search bar component | 3 | MEDIUM | Single search input with multi-entity support |
| SEARCH-2 | Auto-completion lookup service & cache | 5 | MEDIUM | Fast prefix search with 90-day activity filter |
| SEARCH-3 | Search result routing logic | 2 | MEDIUM | Routes to correct page based on entity type |
| SEARCH-4 | Updated index page with universal search | 3 | LOW | Remove character intel link, add universal search |

**Total Points**: 32 *(slightly larger scope, but builds cohesively)*

---

## 📈 Daily Progress Tracking

### Day 1 - January 13, 2025
- **Started**: Review EVE item types for structure identification and plan system queries
- **Completed**: [TBD]
- **Blockers**: [TBD]
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
- **Points Completed**: X/32
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
- [ ] All system data queries killmails_raw/participants tables
- [ ] Structure identification uses eve_item_types table
- [ ] No hardcoded system lists or statistics
- [ ] All tests use real test data
- [ ] No compilation warnings
- [ ] No TODO comments in completed code

### Documentation
- [ ] README.md updated with system intelligence feature
- [ ] DEVELOPMENT_PROGRESS_TRACKER.md updated
- [ ] PROJECT_STATUS.md updated to show system intel working
- [ ] API documentation for new system queries
- [ ] User guide for system and search pages

### Testing Evidence
- [ ] Screenshots of working system pages
- [ ] Test multiple systems with different activity levels
- [ ] Verify structure kill detection is accurate
- [ ] Performance acceptable for high-activity systems
- [ ] Universal search works for all entity types
- [ ] Auto-completion responds quickly

---

## 📊 Sprint Metrics

### Delivery Metrics
- **Planned Points**: 32
- **Completed Points**: [TBD]
- **Completion Rate**: [TBD]%
- **Features Delivered**: [TBD]
- **Bugs Fixed**: [TBD]

### Quality Metrics
- **Test Coverage**: [TBD]%
- **Compilation Warnings**: 0
- **Runtime Errors Fixed**: [TBD]
- **Mock Code Removed**: [TBD lines]

### Reality Check Score
- **Features with Real Data**: [X/Y]
- **Features with Tests**: [X/Y]
- **Features Manually Verified**: [X/Y]

---

## 🔄 Sprint Retrospective

### What Went Well
1. [To be filled at sprint end]
2. [To be filled at sprint end]
3. [To be filled at sprint end]

### What Didn't Go Well
1. [To be filled at sprint end]
2. [To be filled at sprint end]
3. [To be filled at sprint end]

### Key Learnings
1. [To be filled at sprint end]
2. [To be filled at sprint end]
3. [To be filled at sprint end]

### Action Items for Next Sprint
- [ ] [To be filled at sprint end]
- [ ] [To be filled at sprint end]
- [ ] [To be filled at sprint end]

---

## 🚀 Next Sprint Recommendation

Based on this sprint's outcomes:

### Capacity Assessment
- **Actual velocity**: [TBD] points/sprint
- **Recommended next sprint size**: [TBD] points
- **Team availability**: [Any known issues]

### Technical Priorities
1. [To be determined based on learnings]
2. [To be determined based on learnings]
3. [To be determined based on learnings]

### Recommended Focus
**Sprint 6: [TBD]**
- Primary Goal: [Based on actual capacity]
- Estimated Points: [Conservative estimate]
- Key Risks: [Identified from this sprint]

---

## 📋 Implementation Notes

### Structure Identification Strategy
Query eve_item_types to identify citadels and structures:
```sql
-- Find structure types
SELECT type_id, type_name 
FROM eve_item_types 
WHERE type_name LIKE '%Citadel%' 
   OR type_name LIKE '%Complex%'
   OR type_name LIKE '%Refinery%'
   OR type_name LIKE '%Engineering%'
   OR type_name LIKE '%Astrahus%'
   OR type_name LIKE '%Fortizar%'
   OR type_name LIKE '%Keepstar%'
```

### Key System Queries Needed
1. **System Activity Query**
   ```sql
   SELECT 
     solar_system_id,
     COUNT(*) as total_kills,
     COUNT(DISTINCT character_id) as unique_pilots,
     COUNT(DISTINCT corporation_id) as unique_corps
   FROM participants p
   JOIN killmails_raw k ON p.killmail_id = k.killmail_id
   WHERE k.killmail_time >= $1
   GROUP BY solar_system_id
   ```

2. **Structure Kills Query**
   ```sql
   SELECT 
     k.solar_system_id,
     t.type_name as structure_type,
     COUNT(*) as structure_kills
   FROM killmails_raw k
   JOIN eve_item_types t ON k.victim_ship_type_id = t.type_id
   WHERE t.type_name LIKE '%Citadel%' OR t.type_name LIKE '%Complex%'
   GROUP BY k.solar_system_id, t.type_name
   ```

3. **Search Index Population**
   ```sql
   CREATE TABLE search_index (
     id SERIAL PRIMARY KEY,
     name TEXT NOT NULL,
     entity_type VARCHAR(20), -- 'character', 'corporation', 'alliance', 'system'
     entity_id BIGINT,
     popularity_score INTEGER DEFAULT 0, -- based on recent activity
     last_activity TIMESTAMP
   );
   ```

### Files to Create/Update
- `lib/eve_dmv_web/live/system_live.ex` - System overview LiveView
- `lib/eve_dmv_web/live/system_live.html.heex` - System page template
- `lib/eve_dmv/contexts/system_intelligence/` - New domain context
- `lib/eve_dmv/search/` - Universal search functionality
- `lib/eve_dmv_web/components/universal_search_component.ex` - Search UI component
- Update `lib/eve_dmv_web/router.ex` for system routes
- Update index page to remove character intel link

### Navigation Updates
**Remove from top navigation:**
- Character Intelligence link

**Keep in top navigation:**
- Live Feed link

**Add to index page:**
- Universal search bar with auto-completion
- Quick access cards for different intelligence types

---

**Remember**: Focus on citadels/structures over deployables, limit search to 90-day active entities, and prioritize system analysis before universal search implementation.