# Sprint 4.5: ESI Integration & Technical Debt

## Sprint Overview
- **Sprint Number**: 4.5 (Integration Sprint)
- **Duration**: 2 weeks (Weeks 9-10)
- **Theme**: ESI Integration & Completion
- **Goal**: Complete ESI integration for core features and resolve outstanding technical debt

## User Stories

### 1. ESI Character & Corporation Integration (5 pts)
**As a** wormhole corporation leadership member  
**I want** accurate character and corporation information from EVE's official API  
**So that** vetting and analytics data is current and reliable

**Acceptance Criteria:**
- Real character names, portraits, and current corporation/alliance affiliations
- Corporation details including member count, tax rate, and description
- Alliance information when applicable
- Automatic updates when characters change corporations
- Proper error handling for characters that no longer exist

**Technical Implementation:**
- ESI endpoints: `/characters/{character_id}/`, `/corporations/{corporation_id}/`, `/alliances/{alliance_id}/`
- Update `get_character_info/1` and `get_corporation_info/1` placeholder functions
- Add character portrait URLs and corp/alliance logos
- Implement caching to respect ESI rate limits
- Add background jobs for data refresh

**Definition of Done:**
- All character and corporation data sourced from ESI
- Character intelligence pages show real portraits and current affiliations
- Vetting system uses accurate employment history
- Error handling for missing/invalid characters

---

### 2. ESI Skill Data Integration (6 pts)
**As a** fleet commander planning doctrine compositions  
**I want** real skill data from pilot characters  
**So that** fleet readiness and skill gap analysis is accurate

**Acceptance Criteria:**
- Real character skill levels for doctrine requirements
- Current training queue analysis for improvement recommendations
- Skill gap calculations based on actual character skills
- Ship flying capabilities based on skill requirements
- Skill group proficiency ratings (Spaceship Command, Gunnery, etc.)

**Technical Implementation:**
- ESI endpoints: `/characters/{character_id}/skills/`, `/characters/{character_id}/skillqueue/`
- Create EveDmv.ESI.SkillService for skill data management
- Update WHFleetAnalyzer skill gap analysis functions
- Add skill requirement validation for ship types
- Implement skill-based pilot role recommendations

**Definition of Done:**
- Fleet composition shows real pilot skill readiness
- Vetting system includes accurate skill assessments
- Training priority recommendations based on actual skill gaps
- Skill-based ship assignment in fleet tools

---

### 3. ESI Static Data Integration (4 pts)
**As a** system analyzing fleet compositions  
**I want** accurate ship and item data from EVE's static data  
**So that** mass calculations and ship requirements are precise

**Acceptance Criteria:**
- Real ship mass, volume, and attribute data
- Accurate item type information for all EVE assets
- System security status and regional data
- Ship group classifications and tech levels
- Proper ship mass calculations for wormhole operations

**Technical Implementation:**
- ESI endpoints: `/universe/types/{type_id}/`, `/universe/systems/{system_id}/`
- Create EveDmv.ESI.StaticDataService for cached static data
- Update ship mass calculation functions with real data
- Add ship group and meta level analysis
- Implement system security and region lookups

**Definition of Done:**
- Fleet composition mass calculations use real ship data
- Ship suitability ratings based on actual attributes
- System activity analysis includes security status
- Item type resolution for all game assets

---

### 4. ESI Employment History Integration (3 pts)
**As a** recruiter conducting pilot vetting  
**I want** complete employment history from EVE's API  
**So that** I can assess pilot loyalty and experience accurately

**Acceptance Criteria:**
- Complete corporation history with dates and reasons
- Alliance affiliation tracking over time
- Corp hopping detection and risk scoring
- Experience duration calculations per corporation type
- Integration with existing WH vetting risk assessments

**Technical Implementation:**
- ESI endpoint: `/characters/{character_id}/corporationhistory/`
- Update `analyze_employment_history/1` in WHVettingAnalyzer
- Add corp-hopping detection algorithms
- Implement experience scoring based on corp types
- Create timeline visualization data structures

**Definition of Done:**
- WH vetting shows complete employment timeline
- Corp hopping risk factors calculated accurately
- Experience scoring includes real tenure data
- Employment stability metrics integrated

---

### 5. Complete Sprint 3 Threat Analyzer TODOs (3 pts)
**As a** user of the threat analysis system  
**I want** the remaining threat analysis features completed  
**So that** the system provides comprehensive threat assessment

**Acceptance Criteria:**
- Blue/red list checking against known hostile entities
- Corporation and alliance standings integration
- Threat level escalation based on standings
- Known hostile detection and alerting
- Integration with existing character intelligence

**Technical Implementation:**
- Complete TODO items in threat analyzer functions
- Implement blue/red list checking algorithms
- Add standings-based threat escalation
- Create hostile entity detection
- Update character intelligence with threat data

**Definition of Done:**
- Threat analyzer includes standings-based assessment
- Blue/red list functionality operational
- Hostile detection integrated with character profiles
- Threat levels accurately calculated

---

### 6. ESI Asset & Ship Availability (4 pts)
**As a** fleet commander  
**I want** to see actual ship availability for my corporation  
**So that** doctrine readiness reflects real assets

**Acceptance Criteria:**
- Real ship counts from character and corporation hangars
- Asset location tracking for staging systems
- Ship availability vs doctrine requirements
- Asset value calculations for fleet compositions
- Hangar management recommendations

**Technical Implementation:**
- ESI endpoints: `/characters/{character_id}/assets/`, `/corporations/{corporation_id}/assets/`
- Create EveDmv.ESI.AssetService for asset management
- Update fleet readiness calculations with real ship counts
- Add asset location and accessibility analysis
- Implement asset-based doctrine recommendations

