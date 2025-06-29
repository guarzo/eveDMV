# 🌀 EVE DMV - Wormhole Features Specification

## Overview

This document details the wormhole-specific features that differentiate EVE DMV from generic killboard tools. Our integration with Wanderer map and focus on J-space mechanics provides unique value to wormhole corporations.

## Core Wormhole Features

### 1. Wanderer Map Integration

#### 1.1 Basic Integration (Phase 1)
**Purpose**: Read-only access to chain topology and inhabitant data

**Data Flow**:
```
Wanderer Map → API → EVE DMV → Real-time Updates
```

**Key Endpoints**:
- `GET /api/chain/topology` - Current chain structure
- `GET /api/chain/inhabitants` - Pilots in each system
- `GET /api/fleet/composition` - Current fleet makeup
- `WS /api/chain/updates` - Real-time chain changes

**Implementation Details**:
- Poll topology every 5 seconds
- WebSocket for real-time updates
- Cache chain data with 30-second TTL
- Handle connection failures gracefully

#### 1.2 Data Synchronization
**Features**:
- Real-time chain topology updates
- System inhabitant tracking
- Connection lifecycle events (new/EOL/gone)
- Fleet composition monitoring

**Performance Requirements**:
- <1 second update latency
- Support 50+ system chains
- Handle rapid changes (rolling)
- Concurrent multi-chain monitoring

### 2. Chain-Wide Intelligence System

#### 2.1 Inhabitant Tracking
**Purpose**: Replace local chat with chain-wide awareness

**Features**:
- **Live Presence**: Show current inhabitants across entire chain
- **Historical Data**: "Last seen 10 minutes ago" tracking
- **Corporation Analysis**: Group pilots by corp/alliance
- **Threat Assessment**: Automatic threat level based on:
  - Kill/loss ratio in J-space
  - Ship types commonly flown
  - Known associates
  - Time in J-space

**UI Components**:
```
┌─────────────────────────────────────┐
│ Chain Intelligence Dashboard        │
├─────────────────────────────────────┤
│ J123456 (C5) - Home                │
│ ├─ [5 Friendlies] [2 Neutrals]     │
│ │                                   │
│ J234567 (C3) - Static              │
│ ├─ [0 Friendlies] [4 Hostiles]     │
│ │   └─ ⚠️ Hostile Fleet Detected    │
│ │                                   │
│ J345678 (C2) - K162                │
│ └─ [1 Friendly] [0 Others]         │
└─────────────────────────────────────┘
```

#### 2.2 Real-time Alerts
**Alert Types**:
- Hostile enters chain
- Known eviction group detected
- Hostile fleet forming
- Rolling detected on connection
- High-value target spotted

**Delivery Methods**:
- In-app notifications
- Discord webhooks
- Audio alerts (customizable)
- Desktop notifications

### 3. WH-Specific Character Intelligence

#### 3.1 J-Space Activity Profile
**Data Points**:
- Total time in J-space (last 90 days)
- J-space kill/loss ratio
- Wormhole classes frequented
- Common ship types in WHs
- Peak activity times

**Bait Detection Algorithm**:
```python
def calculate_bait_probability(pilot):
    factors = {
        'solo_appearance': check_solo_frequency(pilot),
        'hidden_associates': find_frequent_partners(pilot),
        'ship_patterns': analyze_ship_progression(pilot),
        'engagement_outcomes': check_fight_escalations(pilot),
        'timing_patterns': detect_coordinated_logins(pilot)
    }
    return weighted_average(factors)
```

#### 3.2 Home Chain Identification
**Method**: Analyze where pilot spends most time
- Track system frequency over 30 days
- Identify static patterns
- Cross-reference with corp locations
- Flag "tourist" vs "resident" status

### 4. Small Gang Combat Analytics

#### 4.1 Engagement Analysis
**Metrics Tracked**:
- Average gang size (both sides)
- Ship composition effectiveness
- Target selection accuracy
- Logi effectiveness
- Range control success

**WH-Specific Factors**:
- Mass limitations considered
- Wormhole effects applied
- Home field advantage
- Hole control importance

#### 4.2 Doctrine Effectiveness
**Analysis Includes**:
- Success rate by doctrine
- Counter-doctrine performance
- Pilot performance by ship
- Optimal gang compositions

### 5. Fleet Composition Tools

