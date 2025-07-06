# Web & LiveView Code Quality Fixes

## Issues Overview - COMPLETE REMAINING WORK
- **Error Count**: 80+ errors across web modules
- **Major Categories**: Single-function pipelines (30+), trailing whitespace (20+), alias organization (15+), variable redeclaration (10+), excessive dependencies (1)
- **Files Affected**: 
  - `lib/eve_dmv_web/live/*`
  - `lib/eve_dmv_web/components/*`
  - `lib/eve_dmv_web/controllers/*`
  - `lib/eve_dmv_web/live/surveillance_live/services.ex` (16 dependencies)

## AI Assistant Prompt

Address web layer code quality issues systematically:

### 1. **Single-Function Pipelines** (HIGH PRIORITY - 30+ instances)
**Status**: ❌ Major category in LiveView modules
**Affected**: All LiveView modules, components, controllers
```elixir
# Bad
socket |> assign(:loading, true)

# Good  
assign(socket, :loading, true)

# Bad
changeset |> Ecto.Changeset.put_change(:status, "active")

# Good
Ecto.Changeset.put_change(changeset, :status, "active")
```

### 2. **Trailing Whitespace** (CRITICAL - 20+ instances)
**Status**: ❌ Easy automated fix available
**Solution**: Run `mix format` on all web modules
**Impact**: Immediate 25% error reduction in web layer

### 3. **Alias Organization** (HIGH PRIORITY - 15+ instances)
**Issues**:
- `alias` must appear before `require`
- Grouped aliases must be individual lines
- Need alphabetical ordering

```elixir
# Bad
require Logger
alias EveDmvWeb.{ComponentA, ComponentB}
alias EveDmv.Api

# Good
alias EveDmv.Api
alias EveDmvWeb.ComponentA
alias EveDmvWeb.ComponentB
require Logger
```

### 4. **Variable Redeclaration** (MEDIUM PRIORITY - 10+ instances)
**Common in LiveView event handlers**:
```elixir
# Bad - socket redeclared multiple times
def handle_event("action", params, socket) do
  socket = assign(socket, :loading, true)
  # ... processing ...
  socket = assign(socket, :loading, false)
  {:noreply, socket}
end

# Good - descriptive intermediate states
def handle_event("action", params, socket) do
  loading_socket = assign(socket, :loading, true)
  # ... processing ...
  final_socket = assign(loading_socket, :loading, false)
  {:noreply, final_socket}
end
```

### 5. **Excessive Dependencies** (CRITICAL - 1 instance)
**File**: `lib/eve_dmv_web/live/surveillance_live/services.ex`
**Issue**: 16 dependencies (max 15)
**Solution**: Split into focused service modules:
- `ProfileService` - profile operations
- `NotificationService` - notifications
- `ExportImportService` - data exchange
- `BatchOperationService` - bulk operations

## Implementation Steps

### **Phase 1: Automated Formatting**
```bash
# Format all web modules
find lib/eve_dmv_web -name "*.ex" -exec mix format {} \;
# Result: ~20 errors eliminated
```

### **Phase 2: Pipeline Conversion**
Target files:
- All LiveView modules (`*_live.ex`)
- Component modules
- Controller actions
- View helpers

### **Phase 3: Import Organization**
1. Extract all imports to top of file
2. Order: `alias`, then `require`, then `import`, then `use`
3. Alphabetize within each group
4. Expand grouped aliases

### **Phase 4: Variable Cleanup**
Focus on LiveView event handlers:
- `handle_event` functions
- `handle_info` callbacks
- Mount and update functions

### **Phase 5: Dependency Reduction**
Split `surveillance_live/services.ex`:
```elixir
# From:
defmodule EveDmvWeb.SurveillanceLive.Services do
  # 16 dependencies...
end

# To:
defmodule EveDmvWeb.SurveillanceLive.Services.Profiles do
  # 5-6 dependencies
end

defmodule EveDmvWeb.SurveillanceLive.Services.Notifications do
  # 4-5 dependencies
end
# etc.
```

## Files Requiring Immediate Attention

**Critical (Dependencies)**:
- `surveillance_live/services.ex` - Split required

**High Priority (Pipelines)**:
- All LiveView modules with 30+ pipeline issues
- Component modules
- Authentication and controller modules

**Quick Wins (Formatting)**:
- All web modules for whitespace cleanup
- Import organization across all files

## Success Criteria

1. **Surveillance Services ≤15 dependencies** per module
2. **Zero single-function pipelines** in LiveView modules
3. **All imports properly organized** 
4. **No variable redeclaration** in event handlers
5. **All whitespace cleaned** via formatting

## Expected Impact

- **Current**: 80+ errors in web layer
- **After Phase 1**: ~60 errors (25% reduction)
- **After Phase 2**: ~30 errors (62% reduction)
- **After Phase 3**: ~15 errors (81% reduction)
- **After Phase 4**: ~5 errors (94% reduction)
- **After Phase 5**: 0-2 errors (near complete)

Web layer can achieve near-zero errors with systematic approach.