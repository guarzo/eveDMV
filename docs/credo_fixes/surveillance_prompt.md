# Surveillance Context Code Quality Fixes

## Issues Overview - COMPLETE REMAINING WORK
- **Error Count**: 40+ errors in surveillance modules
- **Major Categories**: Single-function pipelines (15+), trailing whitespace (10+), alias organization (8+), variable redeclaration (5+), excessive dependencies (1)
- **Files Affected**: 
  - `lib/eve_dmv_web/live/surveillance_live.ex` (CRITICAL: 16 dependencies, max 15)
  - `lib/eve_dmv/surveillance/*`
  - `lib/eve_dmv/contexts/surveillance/*`

## AI Assistant Prompt

Address surveillance context code quality issues:

### 1. **Excessive Dependencies** (CRITICAL PRIORITY - PARTIALLY FIXED)
**PROGRESS**: ✅ SurveillanceLive core module dependencies reduced
**NEW ISSUE**: ❌ Services module now has 16 dependencies (max is 15)
**File**: `lib/eve_dmv_web/live/surveillance_live/services.ex:1:11`

**NEW Strategy for Services Module**:
- **Split Services module** into focused service modules:
  - `ProfileService` - profile CRUD operations
  - `NotificationService` - notification management  
  - `ExportImportService` - export/import functionality
  - `BatchOperationService` - batch operations
- **Use composition** instead of single large service module
- **Reduce database/API dependencies** in each service

**Suggested structure**:
```elixir
# Core LiveView (reduced dependencies)
SurveillanceLive

# Extracted modules
SurveillanceLive.Components.ProfileGrid
SurveillanceLive.Components.FilterPanel  
SurveillanceLive.Services.ProfileManager
SurveillanceLive.Services.NotificationHandler
```

### 2. **Variable Redeclaration** (High Priority)
Fix repeated variable names in matching and analysis modules:
```elixir
# Bad - same variable name reused
matched_criteria = initial_match()
# ... processing ...
matched_criteria = refined_match()

# Good - descriptive names  
initial_criteria = initial_match()
# ... processing ...
refined_criteria = refined_match()
```

**Common variables to fix**:
- `matched_criteria` → `initial_criteria`, `filtered_criteria`, `final_criteria`
- `filter_complexity` → `base_complexity`, `calculated_complexity`
- `recommendations` → `match_recommendations`, `filter_recommendations`

### 3. **Single-Function Pipelines** (High Priority)
Convert unnecessary pipelines:
```elixir
# Bad
profile_data |> ProfileManager.validate()

# Good
ProfileManager.validate(profile_data)
```

### 4. **Code Formatting** (Quick Wins)
- Remove trailing whitespace from all lines
- Add final newlines to files
- Format large numbers with underscores
- Fix alias/require ordering

## Implementation Steps

### **Phase 1: Dependency Reduction (CRITICAL)**
1. **Analyze SurveillanceLive dependencies**:
   ```bash
   grep -n "alias\|import\|use" lib/eve_dmv_web/live/surveillance_live.ex
   ```

2. **Extract UI components**:
   - Profile grid rendering
   - Filter panel management
   - Stats display components
   - Batch operation handlers

3. **Create service modules**:
   - Profile management operations
   - Notification handling
   - Export/import functionality
   - Search and filtering logic

4. **Refactor LiveView** to use extracted modules

### **Phase 2: Variable Naming**
1. **Identify redeclared variables** in matching engine
2. **Create naming convention**:
   - Prefix with stage: `initial_`, `filtered_`, `final_`
   - Include context: `criteria`, `matches`, `results`
3. **Rename systematically** preserving logic flow

### **Phase 3: Pipeline & Format Cleanup**
1. **Convert single-function pipelines**
2. **Fix import organization**
3. **Apply code formatting**

## Files Requiring Immediate Attention

**CRITICAL (Dependencies)**:
- `surveillance_live.ex` - Must reduce from 16 to ≤15 dependencies

**High Priority (Variables)**:
- `matching_engine.ex` - Multiple `matched_criteria` redeclarations
- `profile_manager.ex` - `filter_complexity` redeclaration
- Notification and alert services

**Medium Priority**:
- Pipeline issues in event processors
- Formatting across surveillance modules

## Dependency Reduction Strategy

### **Current Dependencies (Estimated)**
- Phoenix LiveView components
- Core surveillance modules
- Database repositories
- Authentication helpers
- UI component modules
- Utility libraries
- Broadcasting modules
- Export/import handlers

### **Target Architecture**
```elixir
# surveillance_live.ex (≤15 dependencies)
defmodule EveDmvWeb.SurveillanceLive do
  use EveDmvWeb, :live_view
  
  alias EveDmv.Surveillance
  alias EveDmvWeb.SurveillanceLive.{Components, Services}
  # ... up to 15 total
end

# Extracted component modules
defmodule EveDmvWeb.SurveillanceLive.Components do
  # UI rendering logic with own dependencies
end

defmodule EveDmvWeb.SurveillanceLive.Services do  
  # Business logic with own dependencies
end
```

## Success Criteria

1. **SurveillanceLive ≤15 dependencies** (passes credo check)
2. **No variable redeclaration** in surveillance modules
3. **All single-function pipelines** converted
4. **All tests passing** with no behavioral changes
5. **UI functionality preserved** exactly as before

Focus on maintaining all surveillance functionality while improving code organization and meeting dependency limits.
