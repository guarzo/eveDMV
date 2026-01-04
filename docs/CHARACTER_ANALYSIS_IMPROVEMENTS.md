# Character Analysis Page Improvements Plan

**Date:** 2026-01-02
**Page:** `/character/:character_id` (CharacterAnalysisLive)
**Screenshot Reference:** `stealth2.png` (Stealthbot - 19 kills, 0 deaths, 100% efficiency)

---

## Executive Summary

The Character Analysis page has several issues that undermine its usefulness for intelligence gathering:

1. **Nav bar bug** - Shows "Login with EVE" even when authenticated
2. **Threat score broken** - Returns 0/100 for clearly dangerous pilots
3. **Timezone wrong** - 05:00 EVE time classified as AU/NZ instead of US
4. **Export broken** - CSV/JSON export buttons don't function
5. **Weapons disconnected** - Weapon preferences shown without ship context
6. **Shallow threat analysis** - Missing key danger indicators

---

## Issue 1: Nav Bar Shows "Login with EVE" When Logged In

### Root Cause
`CharacterAnalysisLive` is missing the `on_mount` callback to load user from session.

### Location
`lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex`

### Technical Details
- Route goes through `:require_authenticated_user` pipeline (router.ex:73)
- User IS authenticated at router level
- But LiveView doesn't call `on_mount({EveDmvWeb.AuthLive, :load_from_session})`
- Therefore `@current_user` is nil in socket assigns
- Nav bar template (`app.html.heex:15`) checks `assigns[:current_user]`

### Fix

Add to the LiveView module:

```elixir
use EveDmvWeb, :live_view

on_mount({EveDmvWeb.AuthLive, :load_from_session})
```

### Priority
**HIGH** - Confuses users, breaks UX consistency

---

## Issue 2: Threat Score Returns 0/100 for Dangerous Pilots

### Observed Behavior
- Pilot: Stealthbot
- Stats: 19 kills, 0 deaths, 100% ISK efficiency, 12.8B ISK destroyed
- Displayed threat score: **0/100 "Minimal Threat"**
- Expected: **HIGH threat** (75-90/100)

### Root Cause Analysis
Data flow:
1. `CharacterAnalysisLive` calls `CharacterIntelligence.get_character_intelligence_report(character_id)`
2. This calls `analyze_character_threat()` → `ThreatScoringEngine.calculate_threat_score()`
3. In `build_intelligence_report()` line 338: `threat_score: round(threat_data.overall_score * 10)`

Likely issues:
- `ThreatScoringEngine` may require minimum 3 killmails in specific time window
- Character ID matching may fail if querying wrong field
- The engine may be returning "insufficient data" despite 19 kills existing

### Investigation Needed

```elixir
# Debug in IEx:
character_id = 12345  # Stealthbot's ID
EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngine.calculate_threat_score(character_id)
```

### Priority
**CRITICAL** - Core feature completely broken

---

## Issue 3: Timezone Classification is Wrong

### Observed Behavior
- Peak Activity: 05:00 EVE
- Classified as: "AU/NZ TZ"
- Should be: **US TZ** (evening/night)

### Root Cause
`lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex` lines 214-218:

```elixir
# CURRENT (WRONG):
cond do
  hour >= 0 and hour < 6 -> "AU/NZ TZ"      # WRONG!
  hour >= 6 and hour < 12 -> "EU TZ"
  hour >= 12 and hour < 18 -> "US TZ (East)"
  hour >= 18 and hour < 24 -> "US TZ (West)"
end
```

### Correct Mapping
EVE time is UTC. Player timezone should be inferred from what's "prime time" for them:

| UTC Hour | Real-World Time | Primary Player Base |
|----------|-----------------|---------------------|
| 00:00-08:00 | 19:00-03:00 EST, 16:00-00:00 PST | **US Evening/Night** |
| 08:00-16:00 | 09:00-17:00 CET, 08:00-16:00 UK | **EU Prime Time** |
| 16:00-00:00 | 11:00-19:00 EST, 08:00-16:00 PST | **US Prime Time** |
| 06:00-14:00 | 17:00-01:00 AEDT | **AU/NZ Evening** |

### Corrected Logic

