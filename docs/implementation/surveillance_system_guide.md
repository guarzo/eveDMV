# EVE DMV Surveillance System Guide

## Overview

The EVE DMV Surveillance System provides real-time monitoring and alerting for EVE Online killmail data. It allows users to create sophisticated surveillance profiles that monitor for specific events, characters, corporations, and situations within New Eden.

## Key Features

### 🎯 Profile Management
- **Hybrid Filter Builder**: Intuitive interface combining dropdowns with visual representation
- **Real-time Preview**: Test profiles against the last 1,000 killmails with live match counts
- **Chain-aware Filtering**: Integration with Wanderer for wormhole chain monitoring
- **Multiple Filter Types**: Support for character, corporation, alliance, system, ship type, ISK value, and participant count filters

### 🚨 Real-time Alerts
- **Visual Notifications**: In-browser alerts with priority-based styling
- **Audio Alerts**: Configurable sound notifications based on alert priority
- **Alert Management**: Acknowledge, resolve, and track alert history
- **Bulk Operations**: Mass acknowledge alerts with filtering

### 📊 Performance Dashboard
- **System Metrics**: Overall surveillance performance monitoring
- **Profile Analytics**: Individual profile performance and efficiency metrics
- **Optimization Recommendations**: Automated suggestions for improving profile performance
- **Alert Trends**: Time-series visualization of alert patterns

### 🔗 Wanderer Integration
- **Live Chain Data**: Real-time wormhole chain topology and inhabitant tracking
- **Chain Filters**: Monitor for events within your wormhole chain
- **SSE Integration**: Server-sent events for real-time Wanderer updates

## User Interface Components

### 1. Surveillance Profiles (`/surveillance-profiles`)

The main interface for creating and managing surveillance profiles.

#### Creating a Profile
1. Click "New Profile" button
2. Enter profile name and optional description
3. Add filters using the dropdown menu
4. Configure filter parameters
5. Review real-time preview
6. Save profile

#### Filter Types

**Character Watch**
- Monitor specific character IDs
- Tracks both victim and attacker roles
- Comma-separated ID input

**Corporation Watch**
- Monitor specific corporation IDs
- Includes member activity tracking
- Supports multiple corporations

**Alliance Watch**
- Monitor alliance-level activity
- Tracks member corporations automatically
- Alliance-wide surveillance

**System Watch**
- Monitor specific solar systems
- Tracks all activity in specified systems
- System ID based filtering

**Ship Type Watch**
- Monitor specific ship types
- Track ship usage patterns
- Ship type ID filtering

**Chain Awareness**
- Monitor wormhole chain activity
- Integration with Wanderer maps
- Multiple chain filter types:
  - In Chain: Events within your chain
  - Within X Jumps: Events near your chain
  - Chain Inhabitant: Events involving chain members
  - Entering Chain: Potential hostile activity

**ISK Value**
- Filter by killmail value
- Operators: greater than, less than, equals
- Customizable ISK thresholds

**Participant Count**
- Filter by number of participants
- Useful for identifying fleet fights
- Configurable thresholds

#### Logic Operators
- **AND**: All conditions must be met
- **OR**: Any condition can trigger the alert

### 2. Surveillance Alerts (`/surveillance-alerts`)

Real-time alert monitoring and management interface.

#### Alert Display
- **Priority Badges**: Critical, High, Medium, Low
- **State Tracking**: New, Acknowledged, Resolved
- **Quick Actions**: ACK and RESOLVE buttons
- **Alert Details**: Expandable detail view

#### Filtering Options
- Priority level filtering
- State-based filtering
- Time range selection
- Profile-specific filtering

#### Alert Management
- Individual alert acknowledgment
- Bulk acknowledge operations
- Alert resolution tracking
- Historical alert viewing

#### Sound Configuration
- Toggle audio notifications
- Priority-based sound differentiation
- Auto-acknowledge settings

### 3. Performance Dashboard (`/surveillance-dashboard`)

Comprehensive monitoring and analytics for surveillance system performance.

