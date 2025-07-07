# Module Structure Fixes (25+ errors)

## Error Patterns

### 1. defstruct Position (~22 errors)
**Pattern**: "defstruct must appear before module attribute"

### 2. Type Position (2 errors)
**Pattern**: "type must appear before module attribute"

### 3. Documentation Position (3 errors)
**Pattern**: "moduledoc/shortdoc must appear before X"

## Correct Module Element Order

```elixir
defmodule MyModule do
  @moduledoc "Module documentation"
  
  # Types and type definitions
  @type my_type :: term()
  @typep private_type :: term()
  
  # Struct definitions
  defstruct [:field1, :field2]
  
  # Module attributes
  @default_timeout 5000
  @constant_value "some_value"
  
  # Functions...
end
```

## Files with defstruct Position Issues

### Domain Events (Major File - 22 instances):
**File**: `lib/eve_dmv/domain_events.ex`

**Lines with defstruct issues**:
- Line 658 - StaticDataUpdated
- Line 630 - MarketAnalyzed  
- Line 606 - PriceUpdated
- Line 578 - AlertTriggered
- Line 550 - MatchFound
- Line 522 - MassCalculated
- Line 490 - SurveillanceAlert
- Line 462 - SurveillanceMatch
- Line 434 - FleetAnalysisComplete
- Line 389 - VettingCompleted
- Line 363 - ChainUpdated
- Line 339 - ChainActivityPrediction
- Line 315 - HostileMovement
- Line 289 - ChainThreatDetected
- Line 263 - DoctrineValidated
- Line 235 - FleetAnalyzed
- Line 205 - ThreatDetected
- Line 179 - CorporationAnalyzed
- Line 153 - CharacterAnalyzed
- Line 129 - TacticalInsightGenerated
- Line 101 - BattleAnalysisComplete
- Line 77 - KillmailFailed

### Other Files with defstruct Issues:
- `lib/eve_dmv/error.ex:30` (defstruct before type)
- `lib/eve_dmv/eve/circuit_breaker.ex:33`
- `lib/eve_dmv/intelligence/chain_monitor.ex:23`
- `lib/eve_dmv/intelligence/wanderer_client.ex:21`
- `lib/eve_dmv/intelligence/wanderer_sse.ex:19`

## Files with Type Position Issues

### Domain Events:
- `lib/eve_dmv/domain_events.ex:64` - KillmailEnriched
- `lib/eve_dmv/domain_events.ex:34` - KillmailReceived

### Infrastructure:
- `lib/eve_dmv/infrastructure/event_bus.ex:21`

## Files with Documentation Position Issues

### Module Documentation:
- `lib/eve_dmv/market/strategies/esi_strategy.ex:4`
- `lib/eve_dmv/market/strategies/mutamarket_strategy.ex:6`

### Short Documentation:
- `lib/mix/tasks/eve.analyze_performance.ex:10`
- `lib/mix/tasks/eve.load_static_data.ex:30`
- `lib/mix/tasks/security.audit.ex:22`

## Files with Other Module Attribute Issues

### Module Attributes Before Functions:
- `lib/eve_dmv/database/performance_optimizer.ex:36`
- `lib/eve_dmv/intelligence/wanderer_client.ex:17`
- `lib/eve_dmv/killmails/historical_killmail_fetcher.ex:23`

### Type Before Functions:
- `lib/eve_dmv/killmails/data_processor.ex:112`

## Fix Strategies

### For domain_events.ex (Major Effort):
This file has a repetitive pattern where each event has:
```elixir
@type some_event :: %__MODULE__{...}
defstruct [...]
```

**Fix**: Move all defstruct statements to appear immediately after their @type declarations.

### For other files:
**Standard module organization**: 
1. @moduledoc
2. @type/@typep
3. defstruct
4. @module_attributes
5. Functions

## Step-by-Step Instructions

### 1. Start with domain_events.ex (15 minutes)
This file requires the most work:
1. **Open** `lib/eve_dmv/domain_events.ex`
2. **For each event structure**, move defstruct to appear immediately after its @type
3. **Maintain the logical grouping** of related events
4. **Save and compile** to verify syntax

### 2. Fix other defstruct issues (5 minutes)
For each remaining file:
1. **Locate the defstruct** statement
2. **Move it before** any @module_attribute lines
3. **Ensure it comes after** @type/@typep lines

### 3. Fix documentation position (3 minutes)
For moduledoc/shortdoc issues:
1. **Move @moduledoc** to very beginning of module
2. **Move @shortdoc** to beginning (before alias statements)

### 4. Fix remaining module attribute issues (2 minutes)
For module attributes before functions:
1. **Move @module_attribute** statements before function definitions
2. **Group them logically** after struct/type definitions

## Example Fix Pattern

### Before:
```elixir
defmodule MyModule do
  @default_value 123
  
  defstruct [:field]
  
  @type my_type :: term()
  
  defp private_function, do: :ok
  
  @another_attribute "value"
end
```

### After:
```elixir
defmodule MyModule do
  @type my_type :: term()
  
  defstruct [:field]
  
  @default_value 123
  @another_attribute "value"
  
  defp private_function, do: :ok
end
```

## Time Estimates
- **domain_events.ex**: 15 minutes (22 fixes)
- **Other defstruct**: 3 minutes (4 fixes)
- **Documentation**: 2 minutes (5 fixes)
- **Module attributes**: 2 minutes (4 fixes)
- **Type positioning**: 1 minute (3 fixes)
- **Total**: 23 minutes

## Verification

After each major file:
```bash
# Compile to check syntax
mix compile

# Check remaining structure errors
mix credo | grep -c "defstruct must appear before"
mix credo | grep -c "must appear before"
```

After all fixes:
```bash
# Should show 0 module structure errors
mix credo | grep -c "must appear before"
```

## Expected Results
- **Before**: 25+ module structure errors
- **After**: 0 module structure errors  
- **Impact**: 12% reduction in total issues
- **Benefit**: Consistent, professional module organization

## Notes
- **domain_events.ex** is the largest file to fix but follows repetitive patterns
- **No logic changes** - purely organizational
- **Sets foundation** for clean, maintainable code structure
- **High visibility improvement** in code quality