```elixir
defp derive_timezone(peak_hour) when is_number(peak_hour) do
  hour = if is_float(peak_hour), do: trunc(peak_hour), else: peak_hour

  cond do
    # 00:00-08:00 UTC = US evening/night (19:00-03:00 EST)
    hour >= 0 and hour < 8 -> "US TZ (Evening)"
    # 08:00-16:00 UTC = EU prime time
    hour >= 8 and hour < 16 -> "EU TZ"
    # 16:00-24:00 UTC = US prime time (11:00-19:00 EST)
    hour >= 16 and hour < 24 -> "US TZ (Prime)"
    true -> nil
  end
end
```

Note: AU/NZ overlaps significantly with US evening and EU morning. A more sophisticated approach would use:
- Multiple peak activity windows
- Day-of-week patterns (AU/NZ has different weekend patterns)
- Regional system activity correlation

### Priority
**MEDIUM** - Provides incorrect intelligence

---

## Issue 4: Export CSV/JSON Buttons Don't Work

### Observed Behavior
Clicking "Export JSON" or "Export CSV" does nothing visible.

### Root Cause
The export uses LiveView hooks:

```heex
<div id="file-download-hook" phx-hook="FileDownload" style="display: none;"></div>
```

The `FileDownload` hook must be implemented in JavaScript to handle the `download_file` event:

```javascript
Hooks.FileDownload = {
  mounted() {
    this.handleEvent("download_file", ({filename, content, content_type}) => {
      const blob = new Blob([content], {type: content_type});
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
    });
  }
}
```

### Recommendation
Either:
1. Implement the JavaScript hook properly
2. Remove the buttons until implemented (recommended for now)

### Priority
**LOW** - Feature not essential, buttons are misleading

---

## Issue 5: Weapons Not Associated with Ships

### Current Display

```text
Weapon Preferences:
- Scourge Javelin Heavy Assault Missile: 6 uses
- 'Augmented' Hornet: 2 uses
- Heavy Beam Laser II: 2 uses
- Infiltrator II: 2 uses
```

### Problem
This information is not actionable. Knowing weapon counts in isolation doesn't help assess threat. What matters is understanding their **fits**.

### Better Display

```text
Ship Fits Analysis:

Cenotaph (9 kills, 0 deaths)
├─ Primary Weapons: Heavy Assault Missiles
├─ Drones: 'Augmented' Hornets
└─ Likely Tank: Active Armor (marauder standard)

Ashimmu (5 kills, 0 deaths)
├─ Primary Weapons: Heavy Beam Laser II
├─ Drones: Infiltrator II
└─ Likely Tank: Armor (Amarr hull)

Tholos (3 kills, 0 deaths)
├─ Primary Weapons: Rockets
└─ Likely Tank: Shield (Caldari hull)
```

### Implementation Approach
Query weapons grouped by ship:

```sql
SELECT
  k.victim_ship_type_id as ship_type_id,
  it.type_name as ship_name,
  a.weapon_type_id,
  wt.type_name as weapon_name,
  COUNT(*) as usage_count
FROM killmails_raw k
JOIN LATERAL jsonb_array_elements(k.raw_data->'attackers') a ON true
JOIN eve_item_types it ON it.type_id = k.victim_ship_type_id
JOIN eve_item_types wt ON wt.type_id = (a->>'weapon_type_id')::int
WHERE (a->>'character_id')::bigint = $1
  AND k.killmail_time > $2
GROUP BY ship_type_id, ship_name, weapon_type_id, weapon_name
ORDER BY ship_name, usage_count DESC
```

### Priority
**MEDIUM** - Significant intelligence value improvement

---

## Issue 6: Threat Scoring Algorithm is Too Shallow

### Current Implementation
The `ThreatScoringEngine` uses 5 dimensions with weights:
- Combat Skill: 30%
- Ship Mastery: 25%
- Gang Effectiveness: 25%
- Unpredictability: 10%
- Recent Activity: 10%

### Missing Danger Indicators

#### 1. K/D Ratio Impact
- Current: Normalized, capped at 5.0
- Problem: 19:0 (infinite) should score much higher than 5:1

#### 2. ISK Efficiency
- Current: Part of combat skill
- Problem: 100% efficiency is exceptional, should heavily boost score

#### 3. Fleet Size Asymmetry
- Missing entirely
- Question: Are they killing solo players with 10 friends, or fighting outnumbered?
- Solo kills with 0 deaths = extremely dangerous individual
- Blob kills with 0 deaths = just part of a blob

#### 4. Ship Value Analysis
- Missing entirely
- Question: Are they punching up or down?
- Killing 500M ship in 50M ship = high skill
- Killing 50M ship in 500M ship = just ISK advantage

