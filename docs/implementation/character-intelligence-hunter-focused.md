# Character Intelligence: Hunter's Perspective

## Overview
Designed to answer the key question: **"Should I engage this target?"**

## Critical Hunter Intelligence

### 1. **Ship Profile & Fits**
#### Most Flown Ships (Last 90 days)
```
Ship               | Times Flown | Typical Fit Type    | Avg Friends | Success Rate
-------------------|-------------|--------------------:|------------:|-------------
Loki               | 47          | HAM Shield         | 3-5         | 78%
Proteus            | 23          | Blaster Armor      | Solo        | 65%
Hecate             | 19          | Rail Kite          | 2-3         | 84%
Sabre              | 12          | Standard Bubble    | 5-15        | 92%
```

#### Common Fit Detection
- **Loki Fit Profile**: 
  - Weapons: Heavy Assault Missiles (87%), Autocannons (13%)
  - Tank: Shield (92%), Armor (8%)  
  - Utility: Webs (100%), Scram (89%), Neut (45%)
  - Subsystems: Most common configuration
  - **Engagement Profile**: Brawler, 20-30km optimal

### 2. **Gang Composition Analysis**
#### Typical Fleet Size
```
Solo:        ████████░░░░░░░░ 23%
2-5:         ████████████████ 45%  ⚠️ Small gang specialist
6-15:        ████████░░░░░░░░ 22%
16+:         ████░░░░░░░░░░░░ 10%
```

#### Frequent Wingmen (Last 30 days)
```
Pilot Name         | Corp [TICKER] | Times Together | Ships They Bring
-------------------|---------------|---------------:|------------------
xXKillerXx         | Same Corp     | 34             | Deacon, Guardian
SpaceViking        | Blue Corp     | 28             | Sabre, Stiletto
CynoAlt420         | Same Alliance | 15             | Rapier ⚠️
```

#### Corporate Cooperation
- **Blues Often Present**: 73% of kills have alliance members
- **Batphone Probability**: Medium (has called 10+ help before)
- **Common Support**: Logi (45%), Tackle (67%), Recon (23%)

### 3. **Operational Patterns**
#### Active Zones (Heat Map)
```
System          | Activity | Time Pattern      | Notes
----------------|----------|-------------------|------------------
Amamake         | ████████ | 18:00-22:00 EVE  | Home system
Auga            | ██████░░ | Weekends         | Roaming
Tama            | ████░░░░ | Random           | Gate camps
```

#### Hunting Grounds
- **Preferred Space**: Lowsec (78%), Nullsec (19%), Highsec (3%)
- **Engagement Range**: 0-3 jumps from home (82%)
- **Site Preferences**: Gates (45%), Stations (30%), Belts (15%), Anoms (10%)

### 4. **Target Selection Profile**
#### What They Kill
```
Target Type        | Frequency | Avg Gang Size | Success Rate
-------------------|-----------|---------------|-------------
T1 Cruisers        | ████████  | Solo-2        | 92%
Faction Frigates   | ██████░░  | 2-3           | 78%
T2 Cruisers        | ████░░░░  | 3-5           | 65%
Battleships        | ██░░░░░░  | 5+            | 45%
Capitals           | ░░░░░░░░  | 15+           | 100%
```

#### Engagement Decision Patterns
- **Aggression Index**: 7.5/10 (Likely to engage similar numbers)
- **Bait Resistance**: Low (Takes bait 30% of time)
- **Disengage Success**: 45% (Commits to fights)

### 5. **Weaknesses & Exploitable Patterns**

#### Behavioral Weaknesses
- **⚠️ Predictable Routes**: Uses same 3 systems for roaming
- **⚠️ Time Pattern**: Most active 20:00-22:00 EVE time
- **⚠️ Overconfidence**: Engages outnumbered when in Loki
- **⚠️ Poor Intel**: Rarely has scout, relies on d-scan

#### Technical Weaknesses  
- **Capacitor Pressure**: Dies to neuts (3 recent losses)
- **Range Control**: Struggles against kiters
- **Damage Type**: Shield fits weak to EM/Thermal
- **Common Mistakes**: Forgets drones, cap booster management

### 6. **Cyno & Escalation Risk**
```
Escalation Indicators:
├─ Has Used Cynos: Yes (3 times in last 60 days)
├─ Capital Alt Suspected: No capital losses/kills
├─ Batphone History: Called 10+ once when losing Loki
└─ Risk Assessment: MEDIUM - May call backup if losing
```

### 7. **Recent Activity Analysis**
#### Last 7 Days
- **Activity Level**: ██████░░░░ Above average
- **Ships Lost**: Hecate (Friday, 15M), Stiletto (Sunday, 45M)
- **Notable Kills**: Orthrus (450M), Gila (380M)
- **Pattern Change**: ⚠️ Flying cheaper ships after losses

## Hunter's Quick Decision Matrix

```
ENGAGE IF:
✓ You have neut pressure (their weakness)
✓ You can kite beyond 30km
✓ It's before 20:00 EVE (less backup)
✓ They're more than 3 jumps from Amamake

AVOID IF:
✗ They have 2+ blues in local
✗ You see xXKillerXx (logi alt)
✗ They're in a Sabre (92% success rate)
✗ Multiple neut ships in your gang
```

## Implementation Data Model

### Key Aggregations Needed
1. **Ship-Fit Combinations**: Track modules used together
2. **Gang Composition**: Who flies with whom, in what ships
3. **Geographic Patterns**: Systems, times, routes
4. **Engagement Outcomes**: What worked, what didn't
5. **Loss Analysis**: How they die, to what

### Real-time Indicators
- Current system location (via ESI)
- Online status
- Recent losses (might be reshipping)
- Local count analysis

This hunter-focused design provides immediate tactical value for making engagement decisions.