#### System Metrics
- **Total Profiles**: Active and inactive profile counts
- **Alert Volume**: Total alerts and alerts per hour
- **Response Time**: Average surveillance engine response time
- **System Health**: Memory usage and cache hit rates

#### Profile Performance
- **Alert Generation**: Number of alerts per profile
- **Match Rate**: Percentage of killmails matched
- **False Positive Rate**: Estimated accuracy metrics
- **Confidence Scores**: Average confidence per profile
- **Performance Score**: Composite performance rating

#### Optimization Recommendations
- Automated analysis of profile efficiency
- Suggestions for performance improvements
- Identification of problematic profiles
- System-wide optimization guidance

#### Alert Trends
- Time-series visualization of alert patterns
- Hourly breakdown of alert activity
- Trend analysis for capacity planning

## Technical Architecture

### Core Components

#### Matching Engine
- **Real-time Processing**: Sub-200ms killmail evaluation
- **Parallel Execution**: Concurrent profile matching
- **Caching**: Optimized profile and chain data caching
- **Metrics**: Performance monitoring and analytics

#### Alert Service
- **Priority Calculation**: Automatic alert prioritization
- **State Management**: Alert lifecycle tracking
- **Bulk Operations**: Efficient mass operations
- **Notification Integration**: Multi-channel notifications

#### Notification Service
- **In-app Notifications**: Real-time browser notifications
- **Email Integration**: SMTP-based email alerts (configurable)
- **Webhook Support**: External system integration
- **Rate Limiting**: Prevents notification spam

#### Wanderer Client
- **SSE Integration**: Real-time chain updates
- **Chain Topology**: Live wormhole mapping data
- **Inhabitant Tracking**: Active pilot monitoring
- **Error Handling**: Robust connection management

### Data Flow

1. **Killmail Reception**: Broadway pipeline receives killmails
2. **Profile Matching**: Matching engine evaluates against active profiles
3. **Alert Generation**: Matches trigger alert creation
4. **Notification Delivery**: Alerts distributed via configured channels
5. **UI Updates**: Real-time updates to connected browsers

### Performance Characteristics

- **Matching Speed**: <200ms per killmail across all active profiles
- **Scalability**: Supports 100+ concurrent surveillance profiles
- **Cache Efficiency**: 85%+ cache hit rate for optimal performance
- **Real-time Updates**: <1 second from killmail to notification

## Configuration

### Environment Variables

```bash
# Wanderer Integration
WANDERER_BASE_URL=https://wanderer.example.com
WANDERER_AUTH_TOKEN=your_auth_token
WANDERER_DEFAULT_MAP_SLUG=your_map_slug

# Surveillance Settings
SURVEILLANCE_PREVIEW_KILLMAIL_LIMIT=1000
SURVEILLANCE_MAX_PROFILES_PER_USER=50
SURVEILLANCE_CACHE_TTL_SECONDS=300

# Notification Settings
NOTIFICATION_RATE_LIMIT_PER_HOUR=10
NOTIFICATION_EMAIL_ENABLED=true
NOTIFICATION_WEBHOOK_ENABLED=false
```

### Profile Configuration

Profiles are stored as JSON structures with the following format:

```elixir
%{
  name: "High Value Targets",
  description: "Monitor high-value ship kills",
  enabled: true,
  criteria: %{
    type: :custom_criteria,
    logic_operator: :and,
    conditions: [
      %{
        type: :isk_value,
        operator: :greater_than,
        value: 5_000_000_000
      },
      %{
        type: :ship_type_watch,
        ship_type_ids: [23773, 23919]  # Titan ship types
      }
    ]
  },
  notification_config: %{
    in_app: %{enabled: true},
    email: %{enabled: false},
    webhook: %{enabled: false}
  }
}
```

## API Reference

### Profile Management API

#### Create Profile
```http
POST /api/v1/surveillance/profiles
Content-Type: application/json

{
  "name": "Profile Name",
  "description": "Optional description",
  "criteria": { ... },
  "enabled": true
}
```

