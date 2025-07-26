# Enhanced Battle Phase Analysis Implementation

## Overview
The battle phase analysis system has been enhanced to identify multiple distinct phases within a battle based on various factors including time gaps, kill intensity changes, ship type transitions, and geographic movement.

## Features Implemented

### 1. Multi-Phase Detection
The system now identifies multiple phases within a battle based on:
- **Time Gaps**: Gaps of >5 minutes between kills indicate a new phase
- **System Changes**: Movement to a different solar system triggers a new phase
- **Ship Class Transitions**: Escalation to capital ships or de-escalation creates phase boundaries
- **Kill Intensity Changes**: >50% change in kill rate indicates a phase transition

### 2. Enhanced Phase Types
The system now recognizes a wider variety of phase types:
- **:single_engagement** - Entire battle is one continuous high-intensity phase
- **:skirmish** - Low intensity single-phase engagement
- **:initial_engagement** - First contact phase
- **:hot_drop** - High intensity initial phase (surprise attack)
- **:escalation** - Increasing intensity, reinforcements arriving
- **:sustained_combat** - Main fighting phase with steady intensity
- **:climax** - Peak intensity period of the battle
- **:de_escalation** - Intensity dropping, one side pulling back
- **:withdrawal** - One side retreating or disengaging
- **:cleanup** - Mopping up stragglers
- **:final_push** - Last offensive before battle ends
- **:lull** - Temporary pause in fighting
- **:transitional** - Generic phase between other types

### 3. Phase Metrics
Each phase now includes comprehensive metrics:
- **Duration**: Time span of the phase
- **Kill Count**: Number of kills in the phase
- **Intensity**: Kills per minute rating and classification
- **Ship Composition**: Breakdown of ship classes involved
- **Geographic Scope**: Number of systems involved
- **Key Events**: Capital kills, high-value targets, potential FC kills
- **Dominant Side**: Which side had the upper hand

### 4. Technical Implementation

#### BattlePhaseAnalyzer Module Updates
```elixir
def identify_battle_phases(timeline) do
  # Sort timeline by timestamp
  sorted_timeline = Enum.sort_by(timeline, & &1.timestamp)
  
  # Identify phase boundaries based on multiple factors
  phase_boundaries = identify_phase_boundaries(sorted_timeline)
  
  # Split timeline into phases based on boundaries
  phases = split_into_phases(sorted_timeline, phase_boundaries)
  
  # Analyze each phase
  phases
  |> Enum.with_index(1)
  |> Enum.map(fn {phase_events, phase_number} ->
    analyze_phase(phase_events, phase_number, length(phases))
  end)
end
```

#### Phase Boundary Detection
- Time-based: Detects gaps >5 minutes between consecutive kills
- Geographic: Identifies system changes
- Ship class: Detects escalation/de-escalation patterns
- Intensity: Analyzes kill rate changes in 2-minute windows

#### Phase Analysis
Each phase is analyzed for:
- Phase type based on position and characteristics
- Kill intensity and classification
- Ship composition breakdown
- Geographic scope (single system, localized, regional, widespread)
- Key events (capital kills, high-value targets)
- Dominant side determination

## Usage Example

```elixir
timeline = [
  %{timestamp: ~U[2024-01-01 12:00:00Z], victim_ship_type_id: 620, solar_system_id: 30000142},
  %{timestamp: ~U[2024-01-01 12:01:00Z], victim_ship_type_id: 621, solar_system_id: 30000142},
  # 10 minute gap
  %{timestamp: ~U[2024-01-01 12:12:00Z], victim_ship_type_id: 25000, solar_system_id: 30000142},
  %{timestamp: ~U[2024-01-01 12:13:00Z], victim_ship_type_id: 25001, solar_system_id: 30000142}
]

phases = BattlePhaseAnalyzer.identify_battle_phases(timeline)
# Returns 2 phases: initial_engagement (subcaps) and final_push (capitals)
```

## Performance Considerations
- Phase detection is O(n) where n is the number of kills
- Boundary detection uses sliding windows for efficiency
- Ship classification uses hardcoded type IDs for speed (future: use static data)

## Future Enhancements
1. Use actual EVE static data for ship classification
2. Implement alliance/corporation-based side determination
3. Add phase transition analysis (what triggered the change)
4. Include damage/ISK efficiency per phase
5. Detect tactical patterns within phases
6. Add phase prediction based on early indicators