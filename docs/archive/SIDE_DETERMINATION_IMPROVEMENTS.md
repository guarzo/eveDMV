# Side Determination Logic Improvements

## Overview
The side determination logic has been completely rewritten to use proper alliance and corporation relationships instead of the naive modulo-based approach. The new system analyzes kill patterns, alliance/corporation affiliations, and combat relationships to accurately group participants into opposing sides.

## Previous Implementation Issues
The old implementation used a simple modulo operation:
```elixir
# Old approach - DO NOT USE
case rem(alliance_id, 2) do
  0 -> :side_a
  1 -> :side_b
end
```

This approach had several critical flaws:
- Random assignment based on ID parity
- No consideration of actual relationships
- Alliance members could be split across sides
- No analysis of who was fighting whom

## New Implementation

### SideDeterminationService
A dedicated service that provides intelligent side determination using multiple factors:

1. **Relationship Graph Analysis**
   - Builds a graph of who killed whom
   - Tracks alliance and corporation affiliations
   - Analyzes attack patterns between groups

2. **Affiliation Grouping**
   - Groups participants by alliance (highest priority)
   - Falls back to corporation grouping
   - Handles unaffiliated pilots

3. **Hostility Matrix**
   - Calculates hostility scores between groups
   - Groups that attack each other are on opposite sides
   - Groups that don't attack each other are allies

4. **Intelligent Clustering**
   - Uses hostility patterns to cluster groups into sides
   - Ensures alliance/corp members stay together
   - Handles complex multi-alliance battles

### Key Features

#### 1. Alliance-First Grouping
```elixir
def group_by_affiliations(participants) do
  participants
  |> Enum.group_by(fn participant ->
    cond do
      alliance_id && alliance_id != 0 -> {:alliance, alliance_id}
      corp_id && corp_id != 0 -> {:corporation, corp_id}
      true -> {:unaffiliated, character_id}
    end
  end)
end
```

#### 2. Hostility Analysis
```elixir
# Calculate kills between groups
kills_a_to_b = count_kills_between_groups(group_a, group_b, kills_map)
kills_b_to_a = count_kills_between_groups(group_b, group_a, kills_map)
total_hostility = kills_a_to_b + kills_b_to_a
```

#### 3. Side Assignment
- Groups with high mutual hostility → opposite sides
- Groups with low/no hostility → same side
- Unknown participants assigned based on kill patterns

### Integration Points

#### BattlePhaseAnalyzer
```elixir
def calculate_dominant_side_for_phase(phase_events, phase_data) do
  participants = extract_participants_from_events(phase_events)
  sides = SideDeterminationService.classify_participants(participants, phase_events)
  
  # Count losses by each side to determine dominance
  side_a_victims = count_victims_by_side(phase_events, sides.side_a)
  side_b_victims = count_victims_by_side(phase_events, sides.side_b)
  
  cond do
    side_a_victims == side_b_victims -> :balanced
    side_a_victims < side_b_victims -> :side_a  # Fewer losses = dominant
    true -> :side_b
  end
end
```

#### EngagementAnalyzer
```elixir
defp classify_participants_by_side(participants) do
  SideDeterminationService.classify_participants(participants, [])
end
```

## Usage Examples

### Basic Two-Alliance Battle
```elixir
participants = [
  %{character_id: 1, alliance_id: 1000, corporation_id: 100},
  %{character_id: 2, alliance_id: 1000, corporation_id: 101},
  %{character_id: 3, alliance_id: 2000, corporation_id: 200},
  %{character_id: 4, alliance_id: 2000, corporation_id: 201}
]

killmails = [
  %{victim_character_id: 1, attackers: [%{character_id: 3}, %{character_id: 4}]},
  %{victim_character_id: 3, attackers: [%{character_id: 1}, %{character_id: 2}]}
]

result = SideDeterminationService.classify_participants(participants, killmails)
# Alliance 1000 members → side_a
# Alliance 2000 members → side_b
```

### Complex Multi-Alliance Battle
```elixir
# Three alliances: A and B are allies against C
participants = [
  # Alliance A
  %{character_id: 1, alliance_id: 1000},
  %{character_id: 2, alliance_id: 1000},
  # Alliance B (allied with A)
  %{character_id: 3, alliance_id: 2000},
  %{character_id: 4, alliance_id: 2000},
  # Alliance C (fighting A and B)
  %{character_id: 5, alliance_id: 3000},
  %{character_id: 6, alliance_id: 3000}
]

killmails = [
  # A and B killing C
  %{victim_character_id: 5, attackers: [%{character_id: 1}, %{character_id: 3}]},
  %{victim_character_id: 6, attackers: [%{character_id: 2}, %{character_id: 4}]},
  # C killing A and B
  %{victim_character_id: 1, attackers: [%{character_id: 5}]},
  %{victim_character_id: 3, attackers: [%{character_id: 6}]}
]

result = SideDeterminationService.classify_participants(participants, killmails)
# Alliances 1000 & 2000 → side_a (no kills between them)
# Alliance 3000 → side_b (fighting both 1000 & 2000)
```

## Benefits

1. **Accurate Grouping**: Alliance and corporation members stay together
2. **Relationship-Based**: Uses actual combat data, not arbitrary IDs
3. **Flexible**: Handles complex multi-party battles
4. **Deterministic**: Same input always produces same output
5. **Extensible**: Can add additional factors (standings, previous battles)

## Future Enhancements

1. **Standing Integration**: Use EVE standings data when available
2. **Historical Analysis**: Consider previous battles between groups
3. **Fleet Detection**: Identify formal fleet structures
4. **Neutral Handling**: Better handling of third parties
5. **Performance Optimization**: Cache alliance/corp relationships
6. **Machine Learning**: Train models on known battle outcomes