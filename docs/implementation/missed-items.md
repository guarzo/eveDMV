# Sprint 4 - Deferred/Missed Intelligence Features

> **Generated on 2025-01-07 during code quality analysis**
> 
> This document tracks intelligence functionality that was scoped for Sprint 4 but either implemented as stubs or deferred due to complexity.

## Overview

During Sprint 4 analysis, we discovered that many intelligence features were implemented as placeholder stubs rather than working functionality. To focus on core killmail-based analysis, the following complex ESI integrations have been deferred to future sprints.

## 🚫 Deferred ESI Integrations

### Character Skills API Integration
**Complexity**: High - Requires ESI token management, skill tree understanding, and training queue analysis

**Deferred Functions:**
- `WHVettingAnalyzer.assess_wh_skills/1` (lines 475-483)
  - Currently returns all zeros for wormhole-related skills
  - Should assess: Cloaking, Scanning, Navigation, Wormhole skills
  - **Impact**: Vetting pipeline cannot assess pilot readiness

- `WHFleetAnalyzer.generate_training_priorities/2` (lines 598-608)  
  - Currently returns hardcoded training recommendations
  - Should analyze skill gaps vs doctrine requirements
  - **Impact**: Cannot provide actionable training guidance

- `WHFleetAnalyzer.calculate_pilot_skill_readiness/2` (lines 687-696)
  - Currently hardcoded to 0.8 (80% readiness)
  - Should check actual pilot skills vs ship/fitting requirements
  - **Impact**: Fleet composition optimization is inaccurate

### Character Assets API Integration  
**Complexity**: Very High - Requires asset location tracking, fitting analysis, and availability calculations

**Deferred Functions:**
- `WHFleetAnalyzer.get_asset_availability/2` (lines 228-237)
  - Currently returns placeholder asset data when no auth token
  - Should query pilot assets, ship availability, fitting modules
  - **Impact**: Fleet doctrines cannot account for actual ship availability

- `WHFleetAnalyzer.select_best_ship_for_pilot/2` (lines 681-685)
  - Currently returns first available ship with comment
  - Should match pilot skills + available assets to optimal ship choice
  - **Impact**: Suboptimal pilot assignments in fleet composition

### Structure/Citadel APIs Integration
**Complexity**: Very High - Requires structure permissions, fitting analysis, and strategic assessment

**Deferred Functions:**
- `HomeDefenseAnalyzer.assess_infrastructure_strength/1` (lines 527-535)
  - Currently returns hardcoded infrastructure assessment
  - Should analyze citadel types, fittings, anchoring patterns, vulnerability windows
  - **Impact**: Home defense analysis lacks infrastructure component

## 📊 Impact Analysis

### Immediate Impact (Current Sprint 4 Delivery)
- **Vetting System**: 60% functionality missing (no skill assessment)
- **Fleet Optimization**: 70% functionality missing (no asset/skill integration)  
- **Home Defense**: 40% functionality missing (no infrastructure analysis)
- **Overall Intelligence**: Relies entirely on killmail analysis patterns

### User Experience Impact
- Vetting recommendations lack depth and accuracy
- Fleet doctrines may recommend unavailable ships
- Training priorities are generic rather than personalized
- Infrastructure vulnerabilities go undetected

## 🎯 Future Sprint Recommendations

### Sprint 6: Character Skills Foundation
**Effort**: 3-4 weeks
- Implement ESI character skills integration
- Add skill requirement definitions for common WH doctrines
- Build skill gap analysis engine
- Create training priority recommendation system

**Deliverables:**
- Real pilot skill assessment in vetting
- Accurate pilot readiness calculations
- Personalized training recommendations

### Sprint 7: Asset Management Integration  
**Effort**: 4-5 weeks  
- Implement ESI character assets integration
- Add ship availability tracking
- Build asset-aware fleet composition system
- Create fitting requirement validation

**Deliverables:**
- Real-time ship availability in fleet planning
- Asset-based pilot assignments
- Fitting compatibility validation

### Sprint 8: Infrastructure Analysis
**Effort**: 2-3 weeks
- Implement ESI structure integration (if available)
- Add citadel vulnerability analysis
- Create infrastructure strength assessment
- Build defensive capability recommendations

**Deliverables:**
- Comprehensive home defense analysis
- Infrastructure vulnerability detection
- Defensive upgrade recommendations

