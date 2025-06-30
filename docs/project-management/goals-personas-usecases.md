# 🎯 EVE DMV - Goals, Personas, and Use Cases (Wormhole-First)

## Project Goals Hierarchy

### 🥇 Primary Goals
1. **Wormhole-Focused PvP Intelligence Platform**
   - Provide actionable intelligence for wormhole corporations
   - Chain-wide threat assessment and tracking
   - Enable better decision-making for small gang PvP
   - Integration with Wanderer map for seamless workflow

2. **Wormhole Community Adoption**
   - Become the standard intel tool for wormhole groups
   - Achieve adoption by 100+ active WH corporations
   - Maintain 80% daily active user rate during prime time

3. **Data Excellence**
   - 99%+ killmail capture rate from wanderer-kills
   - Real-time chain inhabitant tracking via Wanderer API
   - Complete character/corp profiles via ESI with director-level insights

### 🥈 Secondary Goals
1. **Performance & Reliability**
   - <200ms page load times
   - 99.5% uptime during peak hours
   - Handle 10,000+ concurrent users

2. **User Experience**
   - Visually impressive
   - Intuitive interface requiring no manual
   - Mobile-responsive design
   - Real-time updates without page refreshes

3. **Ecosystem Integration**
   - Full EVE ESI API utilization
   - Discord/Slack webhook support
   - Future API for third-party tools

## 👥 Detailed Personas

### 1. Wormhole FC "Alex"
**Background**: Experienced wormhole FC leading 10-30 pilot fleets

**Goals**:
- Assess threats when entering new wormholes
- Identify primary targets in small gang fights
- Track chain-wide hostile movements
- Make quick decisions on engagements

**Pain Points**:
- No intel on new chain inhabitants
- Difficulty assessing pilot specializations
- Manual checking of multiple tools
- Delayed intelligence on hostiles

**Key Features Needed**:
- Chain-wide inhabitant display via Wanderer integration
- Pilot threat assessment with WH-specific metrics
- Small gang composition analyzer
- Real-time updates when hostiles enter chain

---

### 2. WH Corp Recruiter "Sam"
**Background**: Recruitment officer for C5 wormhole corporation

**Goals**:
- Vet potential recruits for WH experience
- Identify security risks (seed scouts, awoxers)
- Assess small gang PvP competence
- Verify wormhole lifestyle compatibility

**Pain Points**:
- Hard to verify actual WH experience
- Difficult to identify known eviction alts
- No way to assess hole rolling discipline
- Can't verify claimed FC experience

**Key Features Needed**:
- WH-specific activity analysis
- Known associates in WH space
- Small gang performance metrics
- J-space activity history

---

### 3. WH Hunter "Jordan"
**Background**: Solo/small gang hunter roaming chains

**Goals**:
- Find active chains with targets
- Identify isolated targets vs bait
- Track personal hunting success
- Analyze effective hunting fits

**Pain Points**:
- Chains often empty or blue
- Hard to identify bait scenarios
- No intel on local group strength
- Can't predict target ship fits

**Key Features Needed**:
- Chain activity indicators
- Pilot association analysis (bait detection)
- Historical fit preferences by pilot
- "Home chain" identification for targets
- Real-time chain population tracking

---

### 4. WH Corp CEO "Morgan"
**Background**: CEO of 200-member C5/C6 corporation

**Goals**:
- Monitor member participation in home defense
- Track PvP performance trends
- Identify training needs
- Optimize fleet compositions for WH meta

**Pain Points**:
- No visibility into off-TZ coverage
- Hard to track who shows for fights
- Difficult to identify skill gaps
- Can't analyze doctrine effectiveness

**Key Features Needed**:
- Member activity tracking by timezone
- Home defense participation metrics
- Small gang performance analytics
- Doctrine effectiveness analysis

## 📋 Priority Use Cases

### 🔴 Critical Use Cases (Must Have)

1. **Real-time Kill Tracking**
   - User views live kill feed
   - System displays kills within 5 seconds
   - Each kill shows ISK value and involved parties
   - User can filter by region/system/ship

2. **Character Intelligence Lookup**
   - User searches for character name
   - System displays comprehensive profile
   - Shows recent kills/losses
   - Identifies patterns and associates

3. **Chain-Wide Surveillance**
   - User creates alert profile for their chain
   - System monitors all connected systems via Wanderer API
   - User receives notification when hostiles enter chain
   - Supports filters by pilot, corp, ship class
   - Real-time updates as chain topology changes

### 🟡 Important Use Cases (Should Have)

4. **Small Gang Battle Analysis**
   - FC selects engagement from Wanderer timeline
   - System pulls all involved parties and ships
   - Analyzes performance in WH meta context
   - Provides recommendations for doctrine adjustments
   - Shows effectiveness vs common WH comps