#### Update Profile
```http
PUT /api/v1/surveillance/profiles/:id
Content-Type: application/json

{
  "name": "Updated Name",
  "enabled": false
}
```

#### List Profiles
```http
GET /api/v1/surveillance/profiles
```

#### Delete Profile
```http
DELETE /api/v1/surveillance/profiles/:id
```

### Alert Management API

#### Get Recent Alerts
```http
GET /api/v1/surveillance/alerts?limit=50&priority=critical
```

#### Update Alert State
```http
PUT /api/v1/surveillance/alerts/:id/state
Content-Type: application/json

{
  "state": "acknowledged",
  "notes": "Investigating this alert"
}
```

#### Bulk Acknowledge
```http
POST /api/v1/surveillance/alerts/bulk_acknowledge
Content-Type: application/json

{
  "criteria": {
    "priority": ["medium", "low"],
    "created_before": "2024-01-01T00:00:00Z"
  }
}
```

### Metrics API

#### System Metrics
```http
GET /api/v1/surveillance/metrics/system
```

#### Profile Metrics
```http
GET /api/v1/surveillance/metrics/profiles/:id?time_range=last_24h
```

## Best Practices

### Profile Design
1. **Start Simple**: Begin with basic filters and add complexity gradually
2. **Use Preview**: Always test profiles against recent killmails
3. **Monitor Performance**: Check profile efficiency in the dashboard
4. **Avoid Overlaps**: Don't create redundant profiles for the same targets

### Alert Management
1. **Regular Cleanup**: Acknowledge or resolve alerts promptly
2. **Tune Notifications**: Adjust sound settings to avoid alert fatigue
3. **Review Accuracy**: Use false positive feedback to improve profiles
4. **Bulk Operations**: Use bulk acknowledge for routine maintenance

### Performance Optimization
1. **Limit Conditions**: Keep profiles under 10 conditions when possible
2. **Cache Awareness**: Chain filters are more expensive than simple ID filters
3. **Monitor Trends**: Use dashboard metrics to identify performance issues
4. **Regular Review**: Disable unused or low-performing profiles

## Troubleshooting

### Common Issues

#### No Alerts Generated
- Check profile enabled status
- Verify filter criteria match expected killmails
- Review profile preview for test matches
- Check Wanderer connection for chain filters

#### Poor Performance
- Reduce number of active profiles
- Simplify complex filter conditions
- Check system metrics in dashboard
- Monitor cache hit rates

#### Wanderer Integration Issues
- Verify environment variables
- Check map slug configuration
- Review Wanderer authentication
- Monitor SSE connection status

#### Missing Notifications
- Check notification configuration
- Verify PubSub subscription
- Review rate limiting settings
- Test notification channels

### Support Resources

- **System Logs**: Check application logs for detailed error messages
- **Performance Dashboard**: Monitor system health and profile efficiency
- **Chain Status**: Verify Wanderer integration in profile interface
- **Preview Function**: Test profile logic against known killmails

## Development and Testing

### Running Tests
```bash
# Run all surveillance tests
mix test test/eve_dmv/contexts/surveillance/
mix test test/eve_dmv_web/live/surveillance_*

# Run specific test suites
mix test test/eve_dmv/contexts/surveillance/domain/matching_engine_test.exs
mix test test/eve_dmv_web/live/surveillance_profiles_live_test.exs
```

### Local Development
```bash
# Start development server
mix phx.server

# Enable surveillance pipeline
export SURVEILLANCE_ENABLED=true

# Set Wanderer configuration
export WANDERER_BASE_URL=http://localhost:4004
export WANDERER_DEFAULT_MAP_SLUG=test_map
```

### Performance Testing
```bash
# Load test surveillance engine
mix run -e "EveDmv.Surveillance.PerformanceTest.run_load_test(1000)"

# Profile memory usage
mix run -e ":observer.start()"
```

This surveillance system provides comprehensive monitoring capabilities for EVE Online activities while maintaining high performance and reliability. The modular architecture allows for easy extension and customization based on specific operational requirements.