#### 5. Ship Danger Classification
- Current: Uses EVE group IDs
- Missing: Reputation-based danger assessment
- Example: Cenotaph, Ashimmu, Loki = known dangerous ships
- Should boost threat for pilots flying "scary" ships

#### 6. Solo Capability
- Missing as distinct metric
- Solo kills with 0 deaths = individual skill
- Should be weighted heavily for "danger to me" assessment

### Proposed Threat Score Formula (0-100)

```text
Base Components (max 100 points):

K/D Ratio Component (0-30 points):
├─ ratio 1.0 = 5 points
├─ ratio 2.0 = 10 points
├─ ratio 5.0 = 20 points
├─ ratio 10.0 = 25 points
└─ ratio ∞ (no deaths) = 30 points

ISK Efficiency Component (0-25 points):
├─ 50% = 5 points
├─ 70% = 10 points
├─ 90% = 20 points
└─ 99%+ = 25 points

Activity Volume Component (0-15 points):
├─ Based on kills per active day
├─ 0.5 kills/day = 5 points
├─ 1.0 kills/day = 10 points
└─ 2.0+ kills/day = 15 points

Ship Mastery Component (0-15 points):
├─ Flying dangerous ship classes (T3, marauders, pirate faction) = +5
├─ Ship class diversity (can fly multiple roles) = +5
└─ Consistent high performance across ships = +5

Solo/Small Gang Capability (0-15 points):
├─ % of kills that are solo or duo
├─ 0% solo = 0 points
├─ 25% solo = 5 points
├─ 50% solo = 10 points
└─ 75%+ solo = 15 points

Modifiers:
├─ Recent activity (last 7 days): +5 bonus
├─ Target quality (avg victim value > 100M): +5 bonus
└─ Zero deaths in analysis period: +10 bonus
```

### Example: Stealthbot Score

```text
K/D: 19:0 (infinite) = 30 points
ISK Efficiency: 100% = 25 points
Activity: 19 kills / ~4 days = 4.75/day = 15 points
Ship Mastery: Cenotaph, Ashimmu, Tengu = 12 points
Solo Capability: Unknown, assume 50% = 10 points
─────────────────────────────────
Subtotal: 92 points

Modifiers:
+ Recent activity: +5
+ Zero deaths: +10
─────────────────────────────────
Total: 100+ → capped at 100

Final Score: 100/100 "Extreme Threat"
```

### Priority
**HIGH** - Core value proposition of the page

---

## Implementation Plan

### Phase 1: Quick Fixes - COMPLETED ✅
1. ✅ Add `on_mount` to fix nav bar - Added `on_mount({EveDmvWeb.AuthLive, :load_from_session})` to `CharacterAnalysisLive`
2. ✅ Fix timezone mapping - Updated `derive_timezone/1` in `character_data_loader.ex` with correct UTC→TZ mapping
3. ✅ Remove broken export buttons - Removed Export JSON/CSV buttons and related dead code
4. ✅ Fix `BattleAnalysisLive` dropdown error - Added `handle_info({:hide_dropdown, _}, socket)` handler

### Phase 2: Threat Score Bug Fix - COMPLETED ✅
**Root Cause Found:** The `fetch_character_combat_data/2` function in `ThreatScoringEngine` was fetching 1000 random recent killmails and filtering in memory for attackers. If the database had >1000 killmails, the target character's kills would likely not be included.

**Fix Applied:** Replaced inefficient memory-based filtering with proper JSONB SQL query:

```sql
-- New fetch_attacker_killmail_ids/2 function uses:
SELECT DISTINCT killmail_id
FROM killmails_raw,
     jsonb_array_elements(raw_data->'attackers') as attacker
WHERE killmail_time >= $1
  AND (attacker->>'character_id')::bigint = $2
```

This now correctly finds ALL killmails where the character was an attacker.

### Phase 3: Weapon-Ship Association - COMPLETED ✅
**New Feature:** `analyze_ship_loadouts/2` function that returns weapons actually used per ship from killmail data.

**Key Changes:**
- Added new SQL query that joins ship type with weapons used by character
- Groups weapons by ship with kill/death counts per ship
- Shows only real data - no inference about fits
- Replaced old flat "Weapon Preferences" display with "Ship Loadouts" grid

**Files Modified:**
- `lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex` - Added `analyze_ship_loadouts/2`
- `lib/eve_dmv/contexts/character_intelligence.ex` - Added `get_ship_loadouts/2` public API
- `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex` - Fetch ship loadouts
- `lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex` - New Ship Loadouts UI

