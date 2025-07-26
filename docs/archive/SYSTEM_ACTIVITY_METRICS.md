# System Activity Metrics Implementation

## Overview
The System Activity Metrics feature provides comprehensive analytics for solar system activity patterns, helping users understand PvP hotspots, identify emerging threats, and analyze regional activity trends.

## Features Implemented

### 1. System Activity Analytics Service
- **Comprehensive system metrics** including kill counts, ISK destroyed, unique participants
- **Activity pattern analysis** with hourly and daily breakdowns
- **Danger rating calculation** based on kill frequency, ship values, and capital activity
- **Alliance/corporation activity tracking** showing most active groups per system
- **Ship class distribution analysis** revealing combat patterns
- **Escalation detection** identifying sudden spikes in activity or capital engagement

### 2. Multi-View Analytics Dashboard
- **Overview Mode**: High-level activity summary with current hotspots
- **System Detail Mode**: Deep dive into individual system metrics
- **Regional Mode**: Comparative analysis across multiple systems
- **Trends Mode**: Activity trends over time (framework ready)
- **Heatmap Mode**: Visual activity patterns (framework ready)

### 3. Real-time Activity Monitoring
- **Timeframe flexibility**: 24 hours, 7 days, 30 days, 90 days
- **Live data updates** via Phoenix PubSub integration
- **Interactive system selection** for detailed analysis
- **Responsive danger rating** that updates with new activity

## Technical Implementation

### SystemActivityMetrics Service
```elixir
defmodule EveDmv.Analytics.SystemActivityMetrics do
  # Core metrics calculation
  def get_system_metrics(system_id, timeframe) do
    %{
      # Basic metrics
      total_kills: count,
      total_isk_destroyed: isk_amount,
      unique_characters: count,
      
      # Activity patterns  
      hourly_activity: hourly_breakdown,
      daily_activity: daily_breakdown,
      activity_trends: trend_analysis,
      
      # Combat analysis
      ship_class_distribution: ship_breakdown,
      top_alliances: alliance_activity,
      danger_rating: danger_analysis,
      recent_escalations: escalation_events
    }
  end
end
```

### Danger Rating Algorithm
The danger rating uses multiple factors:
- **Kill Frequency** (40 points max): kills per day × 10
- **Ship Value** (30 points max): average ship value / 100M ISK × 20  
- **Capital Activity** (30 points max): capital kills × 5

Rating Scale:
- **Safe** (0-19): Low activity, cheap ships
- **Low Risk** (20-39): Some activity, moderate ships
- **Moderate** (40-59): Regular activity, mixed ships
- **High Risk** (60-79): High activity, expensive ships
- **Extreme** (80-100): Intense activity, capitals involved

### Activity Trend Analysis
```elixir
defp calculate_activity_trends(killmails) do
  daily_activity = calculate_daily_activity(killmails)
  recent_avg = calculate_recent_average(daily_activity, 3)
  older_avg = calculate_older_average(daily_activity, 3)
  
  change_percent = ((recent_avg - older_avg) / older_avg) * 100
  
  trend = cond do
    change_percent > 20 -> :increasing
    change_percent < -20 -> :decreasing 
    true -> :stable
  end
  
  %{trend: trend, change_percent: change_percent, confidence: confidence}
end
```

### Escalation Detection
Automatically detects:
- **Kill frequency spikes**: Activity doubling in 24 hours
- **Capital escalation**: Capital ships appearing in recent activity
- **High-value targets**: Expensive ships being destroyed

## User Interface

### Navigation
- Access via `/system-activity` route (requires authentication)
- View mode selector: Overview | Regional | Trends | Heatmap
- Timeframe selector: 24h | 7d | 30d | 90d
- Real-time refresh capability

### Overview Dashboard
- Activity overview statistics
- Current hotspots list with activity scores
- Quick system navigation for detailed analysis

### System Detail View
- Complete system profile with security class and danger rating
- Key metrics: kills, ISK destroyed, unique pilots, activity intensity
- Ship class distribution with visual bars
- Most active alliances/corporations
- Recent escalation alerts with severity indicators
- Activity trend indicators (↗ Increasing, → Stable, ↘ Decreasing)

### Regional Analysis
- Multi-system comparison table
- Sortable by activity score, danger rating, kill count
- Last activity timestamps
- Hotspot identification

## Data Sources and Performance

### Query Optimization
- Database-level filtering with proper indexes
- Reasonable query limits (1K-10K killmails max per analysis)
- Efficient grouping and aggregation operations
- Cached name resolution for ships and systems

### Real-time Updates
- Phoenix PubSub integration for live data updates
- Automatic refresh when new killmails arrive
- Loading states and error handling

## Usage Examples

### Finding Current Hotspots
1. Visit `/system-activity`
2. Select desired timeframe (default: 7 days)
3. View "Current Hotspots" section
4. Click any system for detailed analysis

### Analyzing System Danger
1. Select a system from hotspots or regional view
2. Review danger rating and contributing factors
3. Check recent escalations section for alerts
4. Examine ship class distribution for threat types

### Regional Threat Assessment
1. Switch to "Regional" view mode
2. Sort systems by danger rating or activity score
3. Identify clusters of high-activity systems
4. Monitor last activity times for threat timing

## Benefits

### For Individual Pilots
- **Route Planning**: Avoid dangerous systems or seek PvP content
- **Market Analysis**: Identify systems with high ship turnover
- **Intel Gathering**: Monitor enemy alliance activity patterns

### For Corporations
- **Territory Assessment**: Evaluate system security for operations
- **Enemy Tracking**: Monitor hostile alliance movement patterns
- **Strategic Planning**: Identify emerging threats and opportunities

### For Alliance Leadership
- **Regional Control**: Assess territorial security across regions
- **Threat Intelligence**: Early warning of escalating conflicts
- **Resource Allocation**: Deploy forces to high-activity areas

## Future Enhancements

1. **Predictive Analytics**: Machine learning for threat prediction
2. **Visual Heatmaps**: Interactive system activity visualization
3. **Alert System**: Automated notifications for escalations
4. **Historical Comparison**: Year-over-year activity comparisons
5. **Jump Route Analysis**: Activity patterns along travel routes
6. **Fleet Movement Tracking**: Large fleet detection and tracking
7. **Sovereignty Integration**: Territory control impact on activity
8. **Market Integration**: Correlation with market activity