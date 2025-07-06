# Credo Code Quality Fix Prompts

This directory contains AI assistant prompts for fixing code quality issues identified by Credo static analysis.

## Overview - POST WORKSTREAM UPDATE ✅

- **Total Errors**: **925 errors** (reduced from 1,700+) - **47% improvement**
- **Remaining Critical Issues**: Excessive dependencies (1), duplicate code (3), pipe chains (~20)
- **Source**: Updated analysis after workstream completion - December 2024
- **Status**: Major progress achieved, focus on critical issues

## URGENT - Critical Issues Remaining

1. **[Current Status Summary](current_status_summary.md)** - Complete progress overview
   - 47% total error reduction achieved
   - Critical issues identified for next phase

2. **[Surveillance Dependencies](surveillance_prompt.md)** - 1 CRITICAL issue
   - Services module has 16 dependencies (max 15)
   - Must split into focused service modules

3. **[Duplicate Code](player_profile_prompt.md)** - 3 CRITICAL duplications
   - `calculate_current_metrics` duplicated in analyzer modules
   - 36 lines of duplicate code to extract

## Domain-Specific Error Categories (UPDATED)

1. **[Database Layer](database_layer_prompt.md)** - 50+ errors
   - Variable redeclaration, single-function pipelines, @impl annotations
   
2. **[Surveillance Context](surveillance_prompt.md)** - 30+ errors
   - **CRITICAL**: Excessive dependencies (16 > 15 limit)
   - Variable redeclaration, pipeline issues
   
3. **[Player Profile](player_profile_prompt.md)** - 40+ errors  
   - **CRITICAL**: Duplicate code between analyzers
   - Variable redeclaration, performance issues
   
4. **[Fleet Operations](fleet_operations_prompt.md)** - 25+ errors
   - Variable redeclaration in analysis modules
   - Pipeline and formatting issues
   
5. **[Wormhole Operations](wormhole_operations_prompt.md)** - 15+ errors
   - Variable redeclaration in recruitment vetter
   - Security analysis improvements
   
6. **[Infrastructure & Utilities](infrastructure_utilities_prompt.md)** - 200+ errors
   - Single-function pipelines, @impl annotations
   - Code formatting across utility modules
   
7. **[API Layer](api_layer_prompt.md)** - RESOLVED
   - Previous dependency issues have been fixed

## Implementation Priority

### **Phase 1: Critical Issues (Fix First)**
1. **Surveillance Live Dependencies** - Must fix 16 → ≤15 dependencies
2. **Player Profile Duplicate Code** - Eliminate code duplication between analyzers  
3. **Trailing Whitespace** - 624 instances (automated fix)

### **Phase 2: High Impact (Quick Wins)**  
1. **Single-Function Pipelines** - 233 instances (easy conversions)
2. **@impl Annotations** - 99 instances (add specific behavior names)
3. **Variable Redeclaration** - 106 instances (rename for clarity)

### **Phase 3: Organization & Polish**
1. **Alias Organization** - 261 instances (import cleanup)
2. **Number Formatting** - 46 instances (add underscores)
3. **File Endings** - 13 instances (add final newlines)

### **Phase 4: Feature Completion**
1. **TODO Comments** - 56 instances (implement security functions)

## Usage

Each prompt file contains:
- **Updated error counts** and current state
- **Specific AI assistant prompts** for each domain
- **Detailed implementation steps** with priority
- **Success criteria** and testing guidance

Use these prompts to systematically address code quality issues while maintaining all functionality. Start with Phase 1 critical issues for maximum impact.
