# Infrastructure & Utilities Code Quality Fixes

## Issues Overview - COMPLETE REMAINING WORK
- **Error Count**: ~200 errors still remain across infrastructure modules
- **Major Categories**: Single-function pipelines (60+), trailing whitespace (50+), alias organization (30+), variable redeclaration (20+), pipe chain structure (15+)
- **Files Affected**: 
  - `lib/eve_dmv/workers/*`
  - `lib/eve_dmv/telemetry/*`
  - `lib/eve_dmv/surveillance/*`
  - `lib/eve_dmv/security/*`
  - `lib/eve_dmv/quality/*`
  - `lib/eve_dmv/intelligence/*`
  - `lib/eve_dmv/eve/*`
  - `lib/eve_dmv/analytics/*`
  - `test/` files

## AI Assistant Prompt

Address current infrastructure and utility code quality issues:

### 1. **Single-Function Pipelines** (HIGH PRIORITY - 60+ remaining)
**Status**: ❌ Major work still required across infrastructure modules
**Scope**: Worker supervisors, telemetry, security, analytics, test utilities
**Task**: Convert ALL single-function pipelines to direct function calls:
```elixir
# Bad
result |> SomeModule.process()

# Good
SomeModule.process(result)
```

**Key Areas**:
- Worker supervisors and task management
- Telemetry and monitoring modules  
- Security authentication and validation
- Quality metrics collection
- Test helper utilities

### 2. **Trailing Whitespace** (CRITICAL - 50+ instances in infrastructure)
**Status**: ❌ Widespread formatting issue requiring automated fix
**Solution**: Run code formatter on all infrastructure modules
**Impact**: Easy automated fix for immediate error reduction

### 3. **Alias Organization** (HIGH PRIORITY - 30+ instances)
**Issues**:
- `alias` statements must appear before `require`
- Grouped aliases `alias {A, B}` must be individual lines
- Need alphabetical ordering within import groups

### 3. **@impl Annotations** (High Priority - 30+ instances)
Replace generic `@impl true` with specific behavior names:
```elixir
# Bad
@impl true
def handle_call(...)

# Good  
@impl GenServer
def handle_call(...)
```

**Common behaviors to specify**:
- `GenServer`
- `Supervisor` 
- `Task`
- Custom behavior modules

### 4. **Variable Redeclaration** (Medium Priority - 20+ instances)
Fix repeated variable names with descriptive alternatives:
- `recommendations` → `initial_recommendations`, `filtered_recommendations`, `final_recommendations`
- `results` → `query_results`, `analysis_results`, `validation_results`
- `errors` → `validation_errors`, `processing_errors`, `network_errors`

### 5. **Import Organization** (Medium Priority)
- Order: `alias` before `require` before `import`
- No grouped aliases: `alias {A, B}` → separate lines
- Alphabetize within each group

### 6. **Logger Metadata** (Low Priority)
Add missing logger metadata keys to config:
- `entity_type`
- `threat_level` 
- `error`
- `character_id`
- `corporation_id`

## Implementation Priority

1. **Quick Wins (Do First)**:
   - Run code formatter for whitespace/formatting
   - Convert single-function pipelines
   - Add specific @impl annotations

2. **Code Quality**:
   - Fix variable redeclaration with descriptive names
   - Organize imports properly
   - Address any remaining pipe chain issues

3. **Configuration**:
   - Update logger metadata configuration
   - Review module attribute ordering

## Files Requiring Immediate Attention

Based on error frequency:
- Worker and supervisor modules
- Security and authentication modules
- Quality metrics collectors
- Telemetry and monitoring components
- Test utilities and helpers

Focus on maintaining all infrastructure functionality while systematically improving code organization.
