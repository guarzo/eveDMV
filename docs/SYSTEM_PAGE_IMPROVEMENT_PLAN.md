# System Page Improvement Plan

## Current Issues Analysis

Based on the screenshot review of `/system/31001338` (J100001 wormhole system):

### 1. ISK Values Display Issues

**Problem:** All ISK values in "Recent Kills" section show "0.0 ISK"

**Root Cause Analysis:**
- The `total_value` field from `killmails_raw` table might be NULL or 0 for these killmails
- Looking at `system_live.ex:479`: `total_value: total_value || Decimal.new(0)` - handles NULL but not if the value was never populated
- The killmail ingestion pipeline may not be extracting/storing the `total_value` correctly from the raw killmail data

**Investigation Needed:**
```sql
-- Check if total_value is actually populated for recent kills
SELECT killmail_id, total_value, raw_data->'zkb'->>'totalValue' as zkb_value
FROM killmails_raw
WHERE solar_system_id = 31001338
ORDER BY killmail_time DESC
LIMIT 10;
```

**Fix:** If `total_value` is NULL but available in `raw_data`, update the query in `get_recent_kills/1` to:
```elixir
COALESCE(k.total_value, (k.raw_data->'zkb'->>'totalValue')::numeric, 0) as total_value
```

### 2. Danger Assessment "Average Kill Value" Always Shows 0.0 ISK

**Problem:** Line 363 in `system_live.ex` hardcodes this value:
```elixir
# Not available in current schema
recent_avg_value: 0.0
```

**Fix:** Calculate the actual average from the query:
```sql
SELECT
  ...
  AVG(k.total_value) as avg_kill_value
FROM killmails_raw k
...
```

### 3. Activity Distribution (24h) - Excessive Vertical Space

**Current State:** Displays all 24 hours in a vertical list, taking ~600px of vertical space even when most hours have 0 activity.

**Problems:**
- Wastes screen real estate
- Difficult to quickly see activity patterns
- Each row is ~25px height × 24 = 600px

**Proposed Solutions:**

#### Option A: Compact Horizontal Heatmap (Recommended)
```
Activity Distribution (24h)
┌────────────────────────────────────────────────────┐
│ 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15... │
│ ░░ ░░ ░░ ░░ ░░ ▓▓ ▓▓ ▓▓ ██ ██ ▓▓ ░░ ░░ ...       │
└────────────────────────────────────────────────────┘
Peak: 16:00 EVE (USTZ) • 15 kills
```
- Single row with 24 colored cells
- Color intensity based on activity percentage
- Hover for exact count
- Total height: ~80px

#### Option B: Grouped Time Slots
```
Activity by Time Zone
┌──────────────┬──────────────┬──────────────┐
│ AUTZ (00-06) │ EUTZ (06-14) │ USTZ (14-22) │
│ ▓▓▓░░░       │ ████████     │ ████████████ │
│ 3 kills      │ 12 kills     │ 28 kills     │
└──────────────┴──────────────┴──────────────┘
```

#### Option C: Only Show Active Hours
- Filter to hours with activity > 0
- Collapse zero-activity hours into "Other hours: 0 kills"

### 4. Quick Overview Panel - Wasted Space

**Current State:**
- Right column shows sparse "Quick Overview" with 4 stats
- Large empty area with placeholder text "Click on Total Kills, Pilots, or Corps..."
- Takes 50% of horizontal space for minimal content

**Proposed Redesign:**

Move Quick Overview stats into the header area or merge with other sections:
```
┌─────────────────────────────────────────────────────────┐
│ J100001 [WORMHOLE]                    Danger: 31 LOW    │
│ Primacy > A-RRRR                                        │
│ Primary TZ: USTZ • Peak: 16:00 EVE                     │
├─────────────────────────────────────────────────────────┤
│ Stats Cards (existing)                                  │
├─────────────────────────────────────────────────────────┤
│ Recent Kills (full width)                               │
├─────────────────────────────────────────────────────────┤
│ Activity Heatmap (compact) │ Active Corps & Alliances  │
├────────────────────────────┴────────────────────────────┤
│ Battle Activity (full width, if battles exist)          │
└─────────────────────────────────────────────────────────┘
```

### 5. Recent Kills Section - Good but Could Be Better

**Current State:** Shows kills but ISK values are broken

