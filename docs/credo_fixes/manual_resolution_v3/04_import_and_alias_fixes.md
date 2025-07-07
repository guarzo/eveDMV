# Manual Resolution: Import and Alias Fixes (47 errors)

## Error Patterns:
- "use must appear before alias" 
- "use must appear before require"
- "alias calls should be consecutive"
- "The alias 'X' is not alphabetically ordered"
- "Avoid grouping aliases in '{ ... }'"

## Import Order Rules:
```elixir
defmodule MyModule do
  # 1. use statements (FIRST)
  use GenServer
  use SomeOtherModule
  
  # 2. alias statements (SECOND, alphabetical)
  alias MyApp.ModuleA
  alias MyApp.ModuleB
  alias MyApp.ModuleC
  
  # 3. require statements (THIRD)
  require Logger
  
  # 4. import statements (FOURTH)
  import Ecto.Query
  
  # Rest of module...
end
```

## Files to Fix:

### 1. lib/eve_dmv/contexts/player_profile/analyzers/behavioral_patterns_analyzer.ex
**Line 10** - `use must appear before alias`

**Fix:** Move all `use` statements to the top, before any `alias` statements.

### 2. lib/eve_dmv/contexts/player_profile/analyzers/combat_stats_analyzer.ex  
**Line 11** - `use must appear before alias`

**Fix:** Move `use` statements before `alias` statements.

### 3. lib/eve_dmv/contexts/player_profile/analyzers/ship_preferences_analyzer.ex
**Line 11** - `use must appear before alias`

**Fix:** Move `use` statements before `alias` statements.

### 4. lib/eve_dmv/contexts/player_profile/domain/player_analyzer.ex
**Line 11:9** - Alias not alphabetically ordered

**Fix:** Reorder aliases alphabetically:
```elixir
# Find the alias block and reorder like:
alias EveDmv.Contexts.PlayerProfile.Domain.SomeModule
alias EveDmv.Contexts.PlayerProfile.Infrastructure.PlayerRepository  # Move this to correct position
alias EveDmv.Contexts.PlayerProfile.Other.Module
```

### 5. lib/eve_dmv/contexts/surveillance/api.ex
**Line 14:9** - Alias not alphabetically ordered

**Fix:** Reorder the alias for `EveDmv.Contexts.Surveillance.Domain.ProfileManager` to correct alphabetical position.

### 6. lib/eve_dmv/contexts/surveillance/domain/alert_service.ex
**Line 12:9** - Alias not alphabetically ordered  

**Fix:** Reorder `EveDmv.DomainEvents.SurveillanceMatch` alphabetically.

### 7. lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex
**Line 19:9** - Alias not alphabetically ordered
**Line 27** - `use must appear before alias`

**Fix:** 
1. Move `use` statements to top
2. Reorder `EveDmv.Intelligence.WandererClient` alphabetically

### 8. lib/eve_dmv/contexts/surveillance/domain/matching_engine.ex
**Line 14:9** - Alias not alphabetically ordered

**Fix:** Reorder `EveDmv.DomainEvents.SurveillanceMatch` alphabetically.

### 9. lib/eve_dmv/contexts/surveillance/domain/profile_manager.ex
**Line 11** - `use must appear before alias`

**Fix:** Move `use` statements before `alias` statements.

### 10. lib/eve_dmv/contexts/surveillance/infrastructure/killmail_event_processor.ex
**Line 11:9** - Alias not alphabetically ordered

**Fix:** Reorder `EveDmv.DomainEvents.KillmailReceived` alphabetically.

### 11. lib/eve_dmv/contexts/surveillance/infrastructure/profile_repository.ex
**Line 10** - `use must appear before alias`
**Line 15** - `use must appear before require`

**Fix:** Move all `use` statements to the very top, before `alias` and `require`.

### 12. lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex
**Line 17:58** - Avoid grouping aliases
**Line 19** - `use must appear before alias`

**Fix:** 
1. Expand grouped aliases: `alias Module.{A, B, C}` → separate lines
2. Move `use` statements to top

Example:
```elixir
# BEFORE:
alias EveDmv.SomeModule.{SubModuleA, SubModuleB, SubModuleC}

# AFTER:
alias EveDmv.SomeModule.SubModuleA
alias EveDmv.SomeModule.SubModuleB  
alias EveDmv.SomeModule.SubModuleC
```

### 13. lib/eve_dmv/contexts/threat_assessment/domain/threat_analyzer.ex
**Line 11:9** - Alias not alphabetically ordered
**Line 15** - `use must appear before alias`
**Line 17:3** - Alias calls should be consecutive

**Fix:**
1. Move `use` statements to top
2. Group all `alias` statements together
3. Sort aliases alphabetically
4. Reorder `EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatRepository`

### 14. lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_cache.ex
**Line 12** - `use must appear before alias`

**Fix:** Move `use` statements before `alias` statements.

### 15. lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_repository.ex
**Line 10** - `use must appear before alias`

**Fix:** Move `use` statements before `alias` statements.

## Step-by-Step Process:

### For Each File:

1. **Open the file** and locate the import section (usually at top of module)

2. **Identify current order** - look for `use`, `alias`, `require`, `import` statements

3. **Reorganize in correct order:**
   ```elixir
   # 1. All use statements first
   use GenServer
   use MyModule
   
   # 2. All alias statements (alphabetical)
   alias ModuleA
   alias ModuleB
   
   # 3. All require statements  
   require Logger
   
   # 4. All import statements
   import SomeModule
   ```

4. **Alphabetize aliases** within their group

5. **Expand grouped aliases** if any exist:
   ```elixir
   # WRONG:
   alias App.{ModuleA, ModuleB}
   
   # RIGHT:
   alias App.ModuleA
   alias App.ModuleB
   ```

6. **Save and compile** to verify no syntax errors

## Common Alphabetization Examples:

```elixir
# WRONG ORDER:
alias EveDmv.SomeModule.ZModule
alias EveDmv.SomeModule.AModule  
alias EveDmv.OtherModule.BModule

# CORRECT ORDER:
alias EveDmv.OtherModule.BModule
alias EveDmv.SomeModule.AModule
alias EveDmv.SomeModule.ZModule
```

## Verification Checklist:

For each file:
- [ ] All `use` statements come first
- [ ] All `alias` statements are grouped together and alphabetical
- [ ] All `require` statements come after aliases
- [ ] All `import` statements come last
- [ ] No grouped aliases (no `{...}` syntax)
- [ ] File compiles without errors

## Progress Tracking:
- [ ] player_profile/analyzers/behavioral_patterns_analyzer.ex
- [ ] player_profile/analyzers/combat_stats_analyzer.ex
- [ ] player_profile/analyzers/ship_preferences_analyzer.ex  
- [ ] player_profile/domain/player_analyzer.ex
- [ ] surveillance/api.ex
- [ ] surveillance/domain/alert_service.ex
- [ ] surveillance/domain/chain_intelligence_service.ex
- [ ] surveillance/domain/matching_engine.ex
- [ ] surveillance/domain/profile_manager.ex
- [ ] surveillance/infrastructure/killmail_event_processor.ex
- [ ] surveillance/infrastructure/profile_repository.ex
- [ ] threat_assessment/analyzers/threat_analyzer.ex
- [ ] threat_assessment/domain/threat_analyzer.ex
- [ ] threat_assessment/infrastructure/threat_cache.ex
- [ ] threat_assessment/infrastructure/threat_repository.ex

This should eliminate all import/alias ordering errors.