5. **WH-Specific Vetting**
   - Recruiter enters character name
   - System analyzes J-space activity history
   - Identifies eviction group associations
   - Shows small gang performance metrics
   - Flags suspicious alt patterns

6. **Active Chain Identification**
   - User views chain activity dashboard
   - System shows recent PvP by connection
   - Identifies farmer vs PvP groups
   - Highlights chains with ongoing conflicts

### 🟢 Enhanced Use Cases (Nice to Have)

7. **WH Fleet Optimization**
   - Wanderer API provides current fleet comp
   - System analyzes against WH doctrine templates
   - Shows critical role gaps (logi, tackle, DPS)
   - Recommends ships based on pilot skills
   - Predicts effectiveness vs common WH gangs

8. **Personal WH Performance**
   - User views WH-specific metrics
   - Tracks small gang contributions
   - Shows improvement in key WH skills
   - Analyzes performance by ship class
   - Provides training recommendations


## 🎯 Success Criteria by Persona

### Wormhole FC Success
- 80% reduction in hostile assessment time
- 40% improvement in engagement win rate
- Zero missed hostiles in chain
- Constant usage during ops via Wanderer integration

### WH Recruiter Success
- 90% confidence in WH experience verification
- Catch 100% of known eviction alts
- 50% reduction in bad recruit incidents
- Check every applicant through the tool

### WH Hunter Success
- 3x more successful ganks per roam
- 70% accurate bait identification
- Find content in <30 minutes
- Daily usage integrated with scanning

### WH Corp CEO Success
- Full visibility into TZ coverage gaps
- 30% improvement in fleet participation
- Identify training needs proactively
- Weekly doctrine effectiveness reviews

## 🚀 Feature Prioritization Matrix (Wormhole-First)

| Feature | WH FC | WH Recruiter | WH Hunter | WH CEO | Priority |
|---------|-------|--------------|-----------|---------|----------|
| Chain-Wide Intel | 🔴 | 🟡 | 🔴 | 🟡 | **P0** |
| WH Character Intel | 🟡 | 🔴 | 🔴 | 🟡 | **P0** |
| Chain Surveillance | 🔴 | 🔴 | 🔴 | 🔴 | **P0** |
| Wanderer Integration | 🔴 | 🟡 | 🔴 | 🔴 | **P0** |
| Small Gang Analysis | 🔴 | 🟡 | 🟡 | 🔴 | **P1** |
| Bait Detection | 🟡 | 🟡 | 🔴 | 🟢 | **P1** |
| Active Chains | 🟡 | 🟢 | 🔴 | 🟡 | **P1** |
| Fleet Optimization | 🔴 | 🟢 | 🟢 | 🟡 | **P2** |
| TZ Coverage | 🟡 | 🟢 | 🟢 | 🔴 | **P2** |
| Training Metrics | 🟢 | 🟢 | 🟡 | 🔴 | **P2** |

**Legend**: 🔴 Critical | 🟡 Important | 🟢 Nice to Have

## 📊 Usage Patterns (Wormhole-Focused)

### Constantly Active Features (via Wanderer)
1. Chain-wide inhabitant tracking (all personas)
2. Real-time hostile alerts (all personas)
3. Fleet composition display (FC, CEO)
4. Active chain indicators (Hunter, FC)

### Daily Active Features
1. Character intelligence lookups (all personas)
2. Bait detection checks (Hunter, FC)
3. Small gang battle analysis (FC, CEO)
4. Personal performance tracking (Hunter)

### Weekly Active Features
1. Recruitment vetting reports (Recruiter)
2. Doctrine effectiveness review (CEO, FC)
3. TZ coverage analysis (CEO)
4. Training need identification (CEO, FC)

### Monthly Active Features
1. Corp performance metrics (CEO)
2. Meta shifts in WH space (FC)
3. Member participation trends (CEO)
4. Recruitment pipeline analysis (Recruiter)

## 🌀 Wormhole-Specific Considerations

### Technical Integration Points
1. **Wanderer Map API**
   - Read chain topology and connections
   - Pull current system inhabitants
   - Access fleet composition data
   - Monitor chain activity timeline

2. **Enhanced ESI Usage**
   - Director-level permissions assumed for FCs
   - Real-time data for dynamic elements
   - Aggressive caching for static data
   - Corporation-wide analytics

3. **Performance Requirements**
   - Sub-second updates for chain changes
   - Handle rapid connection changes (rolling)
   - Support 50+ system chains
   - Concurrent monitoring of multiple chains

### Unique WH Challenges Addressed
- **No Local Chat** - Chain-wide intel replaces local
- **Dynamic Geography** - Real-time chain updates
- **Small Gang Meta** - Optimized for 5-30 pilot fights
- **High Stakes** - Emphasis on security and opsec
- **Tight Communities** - Focus on corp/alliance tools

---

*This document reflects our wormhole-first approach to EVE DMV development.*

*Last updated: 2025-06-29*