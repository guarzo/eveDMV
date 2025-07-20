# Placeholder Cleanup Sprint Series

*Created: 2025-07-18*

## Overview

This document outlines a 6-sprint series (12 weeks) to systematically remove all placeholder implementations and achieve a clean codebase that adheres to our "Clean Codebase Vision".

## Sprint Series Summary

### Phase 1: Foundation (Sprints 18-19)
Fix core dependencies that other features rely on.

**Sprint 18: Foundation Cleanup - Ship Classification & Static Data**
- Duration: 2 weeks
- Focus: Replace all modulo-based ship classification with static data queries
- Critical: Unblocks fleet analysis, wormhole mass calculations, battle analysis

**Sprint 19: Character Intelligence Cleanup**
- Duration: 2 weeks  
- Focus: Implement ship/weapon preferences, activity patterns
- Impact: Complete the character analysis features

### Phase 2: Core Features (Sprints 20-21)
Complete partially implemented features.

**Sprint 20: Battle Analysis Completion**
- Duration: 2 weeks
- Focus: Implement battle phases, tactical analysis, doctrine detection
- Impact: Turn battle detection into full battle intelligence

**Sprint 21: Fleet Operations Cleanup**
- Duration: 2 weeks
- Focus: Real DPS/EHP calculations, role detection, composition analysis
- Dependencies: Requires Sprint 18 completion

### Phase 3: Advanced Features (Sprint 22)
Clean up the most complex features.

**Sprint 22: Wormhole Operations Cleanup**
- Duration: 2 weeks
- Focus: Remove all random data, implement real chain tracking
- Dependencies: Requires Sprint 18 & 21 completion

### Phase 4: Final Validation (Sprint 23)
Ensure everything works together.

**Sprint 23: Final Cleanup & Validation**
- Duration: 2 weeks
- Focus: Remove any remaining stubs, comprehensive testing, documentation
- Deliverable: Clean codebase with zero placeholders

## Success Metrics

By the end of this series:
- 0 functions returning empty arrays/maps as placeholders
- 0 instances of random data generation in production
- 0 hardcoded "magic" numbers for calculations
- 100% of ship/system lookups using static data
- All features either work with real data or have been removed

## Risk Mitigation

1. **Incremental Approach**: Each sprint delivers working features
2. **Dependency Management**: Foundation work comes first
3. **Testing Focus**: Every change validated before moving forward
4. **Regular Validation**: Placeholder detection checks run weekly
5. **Scope Control**: Features that can't be implemented are deleted, not stubbed

## Sprint Capacity Planning

Based on the cleanup plan analysis:
- Average sprint capacity: 40-50 story points
- Cleanup work: ~60% of capacity
- New features/bugs: ~40% of capacity
- Each cleanup task estimated at 3-8 points

## Communication Plan

- Sprint kickoff: Review specific files/functions to clean
- Daily standups: Report on placeholders removed
- Mid-sprint: Run placeholder detection checks
- Sprint review: Demo real data flowing through cleaned features
- Retrospective: Assess cleanup velocity and adjust

## Definition of Success

After Sprint 23, running our placeholder detection commands should return:
```bash
$ grep -r "def.*do\s*\[\]\s*end" lib/
# No results

$ grep -r "Enum.random" lib/ | grep -v test/
# No results

$ grep -r "% 10.*ship" lib/
# No results
```

And every feature in the app will either:
1. Work with real data from the database
2. Not exist at all

No middle ground. No lies. No placeholders.