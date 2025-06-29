# ESI Integration Summary

## Overview

Successfully implemented ESI (EVE Swagger Interface) integration for both character intelligence and player profile pages. This allows users to look up ANY EVE Online character by ID, even if we've never seen them in our killmail feed.

## Features Added

### 1. Historical Killmail Fetcher (`lib/eve_dmv/killmails/historical_killmail_fetcher.ex`)

- **Purpose**: Fetch up to 90 days of historical killmail data for any character from wanderer-kills service
- **Technology**: Uses enhanced SSE endpoint with character filtering and preload capabilities
- **Intelligence**: Automatically detects when historical data transfer is complete (via heartbeat pattern)
- **Storage**: Stores all historical data in the same format as live pipeline

**Key Features**:
- Connects to `GET /api/v1/kills/stream/enhanced?character_ids={id}&preload_days=90`
- Processes batched historical data and individual killmails
- Automatically disconnects after receiving all historical data
- Handles connection errors and timeouts gracefully
- Reuses pipeline changeset builders for consistency

### 2. Character Intelligence ESI Integration

**Enhanced `lib/eve_dmv_web/live/character_intel_live.ex`**:
- Fetches character info from ESI when not found in database
- Gets corporation and alliance details automatically
- Triggers historical killmail fetch on first lookup
- Shows basic character info even without killmail data
- Maintains all existing functionality for known characters

**User Experience**:
- Loading indicator while fetching data
- Yellow notice when showing ESI-only data
- Full intelligence analysis if historical data is available
- Graceful error handling for non-existent characters

### 3. Player Profile ESI Integration

**Enhanced `lib/eve_dmv_web/live/player_profile_live.ex`**:
- Same ESI lookup capability as character intelligence
- Shows basic character information from EVE's API
- Displays corporation, alliance, security status, and character age
- Automatically generates player stats if killmail data becomes available
- Maintains existing analytics functionality

**User Experience**:
- Consistent loading and error states
- Clear indication when only ESI data is available
- Seamless integration with existing player statistics

## Data Sources

### ESI API (`lib/eve_dmv/eve/esi_client.ex`)
- **Character Info**: Name, corporation, alliance, security status, birthday
- **Corporation Info**: Name, ticker, member count, CEO
- **Alliance Info**: Name, ticker, founding date
- **Caching**: Built-in ETS cache for performance
- **Rate Limiting**: Respects ESI's 150 req/s limit with safety margin

### Wanderer-Kills Historical Data
- **Source**: Enhanced SSE endpoint with character filtering
- **Coverage**: Up to 90 days of historical killmails
- **Format**: Same as live feed for consistency
- **Processing**: Automatic storage in raw/enriched/participant tables

## Error Handling

### Character Not Found
- Shows clear error message
- Distinguishes between "not in EVE" vs "ESI unavailable"
- Graceful fallback to available data

### Network Issues
- Timeout handling for SSE connections
- Retry logic for ESI requests
- Fallback to partial data when possible

### Data Inconsistencies
- Handles missing corporation/alliance gracefully
- Safe defaults for missing fields
- Validation of required data before processing

## Performance Considerations

### ESI Rate Limiting
- 80% safety margin on 150 req/s limit
- Request batching where possible
- Intelligent caching strategy

### Async Processing
- All ESI calls happen in background tasks
- Non-blocking UI updates
- Progress indicators for long operations

### Data Efficiency
- Only fetch missing characters from ESI
- Reuse existing pipeline infrastructure
- Minimal duplicate storage

## Usage Examples

### Character Intelligence
```
# Previously: Only worked for characters in our database
GET /intel/95465499  # CCP Falcon - existing character

# Now: Works for any EVE character
GET /intel/2115778369  # Any character ID - fetches from ESI + historical data
```

### Player Profile
```
# Previously: Required existing player stats
GET /profile/95465499  # Only worked with pre-generated stats

# Now: Works for any character
GET /profile/2115778369  # Shows ESI info + attempts stats generation
```

## Configuration

### Environment Variables
```bash
# ESI Configuration (already configured)
EVE_SSO_CLIENT_ID=your_client_id
EVE_SSO_CLIENT_SECRET=your_secret

# Wanderer-Kills Configuration (already configured)
WANDERER_KILLS_BASE_URL=http://host.docker.internal:4004
```

### Default Settings
- **Historical Data**: 90 days maximum
- **ESI Timeout**: 30 seconds per request
- **Heartbeat Threshold**: 3 consecutive heartbeats = end of historical data
- **Cache TTL**: As configured in EsiCache module

## Impact

### User Experience
- ✅ Can now look up ANY EVE character by ID
- ✅ Immediate basic information from ESI
- ✅ Automatic historical data population
- ✅ Seamless integration with existing features

### Performance
- ✅ Async processing keeps UI responsive
- ✅ Caching reduces redundant ESI calls
- ✅ Rate limiting prevents API abuse
- ✅ Background historical data fetch

### Reliability
- ✅ Graceful degradation when services unavailable
- ✅ Clear error messages for troubleshooting
- ✅ Fallback to partial data when possible
- ✅ Timeout protection for long operations

## Future Enhancements

### Possible Improvements
1. **Bulk Character Lookup**: Process multiple character IDs simultaneously
2. **Smart Refresh**: Update stale ESI data automatically
3. **Alliance Intelligence**: Extend to alliance/corporation level analysis
4. **Historical Data Chunking**: Process very active characters in smaller batches
5. **ESI Event Stream**: Subscribe to character updates for real-time sync

### Technical Debt
- Consider extracting ESI integration to shared service
- Add more comprehensive error telemetry
- Implement circuit breaker pattern for external services
- Add metrics for ESI usage and performance

## Testing

To test the integration:

1. **Character Intelligence**: Navigate to `/intel/{any_character_id}`
2. **Player Profile**: Navigate to `/profile/{any_character_id}`
3. **Unknown Character**: Use character ID not in database (e.g., 2115778369)
4. **Invalid Character**: Use non-existent character ID to test error handling

The system will automatically fetch ESI data and historical killmails as needed.