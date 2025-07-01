# 🤖 AI Assistant Sprint 4.5 Prompt

## Sprint Completion Prompt Template

### Prompt: Complete Sprint 4.5 - ESI Integration & Technical Debt

```
You are working on EVE DMV, a wormhole-focused PvP intelligence platform for EVE Online. Your task is to complete Sprint 4.5, which focuses on ESI integration and technical debt completion.

## Context
- **Project**: EVE DMV - Wormhole intelligence platform integrated with real-time killmail data
- **Current Sprint**: Sprint 4.5 (ESI Integration & Technical Debt)
- **Sprint Status**: 0/25 story points completed, all features pending
- **Previous Achievement**: 84/84 story points completed across Sprints 1-4

## Sprint 4.5 Scope
According to /workspace/docs/sprints/sprint-4.5.md, implement these 6 features:

1. **ESI Character & Corporation Integration** (5 pts) - Replace placeholder character/corp data with real ESI calls
2. **ESI Skill Data Integration** (6 pts) - Real skill levels for accurate fleet composition analysis
3. **ESI Static Data Integration** (4 pts) - Real ship mass and item data for precise calculations
4. **ESI Employment History Integration** (3 pts) - Complete corp history for accurate vetting
5. **Complete Sprint 3 Threat Analyzer TODOs** (3 pts) - Blue/red lists and standings integration
6. **ESI Asset & Ship Availability** (4 pts) - Real hangar contents for fleet readiness

## Key Project Files
- **Sprint Documentation**: /workspace/docs/sprints/sprint-4.5.md
- **Project Status**: /workspace/PROJECT_STATUS.md
- **Development Guidelines**: /workspace/CLAUDE.md
- **Existing Analyzer Services**: /workspace/lib/eve_dmv/intelligence/

## Your Implementation Tasks

### Phase 1: ESI Service Infrastructure (Days 1-3)
1. **Create ESI Service Layer**:
   ```
   /workspace/lib/eve_dmv/esi/
   ├── auth_service.ex - OAuth2 token management
   ├── character_service.ex - Character data and portraits
   ├── corporation_service.ex - Corp/alliance information
   ├── skill_service.ex - Skill levels and training queues
   ├── static_data_service.ex - Ships, items, systems
   ├── asset_service.ex - Character and corp assets
   └── rate_limiter.ex - ESI rate limit compliance
   ```

2. **Set up ESI Authentication**:
   - OAuth2 token management for ESI access
   - Rate limiting to respect ESI constraints
   - Caching layer (Redis) for frequently accessed data
   - Error handling for ESI failures

3. **Configure ESI Endpoints**:
   - `/characters/{character_id}/` - Basic character info
   - `/corporations/{corporation_id}/` - Corporation details
   - `/characters/{character_id}/skills/` - Character skills
   - `/universe/types/{type_id}/` - Ship/item data
   - `/characters/{character_id}/corporationhistory/` - Employment history
   - `/characters/{character_id}/assets/` - Character assets

### Phase 2: Replace Placeholder Functions (Days 4-8)
1. **Update Character/Corp Integration**:
   - Replace `get_character_info/1` in all analyzer services
   - Replace `get_corporation_info/1` in WHFleetAnalyzer
   - Add character portraits and corp logos
   - Update character intelligence pages with real data

2. **Integrate Real Skill Data**:
   - Update `pilot_meets_skill_requirements?/2` in WHFleetAnalyzer
   - Replace skill gap analysis with real skill levels
   - Update `analyze_skill_requirements/2` functions
   - Add skill-based pilot role recommendations

3. **Replace Static Data Placeholders**:
   - Update `get_ship_info/1` with real ship data from ESI
   - Replace mass calculations with accurate ship masses
   - Update `extract_ship_types_from_doctrine/1` with real type IDs
   - Add system security status lookups

### Phase 3: Employment History & Threat Analysis (Days 9-11)
1. **Complete Employment History**:
   - Update `analyze_employment_history/1` in WHVettingAnalyzer
   - Add corp hopping detection algorithms
   - Implement experience scoring based on corp types
   - Create employment timeline visualization data

2. **Complete Sprint 3 Threat Analyzer TODOs**:
   - Implement blue/red list checking against known hostiles
   - Add corporation and alliance standings integration
   - Create threat level escalation based on standings
   - Update character intelligence with threat assessments

### Phase 4: Asset Integration & Completion (Days 12-14)
1. **Implement Asset Tracking**:
   - Create asset service for character/corp hangars
   - Update fleet readiness calculations with real ship counts
   - Add asset location and accessibility analysis
   - Implement asset-based doctrine recommendations

2. **Integration & Testing**:
   - End-to-end testing of all ESI integrations
   - Performance optimization and caching validation
   - Error handling and fallback mechanism testing
   - Update all affected LiveView pages

3. **Documentation & Deployment**:
   - Update CLAUDE.md with ESI integration patterns
   - Document rate limiting and caching strategies
   - Update PROJECT_STATUS.md with completion status
   - Run quality checks: `mix quality.check`

## Critical Technical Requirements

### ESI Integration Patterns
- **Authentication**: Use OAuth2 for ESI access with proper token refresh
- **Rate Limiting**: Respect ESI rate limits (100 requests/second)
- **Caching**: Implement Redis caching for static and semi-static data
- **Error Handling**: Graceful fallbacks when ESI is unavailable
- **Background Jobs**: Use Oban for bulk data refresh operations

### Data Update Strategy
- **Character Data**: Cache for 1 hour, refresh on character page visits
- **Corporation Data**: Cache for 6 hours, refresh daily via background job
- **Skills Data**: Cache for 24 hours, refresh when skill changes detected
- **Static Data**: Cache permanently, refresh monthly or on game updates
- **Assets**: Cache for 30 minutes, refresh on fleet composition analysis

### Integration Points to Update
```elixir
# Current placeholder functions to replace:
- EveDmv.Intelligence.WHVettingAnalyzer.get_character_info/1
- EveDmv.Intelligence.WHVettingAnalyzer.analyze_employment_history/1
- EveDmv.Intelligence.WHFleetAnalyzer.get_character_info/1
- EveDmv.Intelligence.WHFleetAnalyzer.get_corporation_info/1
- EveDmv.Intelligence.WHFleetAnalyzer.get_ship_info/1
- EveDmv.Intelligence.WHFleetAnalyzer.pilot_meets_skill_requirements?/2
- EveDmv.Intelligence.MemberActivityAnalyzer.get_character_info/1
- EveDmv.Intelligence.HomeDefenseAnalyzer.get_corporation_members/1
```

## Important Project Context
- **Framework**: Phoenix 1.7.21 with LiveView for real-time UI
- **Data Layer**: Ash Framework 3.4 for resources (NOT traditional Ecto)
- **Real-time**: Broadway pipeline for killmail ingestion
- **Focus**: Wormhole corporations and J-space operations
- **Current State**: All core features implemented with placeholder data

## Success Criteria & Definition of Done
- [ ] All 6 features implemented and tested (25 story points)
- [ ] Character/corp data sourced from ESI with proper caching
- [ ] Skill analysis uses real character skills for accurate gap analysis
- [ ] Mass calculations use accurate ship data for wormhole operations
- [ ] Employment history complete with corp hopping detection
- [ ] Threat analyzer includes standings-based assessment and blue/red lists
- [ ] Asset tracking integrated with fleet readiness calculations
- [ ] Proper ESI rate limiting and error handling implemented
- [ ] Performance optimized with Redis caching
- [ ] All existing functionality preserved during migration
- [ ] Quality checks pass: `mix quality.check`
- [ ] Sprint documentation updated with completion status
- [ ] PROJECT_STATUS.md updated

## Expected Outcomes
After Sprint 4.5 completion:
1. **Production-Ready Intelligence**: Real EVE data replaces all placeholders
2. **Accurate Fleet Analysis**: Real skills and ship data for precise doctrine planning
3. **Enhanced Vetting**: Complete employment history with corp hopping detection
4. **Threat Assessment**: Functional standings-based threat analysis
5. **Asset Integration**: Real hangar contents for fleet readiness
6. **Performance Optimized**: Proper caching and rate limiting for production use

## Implementation Priority Order
1. **High Priority**: Character/Corp integration (affects all features)
2. **High Priority**: Static data integration (affects mass calculations)
3. **High Priority**: Skill data integration (affects fleet composition)
4. **Medium Priority**: Employment history (affects vetting accuracy)
5. **Medium Priority**: Asset tracking (affects fleet readiness)
6. **Medium Priority**: Threat analyzer completion (affects intelligence)

Please implement these features following the existing Ash Framework patterns and maintaining the high code quality standards established in previous sprints. Focus on one feature at a time, test thoroughly, and update documentation as you progress.
```

---

## Usage Instructions

1. **Copy the prompt above** when starting Sprint 4.5 implementation
2. **Provide context** by ensuring the AI has access to all project documentation
3. **Monitor progress** by checking the todo list and sprint documentation regularly
4. **Focus on quality** over speed - ESI integration is critical for production readiness
5. **Test extensively** - ESI failures should not break the application

## File Structure Reminder
```
/workspace/docs/sprints/
├── sprint-4.5.md (sprint specification)
└── sprint-4.5-ai-prompt.md (this file)

/workspace/lib/eve_dmv/
├── esi/ (to be created - ESI service layer)
└── intelligence/ (existing analyzers to update)
```

---

*This prompt ensures systematic implementation of ESI integration while maintaining code quality and existing functionality.*