**Definition of Done:**
- Fleet composition shows real ship availability
- Asset tracking integrated with readiness metrics
- Ship availability influences doctrine recommendations
- Asset management guidance provided

---

## Sprint Planning

### Week 1: Core ESI Integration
**Days 1-3: Character & Corporation Data**
- Set up ESI authentication and rate limiting
- Implement character and corporation info services
- Update all character lookups to use ESI
- Add proper error handling and caching

**Days 4-5: Static Data Integration**
- Implement static data service with caching
- Update mass calculations with real ship data
- Add ship attribute analysis
- Update system and region lookups

**Days 6-7: Skill Data Foundation**
- Create skill service infrastructure
- Implement skill data retrieval and caching
- Begin updating skill gap analysis

### Week 2: Advanced Features & Completion
**Days 8-10: Skills & Employment History**
- Complete skill integration in fleet tools
- Implement employment history analysis
- Update vetting system with real data
- Add skill-based recommendations

**Days 11-12: Asset Tracking & Threat Analysis**
- Implement asset tracking services
- Complete Sprint 3 threat analyzer TODOs
- Add standings and hostile detection
- Update fleet readiness with real assets

**Days 13-14: Integration & Testing**
- End-to-end testing of all ESI integrations
- Performance optimization and caching
- Error handling and fallback mechanisms
- Documentation and deployment preparation

## Technical Architecture

### ESI Service Layer
```
EveDmv.ESI.
├── AuthService - OAuth2 token management
├── CharacterService - Character data and portraits
├── CorporationService - Corp/alliance information
├── SkillService - Skill levels and training queues
├── StaticDataService - Ships, items, systems
├── AssetService - Character and corp assets
└── RateLimiter - ESI rate limit compliance
```

### Integration Points
- **WHVettingAnalyzer**: Employment history, skill assessment
- **WHFleetAnalyzer**: Real skill gaps, ship availability
- **MemberActivityAnalyzer**: Enhanced activity tracking
- **CharacterStats**: Real-time character information
- **ThreatAnalyzer**: Standings-based threat assessment

### Caching Strategy
- **Redis cache** for frequently accessed ESI data
- **Background jobs** for bulk data refresh
- **Smart cache invalidation** based on data staleness
- **Fallback mechanisms** when ESI is unavailable

## Acceptance Criteria Summary

✅ **All character data sourced from ESI**  
✅ **Real skill analysis in fleet tools**  
✅ **Accurate ship mass calculations**  
✅ **Complete employment history tracking**  
✅ **Functional threat analysis with standings**  
✅ **Asset-based fleet readiness**  
✅ **Proper error handling and caching**  
✅ **Performance optimized for production**  

## Story Points Breakdown
- ESI Character & Corporation Integration: **5 pts**
- ESI Skill Data Integration: **6 pts**  
- ESI Static Data Integration: **4 pts**
- ESI Employment History Integration: **3 pts**
- Complete Sprint 3 Threat Analyzer TODOs: **3 pts**
- ESI Asset & Ship Availability: **4 pts**

**Total: 25 story points**

## Definition of Done
- [ ] All ESI integrations functional and tested
- [ ] Character/corp data sourced from ESI 
- [ ] Skill analysis uses real character skills
- [ ] Mass calculations use accurate ship data
- [ ] Employment history complete and analyzed
- [ ] Threat analyzer TODOs completed
- [ ] Asset tracking integrated with fleet tools
- [ ] Proper caching and rate limiting implemented
- [ ] Error handling for ESI failures
- [ ] Performance optimized for production use
- [ ] Documentation updated for ESI integration
- [ ] All existing functionality preserved during migration

---

## Technical Debt & Code Quality Items

### High Priority Issues
1. **Authentication Security** - Missing auth mount on WH vetting route (router.ex:39)
2. **ESI Integration Gaps** - Multiple placeholder functions need real ESI implementation:
   - Character search in wh_vetting_live.ex
   - Employment history analysis in wh_vetting_analyzer.ex  
   - Wormhole skill assessment integration
   - Skill requirement validation in fleet analyzer

### Medium Priority Refactoring
3. **Code Organization** - Large modules need decomposition:
   - HomeDefenseAnalyzer (671 lines) → split into focused modules
   - Extract formatting helpers into shared VettingFormatter module
   
4. **Configuration Management** - Move hardcoded values to config:
   - Eviction group names in wh_vetting_analyzer.ex
   - Recommendation thresholds and magic numbers
   - Ship data in wh_fleet_analyzer.ex

5. **Error Handling Improvements**:
   - Sanitize user-facing error messages  
   - Replace Task.start/1 with supervised tasks
   - Improve error propagation vs silent failures
   - Replace generic rescue clauses with specific handling

6. **Performance & User Experience**:
   - Implement search debouncing to reduce API calls
   - Add search timer management
   - Fix participation rate calculation logic
   - Add validation constraints for score attributes

### Low Priority Polish
7. **Code Documentation** - Add TODO comments for placeholder functions
8. **Database Optimization** - Review GIN indexes for actual usage patterns  
9. **UI Robustness** - Add nil checks for optional fields in templates
10. **Naming Clarity** - Improve ambiguous attribute comments

### Implementation Strategy
- **Week 1**: Focus on high-priority security and ESI integration items
- **Week 2**: Address medium-priority refactoring and error handling
- **Ongoing**: Low-priority items can be tackled during regular development

This technical debt cleanup will improve code maintainability, security, and user experience while establishing patterns for future development.

---

*Sprint 4.5 bridges the gap between placeholder data and production-ready ESI integration, providing the foundation for accurate intelligence analysis and fleet management.*