#### 5.1 Real-time Fleet Analysis
**Via Wanderer Integration**:
```javascript
// Example fleet comp from Wanderer
{
  "fleet_id": "123456",
  "composition": {
    "dps": ["Loki", "Loki", "Legion", "Proteus"],
    "logi": ["Guardian", "Guardian"],
    "support": ["Sabre", "Devoter"],
    "ewar": ["Falcon"]
  },
  "mass_used": 234500000,
  "chain_position": "J123456"
}
```

#### 5.2 Gap Analysis
**Features**:
- Compare to doctrine templates
- Show missing roles
- Suggest ships based on pilots online
- Mass budget remaining
- Skill requirements check

### 6. Active Chain Detection

#### 6.1 Activity Scoring
**Algorithm**:
```
Activity Score = (
    Recent PvP kills * 3 +
    Unique pilots active * 2 +
    Site running detected * 1 +
    POS/Citadel count * 0.5
) / Hours since last activity
```

#### 6.2 Content Recommendations
**For Hunters**:
- Highlight active chains
- Show typical resistance
- Estimate response time
- Suggest optimal ships

### 7. Discord Integration (Future)

#### 7.1 Notification Templates
```
🚨 **HOSTILE ALERT** 🚨
Chain: Home -> C3 Static -> C5 K162
System: J123456
Hostiles: 5x Kikimora, 2x Zarmazd
Threat: High (Volta)
```

#### 7.2 Custom Commands
- `!intel <character>` - Quick lookup
- `!chain` - Current chain status
- `!fleet` - Fleet composition
- `!doctrine <name>` - Show doctrine

## Technical Implementation

### API Structure
```typescript
interface ChainIntelligence {
  chain_id: string;
  systems: SystemIntel[];
  connections: Connection[];
  last_update: timestamp;
  alerts: Alert[];
}

interface SystemIntel {
  system_id: string;
  wh_class: string;
  inhabitants: Pilot[];
  recent_activity: Activity[];
  static_type?: string;
}

interface Pilot {
  character_id: number;
  corporation: string;
  alliance?: string;
  threat_level: 'friendly' | 'neutral' | 'hostile';
  ship_type?: string;
  last_seen: timestamp;
  intel_summary: PilotIntel;
}
```

### Database Schema Additions
```sql
-- Chain tracking
CREATE TABLE chain_snapshots (
  id SERIAL PRIMARY KEY,
  chain_id VARCHAR(50),
  topology JSONB,
  inhabitants JSONB,
  snapshot_time TIMESTAMP,
  created_at TIMESTAMP
);

-- Pilot sightings
CREATE TABLE pilot_sightings (
  character_id BIGINT,
  system_id VARCHAR(10),
  ship_type_id INT,
  sighted_at TIMESTAMP,
  chain_id VARCHAR(50),
  PRIMARY KEY (character_id, sighted_at)
);

-- Alert history
CREATE TABLE chain_alerts (
  id SERIAL PRIMARY KEY,
  chain_id VARCHAR(50),
  alert_type VARCHAR(50),
  details JSONB,
  created_at TIMESTAMP
);
```

### Performance Optimizations

1. **Caching Strategy**:
   - Chain topology: 30-second cache
   - Pilot intel: 5-minute cache
   - Static data: 24-hour cache
   - Use Redis for distributed cache

2. **Real-time Updates**:
   - WebSocket connection to Wanderer
   - Phoenix PubSub for internal distribution
   - Debounce rapid changes (rolling)

3. **Data Aggregation**:
   - Pre-calculate threat scores
   - Batch API calls to ESI
   - Aggregate kills by system/time

## Security Considerations

1. **Data Isolation**:
   - Corporation-level data separation
   - Role-based access control
   - Audit logging for sensitive data

2. **OpSec Features**:
   - Optional pilot name hiding
   - Delayed intel for non-corp
   - Scrubbed export options

3. **Anti-Gaming**:
   - Detect intel feeding
   - Flag suspicious queries
   - Rate limiting by user

## Success Metrics

1. **Performance KPIs**:
   - Chain update latency <1s
   - 99.9% uptime during ops
   - Support 100+ concurrent chains

2. **User Satisfaction**:
   - 90% accuracy on threat assessment
   - 80% bait detection success
   - <30s to assess new chain

3. **Adoption Metrics**:
   - 100+ WH corps in 3 months
   - 80% DAU during prime time
   - 95% retention after 1 month

---

*This specification guides the implementation of wormhole-specific features that make EVE DMV the essential tool for J-space corporations.*

*Last updated: 2025-06-29*