**Improvements:**
- Add total ISK destroyed in last 7 days in header
- Add victim character portraits (already has ship images)
- Truncate long corp names with ellipsis
- Add zkillboard link icon

### 6. Battle Activity Section - Empty State Too Prominent

**Problem:** When no battles detected, shows large empty space with ⚔️ emoji

**Fix:** Reduce empty state size or hide section entirely when no battles

### 7. Corporation Presence Table - Good Layout

**Status:** Works well, keep as-is

### 8. Danger Assessment Details - Redundant

**Problem:** This section repeats info already in the header (danger score) and other sections

**Fix:** Either remove or consolidate into the header danger box with expandable details

---

## Implementation Priority

### Phase 1: Data Fixes (High Priority)
1. [ ] Fix ISK value display - investigate why `total_value` is NULL/0
2. [ ] Calculate actual average kill value for danger assessment
3. [ ] Ensure killmail ingestion properly extracts `total_value`

### Phase 2: Layout Improvements (Medium Priority)
4. [ ] Implement compact horizontal activity heatmap
5. [ ] Remove or repurpose the Quick Overview panel
6. [ ] Reduce empty state sizes for sections with no data

### Phase 3: UX Enhancements (Lower Priority)
7. [ ] Add victim portraits to recent kills
8. [ ] Add zkillboard external links
9. [ ] Consolidate danger assessment info

---

## Detailed Code Changes

### Fix 1: ISK Value in Recent Kills

In `lib/eve_dmv_web/live/system_live.ex`, update the `get_recent_kills/1` query:

```elixir
kills_query = """
SELECT
  k.killmail_id,
  k.killmail_time,
  k.victim_character_id,
  k.victim_ship_type_id,
  COALESCE(k.total_value, (k.raw_data->'zkb'->>'totalValue')::numeric, 0) as total_value,
  k.attacker_count,
  t.type_name as ship_name,
  t.group_name as ship_group,
  COALESCE(k.raw_data->'victim'->>'character_name', 'Unknown Pilot') as victim_name,
  COALESCE(k.raw_data->'victim'->>'corporation_name', 'Unknown Corp') as corporation_name
FROM killmails_raw k
LEFT JOIN eve_item_types t ON k.victim_ship_type_id = t.type_id
WHERE k.solar_system_id = $1
  AND k.killmail_time >= $2
ORDER BY k.killmail_time DESC
LIMIT 20
"""
```

### Fix 2: Average Kill Value

In `calculate_danger_assessment/1`, update the query:

```elixir
danger_query = """
SELECT
  COUNT(CASE WHEN k.killmail_time >= $2 THEN 1 END) as recent_kills,
  COUNT(CASE WHEN k.killmail_time >= $3 THEN 1 END) as total_kills,
  COUNT(DISTINCT CASE WHEN k.killmail_time >= $2 THEN p.corporation_id END) as recent_hostile_corps,
  COUNT(DISTINCT CASE WHEN k.killmail_time >= $2 THEN DATE(k.killmail_time) END) as recent_active_days,
  COALESCE(AVG(CASE WHEN k.killmail_time >= $2 THEN
    COALESCE(k.total_value, (k.raw_data->'zkb'->>'totalValue')::numeric)
  END), 0) as recent_avg_value
FROM killmails_raw k
JOIN participants p ON k.killmail_id = p.killmail_id
WHERE k.solar_system_id = $1
  AND k.killmail_time >= $3
  AND p.final_blow = true
"""
```

Then update the result handling:
```elixir
{:ok, %{rows: [[recent_kills, total_kills, hostile_corps, active_days, avg_value]]}} ->
  # ...
  {:ok, %{
    # ...
    recent_avg_value: avg_value || 0.0
  }}
```

### Fix 3: Compact Activity Heatmap

Replace the 24-row vertical list with a horizontal heatmap component:

```heex
<div class="bg-gray-800 border border-gray-700 rounded-lg p-6">
  <h3 class="text-lg font-medium text-white mb-4">Activity Distribution (24h)</h3>

  <!-- Compact heatmap -->
  <div class="flex items-center space-x-1 mb-4">
    <%= for hour_data <- @system_data.activity_heatmap do %>
      <div
        class="group relative flex-1"
        title={"#{String.pad_leading(to_string(hour_data.hour), 2, "0")}:00 - #{hour_data.count} kills"}
      >
        <div
          class={[
            "h-8 rounded transition-all cursor-pointer",
            cond do
              hour_data.percentage >= 80 -> "bg-red-500"
              hour_data.percentage >= 60 -> "bg-orange-500"
              hour_data.percentage >= 40 -> "bg-yellow-500"
              hour_data.percentage >= 20 -> "bg-blue-500"
              hour_data.percentage > 0 -> "bg-blue-700"
              true -> "bg-gray-700"
            end
          ]}
        ></div>
        <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-2 py-1 bg-gray-900 rounded text-xs text-white opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-10">
          <%= String.pad_leading(to_string(hour_data.hour), 2, "0") %>:00 - <%= hour_data.count %> kills
        </div>
      </div>
    <% end %>
  </div>

  <!-- Hour labels -->
  <div class="flex justify-between text-xs text-gray-500 px-1">
    <span>00:00</span>
    <span>06:00</span>
    <span>12:00</span>
    <span>18:00</span>
    <span>23:00</span>
  </div>

  <!-- Peak activity summary -->
  <div class="mt-4 pt-4 border-t border-gray-700 text-sm text-gray-400">
    Peak: <span class="text-white font-medium"><%= String.pad_leading(to_string(@system_data.peak_activity_hour), 2, "0") %>:00 EVE</span>
    (<%= @system_data.primary_timezone %>)
    •
    <%= Enum.sum(Enum.map(@system_data.activity_heatmap, & &1.count)) %> total kills (30d)
  </div>
</div>
```

---

## Success Metrics

After implementation:
- [x] ISK values display correctly for kills with value data
- [x] Average kill value shows actual calculated value
- [x] Activity heatmap takes <100px vertical space (vs ~600px now)
- [x] No large empty sections when data is sparse
- [x] Page provides actionable intel at a glance

---

## Implementation Log

### Completed Fixes (2026-01-02)

#### 1. Corporation Page Loading Crash
**Issue:** Clicking on a corporation link caused `KeyError: key :corp_info not found`
**Root Cause:** Template rendered content before async data loading completed
**Fix:** Added loading state check at start of template in `corporation_live.html.heex`
```heex
<%= if @loading do %>
  <div class="flex flex-col items-center justify-center py-20">
    <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mb-4"></div>
    <p class="text-gray-400">Loading corporation data...</p>
  </div>
<% else %>
  ... rest of template
<% end %>
```

#### 2. Decimal.to_float Error in Corporation Queries
**Issue:** `FunctionClauseError: no function clause matching in Decimal.to_float/1` when `isk_destroyed` was an integer 0
**Root Cause:** `isk_destroyed || 0` returns integer when nil, but `Decimal.to_float/1` only accepts `%Decimal{}`
**Fix:** Added `safe_decimal_to_float/1` helper in `corporation_queries.ex`

#### 3. ISK Values Showing 0.0 ISK
**Issue:** All kills showed "0.0 ISK" in Recent Kills section
**Root Cause:** `total_value` column was NULL in database; value available in `raw_data->'zkb'->>'totalValue'`
**Fix:** Updated query in `system_live.ex:get_recent_kills/1`:
```sql
COALESCE(k.total_value, (k.raw_data->'zkb'->>'totalValue')::numeric, 0) as total_value
```

#### 4. Average Kill Value Always 0.0 ISK
**Issue:** Danger Assessment Details showed hardcoded 0.0 ISK
**Root Cause:** Line 363 had `recent_avg_value: 0.0` hardcoded
**Fix:** Added AVG calculation to danger query:
```sql
COALESCE(AVG(CASE WHEN k.killmail_time >= $2 THEN
  COALESCE(k.total_value, (k.raw_data->'zkb'->>'totalValue')::numeric)
END), 0) as recent_avg_value
```

#### 5. Activity Heatmap Vertical Space
**Issue:** 24-row vertical list took ~600px of vertical space
**Fix:** Replaced with compact horizontal bar chart (~80px total):
- Vertical bars with color intensity based on activity
- Tooltip on hover showing exact kill count
- Summary stats showing peak hour and total kills

---

## Notes

- System J100001 is a wormhole (class J), explaining why some data might be sparse
- The page loads correctly now after the ArithmeticError fix
- Consider adding caching TTL indicators so users know data freshness
