# Credo Code Quality Fix Prompts

This directory contains AI assistant prompts for fixing code quality issues identified by Credo static analysis.

## Overview - COMPLETE REMAINING WORK SCOPE

- **Total Errors**: **925 errors** (reduced from 1,700+) - **47% improvement achieved**
- **MAJOR REMAINING WORK**: Single-function pipelines (223), trailing whitespace (220), alias organization (121), variable redeclaration (76), pipe chain structure (58)
- **Source**: Complete analysis after workstream completion - December 2024
- **Status**: Significant progress made, but substantial work remains across ALL categories

## COMPLETE REMAINING WORK - ALL CATEGORIES

### **🚀 AUTOMATED FIXES AVAILABLE (High Impact)**
1. **[Automated Fixes](automated_fixes_prompt.md)** - 440+ errors can be fixed automatically
   - **Trailing Whitespace**: 220 errors (mix format)
   - **Single-Function Pipelines**: 223 errors (semi-automated)
   - **Alias Organization**: 121 errors (scripted)
   - **Impact**: 53% error reduction possible with automation

### **📋 COMPLETE SCOPE**
2. **[Complete Remaining Work](complete_remaining_work.md)** - Full breakdown
   - 925 total errors across ALL categories and modules
   - Detailed implementation strategy by category

### **🔧 MANUAL FIXES REQUIRED**  
3. **Domain-Specific Issues** - Logic and architectural fixes:
   - **Variable Redeclaration**: 76 errors in analysis modules
   - **Pipe Chain Structure**: 58 errors in database/infrastructure  
   - **Dependencies & Duplicate Code**: Critical architectural issues

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
