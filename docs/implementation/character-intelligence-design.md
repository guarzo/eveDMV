# Character Intelligence Design

## Overview
The character intelligence page should provide actionable insights for:
- **Recruiters**: Assess pilot quality and fit
- **Fleet Commanders**: Understand pilot capabilities
- **Hunters**: Identify patterns and weaknesses

## Core Intelligence Elements

### 1. **Combat Performance Metrics**
- **K/D Ratio**: Overall and by ship class
- **ISK Efficiency**: ISK destroyed vs ISK lost
- **Solo vs Fleet**: Percentage of solo kills
- **Average Gang Size**: Typical fleet size they fly in
- **Kill Participation**: Final blows vs assists ratio
- **Activity Heat**: Kills/losses over time periods

### 2. **Ship & Fitting Analysis**
- **Most Used Ships**: Top 10 by frequency with success rates
- **Ship Class Distribution**: Pie chart (Frigates, Cruisers, BS, Capitals)
- **Preferred Engagement Range**: Based on weapon systems used
- **Fitting Patterns**: Common module combinations
- **ISK Risk Profile**: Average ship value flown
- **Capital Usage**: If they fly capitals, which types

### 3. **Geographic Intelligence**
- **Active Regions**: Where they operate most
- **Home System**: Most frequent location
- **Roaming Range**: How far they travel for PvP
- **Security Preference**: Highsec/Lowsec/Nullsec/WH distribution
- **Time Zone Activity**: Heat map of kills by hour

### 4. **Social Intelligence**
- **Corporation History**: Timeline with join/leave dates
- **Known Associates**: Frequent fleet members
- **Primary FCs**: Who they fly under
- **Enemy Patterns**: Who they fight most
- **Blue History**: Previous alliance affiliations

### 5. **Behavioral Patterns**
- **Aggression Index**: Likelihood to engage
- **Risk Tolerance**: Ship value vs security status
- **Hunter vs Hunted**: Aggressor percentage
- **Bait Detection**: Suspicious loss patterns
- **Cyno Probability**: Likelihood of hot drops

### 6. **Performance Trends**
- **Skill Evolution**: Performance improvement over time
- **Monthly Activity**: Kills/losses trend chart
- **ISK Efficiency Trend**: Getting better or worse?
- **Ship Progression**: Evolution from T1 to T2/T3
- **Recent Performance**: Last 30/60/90 days

### 7. **Special Indicators**
- **AT Participant**: Alliance Tournament history
- **Known FC**: Identified fleet commander
- **Suspected Alt**: Behavioral pattern matching
- **Inactive Warning**: If no recent activity
- **Anomaly Alerts**: Unusual patterns (e.g., sudden wealth)

## Visual Design Elements

### Header Section
```
[Avatar] Character Name
         Corporation [TICKER] | Alliance <ALLY>
         Security Status: -5.0 ⚔️
         
         ⭐ 92% ISK Efficiency | 3.2 K/D | 1,847 Kills
```

### Quick Stats Grid
```
┌─────────────┬─────────────┬─────────────┬─────────────┐
│ Total Kills │ Total Losses│ ISK Destroyed│ ISK Lost    │
│    1,847    │     573     │   487.3B    │   42.1B     │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ Solo Kills  │ Final Blows │ Top Ship    │ Danger Rating│
│   23% (424) │  31% (573)  │ Loki (187)  │    ★★★★☆    │
└─────────────┴─────────────┴─────────────┴─────────────┘
```

### Activity Timeline
- Interactive graph showing kills/losses over time
- Hover for details on specific engagements
- Corporation change markers

### Ship Usage Sunburst
- Interactive nested circles showing ship usage
- Inner: Ship class
- Middle: Ship type
- Outer: Success rate coloring

### Geographic Heat Map
- EVE map with activity intensity
- Filter by kills/losses/all
- Time range selector

## Data Aggregation Strategy

### Real-time Calculations
- Recent activity (last 7 days)
- Current ship being flown
- Online/offline status (via ESI)

### Pre-aggregated Daily
- Performance metrics
- Ship usage statistics
- Geographic distribution
- Social connections

### Historical Snapshots
- Monthly performance summaries
- Corporation history
- Long-term trends

## Implementation Priority

### Phase 1 (MVP)
1. Basic performance metrics (K/D, ISK efficiency)
2. Ship usage statistics
3. Recent activity timeline
4. Corporation history

### Phase 2
1. Geographic intelligence
2. Social network analysis
3. Performance trends
4. Advanced metrics

### Phase 3
1. Behavioral patterns
2. Anomaly detection
3. Predictive analytics
4. Alt detection

## Technical Considerations

### Performance
- Use materialized views for complex aggregations
- Cache character pages for 10 minutes
- Background jobs for heavy calculations
- Progressive loading for better UX

### Data Sources
- Primary: Our killmail database
- Secondary: EVE ESI for current info
- Tertiary: zKillboard API for historical data

### Privacy/Ethics
- Only show public killmail data
- No doxxing or real-world info
- Respect EVE's EULA and privacy rules
- Allow pilots to claim and annotate their profiles

This design provides deep insights while remaining ethical and useful for legitimate gameplay purposes.