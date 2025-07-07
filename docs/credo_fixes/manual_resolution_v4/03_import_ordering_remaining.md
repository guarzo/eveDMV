# Remaining Import Ordering Fixes (67 errors)

Based on current credo.txt, here are the remaining import ordering errors.

## Error Patterns:
- "alias must appear before require" (47 errors)
- "import must appear before require" (6 errors)  
- "import must appear before alias" (8 errors)
- "use must appear before alias" (6 errors)

## Correct Import Order:
```elixir
defmodule MyModule do
  # 1. use statements (FIRST)
  use GenServer
  
  # 2. alias statements (SECOND)
  alias MyApp.SomeModule
  
  # 3. require statements (THIRD)
  require Logger
  
  # 4. import statements (FOURTH)
  import Ecto.Query
end
```

## Files to Fix:

### "alias must appear before require" Errors:

#### Database Layer:
- `lib/eve_dmv/database/cache_invalidator.ex:12`
- `lib/eve_dmv/database/cache_warmer.ex:14`

#### EVE API Layer:
- `lib/eve_dmv/eve/esi_parsers.ex:11`
- `lib/eve_dmv/eve/esi_utils.ex:12`
- `lib/eve_dmv/eve/fallback_strategy.ex:13`
- `lib/eve_dmv/eve/name_resolver/cache_manager.ex:11`
- `lib/eve_dmv/eve/name_resolver/esi_entity_resolver.ex:11`
- `lib/eve_dmv/eve/name_resolver/static_data_resolver.ex:11`
- `lib/eve_dmv/eve/static_data_loader.ex:22`

#### Intelligence Layer:
- `lib/eve_dmv/intelligence/advanced_analytics.ex:11`
- `lib/eve_dmv/intelligence/alert_system.ex:13`
- `lib/eve_dmv/intelligence/analyzers/character_analyzer.ex:15`
- `lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/asset_availability.ex:11`
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer.ex:12`
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/corporation_analyzer.ex:11`
- `lib/eve_dmv/intelligence/analyzers/member_activity_data_collector.ex:11`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex:13`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/doctrine_manager.ex:11`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_analyzer.ex:11`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_optimizer.ex:12`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/wormhole_compatibility.ex:11`
- `lib/eve_dmv/intelligence/cache/analysis_cache.ex:11`
- `lib/eve_dmv/intelligence/cache_cleanup_worker.ex:15`
- `lib/eve_dmv/intelligence/chain_analysis/chain_event_handlers.ex:13`
- `lib/eve_dmv/intelligence/chain_analysis/system_inhabitants_manager.ex:13`
- `lib/eve_dmv/intelligence/chain_monitor.ex:14`
- `lib/eve_dmv/intelligence/intelligence_scoring.ex:11, 17`
- `lib/eve_dmv/intelligence/performance_optimizer.ex:11`
- `lib/eve_dmv/intelligence/supervisor.ex:16`
- `lib/eve_dmv/intelligence/threat_assessment.ex:11`

#### Infrastructure:
- `lib/eve_dmv/infrastructure/event_bus.ex:14`

#### Killmails:
- `lib/eve_dmv/killmails/data_processor.ex:11`
- `lib/eve_dmv/killmails/database_inserter.ex:11`
- `lib/eve_dmv/killmails/historical_killmail_fetcher.ex:11`
- `lib/eve_dmv/killmails/httpoison_sse_producer.ex:12`
- `lib/eve_dmv/killmails/killmail_broadcaster.ex:11`
- `lib/eve_dmv/killmails/killmail_pipeline.ex:14`
- `lib/eve_dmv/killmails/killmail_processor.ex:29`

#### Market:
- `lib/eve_dmv/market/price_service.ex:17`

#### Player Profile:
- `lib/eve_dmv/player_profile/stats_generator.ex:11`

#### Surveillance:
- `lib/eve_dmv/surveillance/matching/index_manager.ex:11`

#### Telemetry:
- `lib/eve_dmv/telemetry/performance_monitor/database_metrics.ex:11`

### "use must appear before alias" Errors:
- `lib/eve_dmv/database/archive_manager.ex:14`

### "import must appear before require" Errors:
- `lib/eve_dmv/eve/type_resolver.ex:12`
- `lib/eve_dmv/killmails/enriched_participant_loader.ex:14`

### "import must appear before alias" Errors:
- `lib/eve_dmv_web/live/alliance_live.ex:15`
- `lib/eve_dmv_web/live/chain_intelligence_live.ex:22`
- `lib/eve_dmv_web/live/character_intel_live.ex:20`
- `lib/eve_dmv_web/live/corporation_live.ex:15`
- `lib/eve_dmv_web/live/dashboard_live.ex:11`
- `lib/eve_dmv_web/live/kill_feed_live.ex:12`

## Fix Instructions:

### For Each File:

1. **Open the file** and locate the import section
2. **Identify current order** of use, alias, require, import statements
3. **Reorganize** in the correct order
4. **Group statements** by type with blank lines between groups

### Example Fix:

```elixir
# BEFORE (incorrect order):
defmodule SomeModule do
  require Logger
  alias MyApp.SomeModule
  use GenServer
  import Ecto.Query

