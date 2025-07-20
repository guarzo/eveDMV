# Sprint 20: Battle Analysis Completion

**Duration**: 2 weeks  
**Start Date**: TBD  
**End Date**: TBD  
**Sprint Goal**: Transform battle detection into comprehensive battle intelligence with real analysis  

### 🚨 CLEAN CODEBASE COMMITMENT
**This sprint adheres to the Clean Codebase Vision:**
- ✅ NO placeholder implementations
- ✅ NO functions returning empty data as stubs
- ✅ NO hardcoded "magic" numbers
- ✅ NO random data generation for "analysis"
- ✅ ALL features query real data or don't exist

**Philosophy**: "If it returns mock data, it's not done. If it's not done, delete it."

---

## 🎯 Sprint Objective

### Primary Goal
Complete the battle analysis implementation by replacing all placeholder returns with real algorithms that analyze the already-working battle detection data.

### Success Criteria
- [ ] Battle phases identified from kill timing patterns
- [ ] Intensity curves calculated from kills-per-minute
- [ ] Participant flow tracked (joiners/leavers)
- [ ] Doctrine usage detected from ship compositions
- [ ] EWAR presence identified from ship types
- [ ] Side determination uses real logic (not hash)

### Explicitly Out of Scope
- Machine learning predictions
- Integration with external battle reports
- Advanced fleet commander identification

---

## 📊 Sprint Backlog

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| CLEANUP-1 | Implement identify_battle_phases() | 8 | CRITICAL | Detects escalation/de-escalation |
| CLEANUP-2 | Implement calculate_intensity_curve() | 5 | CRITICAL | Returns time-series data |
| CLEANUP-3 | Implement track_participant_flow() | 5 | CRITICAL | Identifies join/leave times |
| CLEANUP-4 | Implement detect_doctrine_usage() | 8 | HIGH | Recognizes fleet compositions |
| CLEANUP-5 | Implement detect_ewar_presence() | 5 | HIGH | Uses static data for EWAR ships |
| CLEANUP-6 | Fix determine_side() logic | 5 | HIGH | Proper affiliation grouping |
| CLEANUP-7 | Implement analyze_tactical_evolution() | 5 | MEDIUM | Ship type changes over time |
| CLEANUP-8 | Remove all empty return stubs | 3 | MEDIUM | Delete or implement |
| STORY-1 | Add battle metrics dashboard | 5 | MEDIUM | Visualize analysis results |
| STORY-2 | Create battle pattern library | 3 | LOW | Common patterns reference |

### 🧹 Placeholder Cleanup Tasks (REQUIRED)
- [x] Identified 15+ functions returning empty data
- [ ] Replace all `[]` returns with real analysis
- [ ] Remove hardcoded mock data returns
- [ ] Fix side determination algorithm

**Total Points**: 52

---

## 📋 Implementation Details

### 1. Battle Phases Detection
**File**: `lib/eve_dmv/contexts/battle_analysis/domain/battle_analysis_service.ex`

**Current (Bad)**:
```elixir
def identify_battle_phases(_battle_id) do
  []
end
```

**Target (Good)**:
```elixir
def identify_battle_phases(battle_id) do
  battle_id
  |> get_battle_killmails()
  |> Enum.sort_by(& &1.occurred_at)
  |> analyze_kill_density()
  |> detect_phase_transitions()
  |> Enum.map(fn phase ->
    %{
      phase_type: phase.type, # :engagement, :escalation, :climax, :withdrawal
      start_time: phase.start_time,
      end_time: phase.end_time,
      duration_seconds: DateTime.diff(phase.end_time, phase.start_time),
      kills_in_phase: length(phase.killmails),
      dominant_side: calculate_dominant_side(phase.killmails),
      intensity_rating: calculate_phase_intensity(phase),
      key_events: identify_key_events(phase)
    }
  end)
end

defp analyze_kill_density(killmails) do
  # Group kills into time windows (30-second buckets)
  killmails
  |> Enum.group_by(&time_bucket(&1.occurred_at, 30))
  |> Enum.map(fn {bucket, kills} ->
    %{
      time: bucket,
      kill_count: length(kills),
      isk_destroyed: Enum.sum(Enum.map(kills, & &1.total_value)),
      participants: count_unique_participants(kills)
    }
  end)
end

defp detect_phase_transitions(density_data) do
  # Identify significant changes in kill rate
  # Phase transitions when kill rate changes by >50%
  # or when there's a gap > 5 minutes
end
```

### 2. Intensity Curve Calculation

**Target Implementation**:
```elixir
def calculate_intensity_curve(battle_id, resolution_seconds \\ 60) do
  killmails = get_battle_killmails(battle_id)
  
  {start_time, end_time} = get_battle_timespan(killmails)
  
  start_time
  |> generate_time_buckets(end_time, resolution_seconds)
  |> Enum.map(fn bucket_start ->
    bucket_end = DateTime.add(bucket_start, resolution_seconds, :second)
    
    bucket_kills = Enum.filter(killmails, fn km ->
      DateTime.compare(km.occurred_at, bucket_start) != :lt &&
      DateTime.compare(km.occurred_at, bucket_end) == :lt
    end)
    
    %{
      timestamp: bucket_start,
      kills_per_minute: length(bucket_kills) * (60 / resolution_seconds),
      isk_destroyed_per_minute: calculate_isk_rate(bucket_kills, resolution_seconds),
      unique_pilots: count_unique_pilots(bucket_kills),
      ship_classes_destroyed: categorize_destroyed_ships(bucket_kills),
      intensity_score: calculate_intensity_score(bucket_kills)
    }
  end)
end
```

### 3. Participant Flow Tracking

