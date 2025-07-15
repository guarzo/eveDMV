# Prompt 2: Fix Module Aliasing and Import Issues

## Task
Fix module aliasing issues, import statements, and namespace conflicts throughout the codebase.

## Context
Several files have module aliasing issues, import conflicts, and namespace problems that need to be resolved to improve code clarity and prevent conflicts.

## Instructions
1. Review and fix module aliasing in these key files:
   - `lib/eve_dmv/contexts/character_intelligence.ex` - Has alias conflicts
   - `lib/eve_dmv/contexts/corporation_intelligence.ex` - Needs proper aliasing
   - `lib/eve_dmv/contexts/battle_analysis.ex` - Import organization needed
   - `lib/eve_dmv/api.ex` - Resource organization

2. For each file:
   - Ensure all `alias` statements are properly organized
   - Remove unused imports
   - Fix any namespace conflicts
   - Organize imports in a consistent order (standard library, dependencies, local modules)
   - Ensure module names don't conflict with function names

3. Pay special attention to:
   - Context modules that aggregate multiple submodules
   - API definitions that import many resources
   - Modules with many internal aliases

## Files to Focus On
- `lib/eve_dmv/api.ex`
- `lib/eve_dmv/contexts/character_intelligence.ex`
- `lib/eve_dmv/contexts/corporation_intelligence.ex`
- `lib/eve_dmv/contexts/battle_analysis.ex`
- `lib/eve_dmv/intelligence_migration_adapter.ex`

## Success Criteria
- All module aliases are properly defined and used
- No namespace conflicts
- Imports are organized and unused imports removed
- Code compiles without warnings
- Module structure is clean and consistent

## Important Notes
- This task focuses on import/alias organization only
- DO NOT change business logic or function implementations
- Maintain existing API contracts
- Ensure all references to aliased modules are updated consistently