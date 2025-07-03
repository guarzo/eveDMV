# TODO Items

This document tracks technical debt and future implementation tasks for the EVE DMV project.

## Intelligence System

### Corporation Intelligence Analysis
**Location**: `lib/eve_dmv/intelligence/correlation_engine.ex:139`  
**Task**: Implement corporation intelligence analysis when data is available  
**Details**: Currently returns placeholder data. Need to implement actual analysis of corporation members and patterns.

### Fleet Analysis Functions
**Location**: `lib/eve_dmv/intelligence/correlation_engine.ex:633`  
**Task**: Implement these functions when fleet analysis is ready  
**Details**: Several commented-out functions for ship progression consistency and behavioral analysis are waiting for fleet data integration.

### Employment Gap Detection
**Location**: `lib/eve_dmv/intelligence/wh_vetting_analyzer.ex:958`  
**Task**: Implement employment gap detection when ESI is available  
**Details**: Currently returns empty array for employment gaps. Need ESI integration to fetch employment history and detect suspicious gaps.

## API Infrastructure

### Fallback Controller
**Location**: `lib/eve_dmv_web/controllers/api/api_keys_controller.ex:14`  
**Task**: Create fallback controller  
**Details**: API controller is missing fallback error handling. Need to implement `EveDmvWeb.FallbackController` for consistent API error responses.

## Priority

- **High Priority**: Fallback Controller (affects API reliability)
- **Medium Priority**: Employment Gap Detection (security feature)
- **Low Priority**: Corporation Intelligence Analysis, Fleet Analysis Functions (enhancement features)