# AFTER (correct order):
defmodule SomeModule do
  use GenServer
  
  alias MyApp.SomeModule
  
  require Logger
  
  import Ecto.Query
```

### Common Patterns to Fix:

#### Pattern 1: alias before require
```elixir
# WRONG:
require Logger
alias MyApp.Module

# RIGHT:
alias MyApp.Module
require Logger
```

#### Pattern 2: use before alias
```elixir
# WRONG:
alias MyApp.Module
use GenServer

# RIGHT:
use GenServer
alias MyApp.Module
```

#### Pattern 3: import before require
```elixir
# WRONG:
require Logger
import Ecto.Query

# RIGHT:
import Ecto.Query
require Logger
```

## Step-by-Step Process:

1. **Start with database files** (usually simpler)
2. **Move to EVE API files** 
3. **Process intelligence files** (most complex)
4. **Finish with web files**

## Verification:
After each file:
1. **Check the import order** follows: use → alias → require → import
2. **Save the file**
3. **Run `mix compile`** to ensure no syntax errors
4. **The credo error should disappear** for that file

## Progress Tracking:

### Database Files:
- [ ] database/cache_invalidator.ex
- [ ] database/cache_warmer.ex
- [ ] database/archive_manager.ex (use before alias)

### EVE API Files:
- [ ] eve/esi_parsers.ex
- [ ] eve/esi_utils.ex
- [ ] eve/fallback_strategy.ex
- [ ] eve/name_resolver/cache_manager.ex
- [ ] eve/name_resolver/esi_entity_resolver.ex
- [ ] eve/name_resolver/static_data_resolver.ex
- [ ] eve/static_data_loader.ex
- [ ] eve/type_resolver.ex (import before require)

### Intelligence Files (largest group):
- [ ] intelligence/advanced_analytics.ex
- [ ] intelligence/alert_system.ex
- [ ] intelligence/analyzers/character_analyzer.ex
- [ ] intelligence/analyzers/fleet_asset_manager/asset_availability.ex
- [ ] intelligence/analyzers/member_activity_analyzer.ex
- [ ] intelligence/analyzers/member_activity_analyzer/corporation_analyzer.ex
- [ ] intelligence/analyzers/member_activity_data_collector.ex
- [ ] intelligence/analyzers/wh_fleet_analyzer.ex
- [ ] intelligence/analyzers/wh_fleet_analyzer/doctrine_manager.ex
- [ ] intelligence/analyzers/wh_fleet_analyzer/fleet_analyzer.ex
- [ ] intelligence/analyzers/wh_fleet_analyzer/fleet_optimizer.ex
- [ ] intelligence/analyzers/wh_fleet_analyzer/wormhole_compatibility.ex
- [ ] intelligence/cache/analysis_cache.ex
- [ ] intelligence/cache_cleanup_worker.ex
- [ ] intelligence/chain_analysis/chain_event_handlers.ex
- [ ] intelligence/chain_analysis/system_inhabitants_manager.ex
- [ ] intelligence/chain_monitor.ex
- [ ] intelligence/intelligence_scoring.ex (2 fixes)
- [ ] intelligence/performance_optimizer.ex
- [ ] intelligence/supervisor.ex
- [ ] intelligence/threat_assessment.ex

### Other Files:
- [ ] infrastructure/event_bus.ex
- [ ] killmails/data_processor.ex
- [ ] killmails/database_inserter.ex
- [ ] killmails/historical_killmail_fetcher.ex
- [ ] killmails/httpoison_sse_producer.ex
- [ ] killmails/killmail_broadcaster.ex
- [ ] killmails/killmail_pipeline.ex
- [ ] killmails/killmail_processor.ex
- [ ] killmails/enriched_participant_loader.ex (import before require)
- [ ] market/price_service.ex
- [ ] player_profile/stats_generator.ex
- [ ] surveillance/matching/index_manager.ex
- [ ] telemetry/performance_monitor/database_metrics.ex

### Web Files:
- [ ] eve_dmv_web/live/alliance_live.ex
- [ ] eve_dmv_web/live/chain_intelligence_live.ex
- [ ] eve_dmv_web/live/character_intel_live.ex
- [ ] eve_dmv_web/live/corporation_live.ex
- [ ] eve_dmv_web/live/dashboard_live.ex
- [ ] eve_dmv_web/live/kill_feed_live.ex

This should eliminate all 67 import ordering errors.