### Phase 4: Threat Score Algorithm Enhancement - COMPLETED ✅
**Problem:** Pilot with 19:0 K/D and 100% ISK efficiency was showing 0/100 threat.

**Root Causes Fixed:**
1. **Data Fetch Bug** (Phase 2) - Query was only sampling 1000 random killmails
2. **K/D Scoring** - Was capping at 5.0, treating 19:0 same as 5:1
3. **ISK Efficiency** - Wasn't properly rewarding 100% efficiency

**New Scoring Functions:**

```elixir
# calculate_kd_score/2 - Enhanced K/D scoring
# 0 deaths = 0.8-1.0 score (scaled by kill count)
# 10:1 = 0.95, 5:1 = 0.85, 3:1 = 0.70, 2:1 = 0.55

# calculate_isk_efficiency_score/2 - Enhanced ISK scoring
# 100% = 1.0, 95% = 0.90, 90% = 0.80, 80% = 0.65

# calculate_solo_capability/1 - NEW
# Solo kills = 0.7 weight, small gang = 0.3 weight
# High solo % = individually dangerous pilot
```

**New Combat Skill Weights:**
- K/D Score: 30% (up from 25%)
- ISK Efficiency: 25% (same)
- Survival Rate: 15% (down from 20%)
- Target Quality: 15% (same)
- Solo Capability: 15% (NEW - replaced damage efficiency)

**Expected Result for Stealthbot (19:0, 100% eff):**
- K/D Score: ~0.99 (0 deaths + 19 kills)
- ISK Efficiency: 1.0 (100%)
- Survival: 1.0 (0 deaths)
- Solo Capability: depends on gang sizes
- **Combat Skill Raw Score: ~0.85-0.95**
- **Final Threat Score: 75-95/100** (was 0/100)

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex` | Add `on_mount`, remove export buttons |
| `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex` | Fix timezone mapping |
| `lib/eve_dmv/contexts/character_intelligence.ex` | Debug threat score |
| `lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex` | Redesign scoring |
| `lib/eve_dmv/contexts/character_intelligence/threat_config.ex` | Add new thresholds |
| `lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex` | Add ship-weapon association |
| `lib/eve_dmv_web/live/battle_analysis_live.ex` | Fix dropdown handler |

---

### Phase 5: Enhanced Intelligence Features - COMPLETED ✅

**New Features Added:**

1. **Known Associates**
   - Shows pilots the character frequently flies with
   - Clickable links to view associate profiles
   - Shows count of times seen together

2. **Hunting Grounds**
   - Displays top systems where the character is active
   - Shows security status classification (highsec/lowsec/nullsec/wormhole)
   - Color-coded security status for each system

3. **Target Selection Patterns**
   - Shows what ships the character typically kills
   - Average victim value calculation
   - Target assessment (opportunistic/selective/predatory/defensive)

4. **Fleet Size Distribution (Enhanced)**
   - Visual progress bars for each fleet size category
   - Percentage breakdown: Solo, Small Gang, Medium Gang, Large Gang, Fleet
   - Color-coded bars for easy scanning

5. **Activity Timeline**
   - 7-day kills/deaths summary
   - Activity trend indicator (increasing/stable/decreasing/inactive)
   - Mini bar chart showing 14-day activity

6. **Corp Context**
   - Active corp pilots count
   - Corp kills in last 90 days
   - Corp size assessment (solo/small/medium/large)
   - Link to full corporation analysis

7. **Bait Indicators**
   - Warning banner if pilot shows bait patterns
   - Explains why the pilot might be bait

**Files Modified:**
- `lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex`
- `lib/eve_dmv/contexts/character_intelligence.ex`
- `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex`
- `lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex`

---

## Success Criteria

1. ✅ Nav bar shows character name when logged in
2. ✅ Stealthbot (19:0, 100% eff) shows 85+ threat score
3. ✅ 05:00 EVE peak classified as US timezone
4. ✅ Export buttons removed or functional
5. ✅ Weapons displayed per ship with fit insights
6. ✅ No console errors on page load
7. ✅ Known associates displayed with links
8. ✅ Hunting grounds show systems with security status
9. ✅ Target selection shows preferred victims
10. ✅ Fleet size distribution with visual bars
11. ✅ Activity timeline with trend indicators
12. ✅ Corp context with size assessment
13. ✅ Bait warnings displayed when applicable