## 🔧 Technical Requirements

### ESI Scopes Required
```
esi-skills.read_skills.v1           # Character skills
esi-skills.read_skillqueue.v1       # Training queue
esi-assets.read_assets.v1           # Character assets  
esi-universe.read_structures.v1     # Structure information
esi-corporations.read_structures.v1  # Corporation structures
```

### Database Schema Extensions
```sql
-- Character skills cache
CREATE TABLE character_skills (
  character_id BIGINT,
  skill_type_id INTEGER,
  trained_skill_level INTEGER,
  skillpoints_in_skill BIGINT,
  active_skill_level INTEGER,
  last_updated TIMESTAMP,
  PRIMARY KEY (character_id, skill_type_id)
);

-- Asset tracking
CREATE TABLE character_assets (
  character_id BIGINT,
  item_id BIGINT PRIMARY KEY,
  type_id INTEGER,
  location_id BIGINT,
  location_type VARCHAR(50),
  quantity INTEGER,
  last_updated TIMESTAMP
);

-- Infrastructure tracking  
CREATE TABLE corporation_structures (
  structure_id BIGINT PRIMARY KEY,
  corporation_id INTEGER,
  type_id INTEGER,
  system_id INTEGER,
  vulnerability_schedule JSONB,
  last_updated TIMESTAMP
);
```

### Caching Strategy
- **Skills**: Cache for 24 hours (skills change slowly)
- **Assets**: Cache for 6 hours (assets move frequently)  
- **Structures**: Cache for 1 hour (vulnerability windows change)

## 🚨 Alternative Approaches

### Option 1: Simplified Heuristics
Instead of full ESI integration, use killmail-based heuristics:
- **Skill Assessment**: Infer skills from ships flown and modules used
- **Asset Availability**: Assume basic doctrine ships available
- **Infrastructure**: Focus on killmail location patterns

**Pros**: Much faster implementation, no ESI complexity
**Cons**: Less accurate, missing key insights

### Option 2: Optional ESI Features
Implement ESI integrations as optional enhancements:
- Core analysis works without ESI data
- Enhanced analysis available when tokens provided
- Graceful degradation when ESI unavailable

**Pros**: Incremental rollout, user choice
**Cons**: Complex dual-path logic, inconsistent user experience

### Option 3: Third-party Integration
Use existing EVE tools with ESI integration:
- Partner with existing skill planners
- Integrate with asset management tools
- Focus on unique intelligence analysis

**Pros**: Faster delivery, proven integrations
**Cons**: External dependencies, limited customization

## 📈 Prioritization Factors

1. **User Value**: Skills > Assets > Structures
2. **Implementation Complexity**: Structures > Assets > Skills  
3. **ESI Reliability**: Skills (stable) > Assets (rate limited) > Structures (complex permissions)
4. **Maintenance Burden**: Assets > Structures > Skills

**Recommended Order**: Skills → Assets → Structures

## 📋 Success Metrics

### Sprint 6 (Skills) Success Criteria
- [ ] Vetting accuracy improves by 40%
- [ ] Training recommendations are pilot-specific
- [ ] Fleet readiness calculations reflect real capabilities
- [ ] User satisfaction with vetting increases significantly

### Sprint 7 (Assets) Success Criteria  
- [ ] Fleet doctrines account for actual ship availability
- [ ] Pilot assignments optimize for available assets
- [ ] Asset-based recommendations reduce doctrine violations
- [ ] Fleet formation time decreases due to better planning

### Sprint 8 (Structures) Success Criteria
- [ ] Home defense analysis includes infrastructure vulnerabilities
- [ ] Infrastructure recommendations are actionable
- [ ] Defensive capability assessment is comprehensive
- [ ] Strategic planning accounts for citadel capabilities

---

## 📞 Implementation Notes

**ESI Rate Limiting**: All integrations must respect ESI rate limits and implement proper caching
**Token Management**: Secure token storage and refresh handling required
**Graceful Degradation**: All features must work (with reduced accuracy) when ESI data unavailable
**Privacy Considerations**: Asset and skill data is sensitive - implement proper access controls

This deferred functionality represents approximately **60% of the originally envisioned Sprint 4 intelligence capabilities**. Focusing on killmail-based analysis first provides immediate value while building foundation for these advanced features.