# Wanderer Integration Implementation Plan

## Current Status
✅ **Infrastructure Ready**: Database schema, API client structure, UI components  
🔧 **Needs Implementation**: Real API integration, authentication, WebSocket connection

## Required Changes for Live Integration

### 1. Authentication & Authorization
**Current**: Mock auth token from environment  
**Needed**: Actual Wanderer authentication flow

```elixir
# Need to implement:
- Wanderer API key or OAuth integration
- User permission checking (can user access specific maps?)
- Token refresh mechanism
- Error handling for auth failures
```

**Environment Variables Needed**:
```bash
WANDERER_API_KEY=your_wanderer_api_key
WANDERER_BASE_URL=https://wanderer.example.com
WANDERER_WS_URL=wss://wanderer.example.com/socket
```

### 2. Real API Endpoint Implementation
**Current Endpoints Used**:
- `GET /api/maps/{map_id}/systems` - ✅ Matches OpenAPI spec
- `GET /api/maps/{map_id}/connections` - ✅ Matches OpenAPI spec  
- `GET /api/maps/{map_id}/signatures` - 🔧 Need to add for complete data

**Required Updates**:
```elixir
# Update WandererClient to handle real responses
defp get_systems_api(map_id, auth_token) do
  url = "#{@base_url}/api/maps/#{map_id}/systems"
  headers = build_headers(auth_token)
  
  case HTTPoison.get(url, headers, timeout: @api_timeout) do
    {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
      # Parse actual Wanderer response format
      case Jason.decode(body) do
        {:ok, %{"systems" => systems, "connections" => connections}} ->
          {:ok, %{systems: systems, connections: connections}}
        {:ok, data} -> {:ok, data}
        error -> error
      end
    # Handle auth errors, rate limits, etc.
  end
end
```

### 3. WebSocket Real-Time Connection
**Current**: Placeholder WebSocket loop  
**Needed**: Real WebSocket client using Gun or WebSockex

```elixir
# Add to mix.exs
{:websockex, "~> 0.4.3"}

# Implement real WebSocket connection
defmodule EveDmv.Intelligence.WandererWebSocket do
  use WebSockex
  
  def start_link(url, auth_token) do
    headers = [{"Authorization", "Bearer #{auth_token}"}]
    WebSockex.start_link(url, __MODULE__, %{}, extra_headers: headers)
  end
  
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, data} -> 
        # Forward to ChainMonitor
        GenServer.cast(EveDmv.Intelligence.ChainMonitor, {:ws_update, data})
      _ -> :ok
    end
    {:ok, state}
  end
end
```

### 4. Data Format Mapping
**Current**: Assumes our own format  
**Needed**: Map Wanderer's actual API response format

**Example Wanderer Response** (based on OpenAPI):
```json
{
  "systems": [
    {
      "id": "uuid",
      "solar_system_id": 31000001,
      "name": "J123456",
      "characters": [
        {
          "character_id": 12345,
          "character_name": "Pilot Name",
          "corporation_id": 67890,
          "ship_type_id": 670
        }
      ]
    }
  ],
  "connections": [
    {
      "id": "uuid", 
      "source_system_id": 31000001,
      "target_system_id": 31000002,
      "mass_status": "stable",
      "time_status": "stable"
    }
  ]
}
```

**Mapping Functions Needed**:
```elixir
defp parse_wanderer_systems(wanderer_data) do
  wanderer_data["systems"]
  |> Enum.flat_map(fn system ->
    system["characters"]
    |> Enum.map(fn char ->
      %{
        character_id: char["character_id"],
        character_name: char["character_name"],
        corporation_id: char["corporation_id"],
        system_id: system["solar_system_id"],
        system_name: system["name"],
        ship_type_id: char["ship_type_id"]
      }
    end)
  end)
end
```

### 5. Error Handling & Resilience
**Add Comprehensive Error Handling**:
- Network timeouts
- Authentication failures  
- Rate limiting (429 responses)
- Invalid map IDs (404 responses)
- WebSocket disconnections

```elixir
defp handle_api_error(status_code, body) do
  case status_code do
    401 -> {:error, :unauthorized}
    403 -> {:error, :forbidden}
    404 -> {:error, :map_not_found}
    429 -> {:error, :rate_limited}
    _ -> {:error, "HTTP #{status_code}: #{body}"}
  end
end
```

### 6. Configuration & Environment Setup
**Update config/runtime.exs**:
```elixir
config :eve_dmv,
  wanderer_base_url: System.get_env("WANDERER_BASE_URL"),
  wanderer_ws_url: System.get_env("WANDERER_WS_URL"),
  wanderer_api_key: System.get_env("WANDERER_API_KEY")
```

**Update .env example**:
```bash
# Wanderer Integration
WANDERER_BASE_URL=https://your-wanderer-instance.com
WANDERER_WS_URL=wss://your-wanderer-instance.com/socket
WANDERER_API_KEY=your_api_key_here
```

## Implementation Priority

### Phase 1: Basic API Integration (1-2 days)
1. ✅ Update WandererClient with real HTTP calls
2. ✅ Add proper authentication headers
3. ✅ Implement response parsing for actual Wanderer format
4. ✅ Add comprehensive error handling

### Phase 2: WebSocket Integration (1 day) 
1. ✅ Replace mock WebSocket with real WebSockex client
2. ✅ Handle connection lifecycle (connect, disconnect, reconnect)
3. ✅ Process real-time events from Wanderer

### Phase 3: Data Validation & Testing (1 day)
1. ✅ Test with actual Wanderer instance
2. ✅ Validate data parsing with real responses
3. ✅ Performance testing with live data
4. ✅ Error scenario testing

## Testing Strategy

### Development Testing
1. **Mock Wanderer Server**: Create a test server that mimics Wanderer's API
2. **Unit Tests**: Test data parsing functions with real response formats
3. **Integration Tests**: Test full flow with mock Wanderer instance

### Production Readiness
1. **Staging Environment**: Test with real Wanderer instance
2. **Performance Testing**: Monitor response times and memory usage
3. **Error Recovery**: Test resilience to network issues and auth failures

## Success Criteria

### Functional Requirements
- ✅ Successfully authenticate with Wanderer API
- ✅ Fetch chain topology and inhabitants for valid map IDs
- ✅ Receive real-time updates via WebSocket
- ✅ Handle errors gracefully without crashing
- ✅ Display accurate data in Chain Intelligence UI

### Performance Requirements  
- ✅ API calls complete within 5 seconds
- ✅ WebSocket reconnects automatically on disconnect
- ✅ No memory leaks during long-running operation
- ✅ Handle 10+ concurrent chain monitoring sessions

### User Experience
- ✅ Clear error messages for invalid map IDs or auth issues
- ✅ Loading states during API calls
- ✅ Real-time updates appear within 5 seconds
- ✅ Chain monitoring works reliably during operations

## Next Steps

1. **Get Wanderer Instance Access**: Obtain API credentials and instance URL
2. **Implement Real API Client**: Update WandererClient with actual implementation
3. **Add WebSocket Client**: Replace mock with real WebSockex integration
4. **Test Integration**: Validate with live Wanderer data
5. **Performance Tune**: Optimize for production use

The architecture is ready - we just need to replace the mock implementations with real Wanderer API integration!