**Target Implementation**:
```elixir
def track_participant_flow(battle_id) do
  killmails = get_battle_killmails(battle_id) |> Enum.sort_by(& &1.occurred_at)
  
  all_participants = extract_all_participants(killmails)
  
  participant_timeline = Enum.reduce(killmails, %{}, fn km, acc ->
    km.attackers
    |> Enum.each(fn attacker ->
      Map.update(acc, attacker.character_id, 
        %{first_seen: km.occurred_at, last_seen: km.occurred_at},
        fn existing -> %{existing | last_seen: km.occurred_at} end)
    end)
    
    # Also track victim as leaving
    Map.update(acc, km.victim.character_id,
      %{first_seen: km.occurred_at, last_seen: km.occurred_at, killed_at: km.occurred_at},
      fn existing -> %{existing | killed_at: km.occurred_at} end)
  end)
  
  %{
    joiners: identify_late_joiners(participant_timeline, battle_start),
    leavers: identify_early_leavers(participant_timeline, battle_end),
    reinforcement_waves: detect_reinforcement_patterns(participant_timeline),
    participation_duration: calculate_avg_participation_time(participant_timeline)
  }
end
```

### 4. Doctrine Detection

**Target Implementation**:
```elixir
def detect_doctrine_usage(battle_id) do
  battle = get_battle_with_participants(battle_id)
  
  battle.participants
  |> Enum.group_by(& &1.corporation_id)
  |> Enum.map(fn {corp_id, pilots} ->
    ship_composition = analyze_ship_composition(pilots)
    
    %{
      corporation_id: corp_id,
      detected_doctrines: match_known_doctrines(ship_composition),
      composition_summary: ship_composition,
      doctrine_adherence: calculate_doctrine_adherence(ship_composition),
      key_ships: identify_doctrine_key_ships(pilots),
      support_ratio: calculate_support_ratio(ship_composition)
    }
  end)
  |> Enum.reject(&Enum.empty?(&1.detected_doctrines))
end

defp match_known_doctrines(composition) do
  # Match against known EVE doctrines
  known_doctrines = [
    %{name: "Armor HACs", required: [:zealot, :sacrilege], optional: [:guardian, :devoter]},
    %{name: "Shield Rush", required: [:caracal, :scythe], optional: [:sabre, :stiletto]},
    %{name: "Bombers", required: [:stealth_bomber], min_count: 5},
    # ... more doctrines
  ]
  
  Enum.filter(known_doctrines, &doctrine_matches?(&1, composition))
end
```

### 5. EWAR Detection

**Target Implementation**:
```elixir
def detect_ewar_presence(battle_id) do
  participants = get_battle_participants(battle_id)
  
  ewar_ships = participants
  |> Enum.filter(&is_ewar_ship?(&1.ship_type_id))
  |> Enum.group_by(& &1.ship_type_id)
  
  if Enum.empty?(ewar_ships) do
    false
  else
    %{
      ewar_present: true,
      ewar_types: categorize_ewar_types(ewar_ships),
      ewar_count: length(ewar_ships),
      ewar_percentage: length(ewar_ships) / length(participants) * 100,
      primary_ewar_type: identify_primary_ewar_type(ewar_ships),
      effectiveness_estimate: estimate_ewar_effectiveness(ewar_ships, participants)
    }
  end
end

defp is_ewar_ship?(ship_type_id) do
  ship = StaticData.get_type(ship_type_id)
  
  # Check ship bonuses and role
  ship.group_id in @ewar_ship_groups or
  String.contains?(ship.name, ["Blackbird", "Falcon", "Rook", "Widow", "Griffin", 
                               "Kitsune", "Celestis", "Arazu", "Lachesis", "Maulus"])
end
```

### 6. Side Determination Fix

**Current (Bad)**:
```elixir
defp determine_side(participant, _battle_context) do
  # Simple hash-based assignment
  if rem(:erlang.phash2(participant.character_id), 2) == 0, do: :side_a, else: :side_b
end
```

**Target (Good)**:
```elixir
defp determine_side(participant, battle_context) do
  # Group by corporation/alliance affiliation
  affiliations = battle_context.affiliations
  
  cond do
    # Check alliance first
    participant.alliance_id && affiliations.alliance_groups[participant.alliance_id] ->
      affiliations.alliance_groups[participant.alliance_id]
      
    # Then corporation
    affiliations.corp_groups[participant.corporation_id] ->
      affiliations.corp_groups[participant.corporation_id]
      
    # Then check who they're shooting
    true ->
      determine_by_engagement_pattern(participant, battle_context)
  end
end

defp determine_by_engagement_pattern(participant, battle_context) do
  # Analyze who this pilot shot at and who shot them
  # Group with pilots they fought alongside
end
```

---

## 🔍 Validation Checklist

### Algorithm Validation
- [ ] Phase detection identifies clear battle stages
- [ ] Intensity curves show realistic patterns
- [ ] Participant flow matches killmail timeline
- [ ] Doctrine detection recognizes common fleets
- [ ] EWAR detection uses real ship data
- [ ] Sides determined by actual affiliations

### Integration Testing
1. **Battle Analysis Page**
   - Timeline shows phases with colors
   - Intensity graph displays properly
   - Participant flow animations work
   - Doctrine tags appear correctly

2. **Performance Testing**
   - Analysis completes in < 2s for 100 kill battle
   - Caching prevents re-analysis
   - Large battles (500+ kills) handled

---

## 🚀 Next Sprint Preview

**Sprint 21: Fleet Operations Cleanup**
- Replace hardcoded DPS values
- Implement real role detection
- Fix ship valuation
- Complete EWAR analysis

This sprint transforms our basic battle detection into rich tactical intelligence!