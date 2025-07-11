# Sprint 8 Deep Analytics Manual Validation Checklist

## Overview
This checklist validates the sophisticated analytics algorithms implemented in Sprint 8. Each feature should be tested with real data to ensure the algorithms work correctly and provide meaningful insights.

## Pre-Validation Setup
- [ ] Ensure Phoenix server is running (`mix phx.server`)
- [ ] Verify you have recent killmail data in the database
- [ ] Have zkillboard URLs ready for testing imports

## DEEP-1: Advanced Battle Analysis with Multi-System Tracking

### 1. Battle Detection & Loading
- [ ] Navigate to `/battle` (Battle Analysis page)
- [ ] Click "Import from zkillboard" and paste a battle URL (e.g., `https://zkillboard.com/kill/128431979/`)
- [ ] Verify the battle loads with all related kills (not just the single kill)
- [ ] Confirm battle duration shows realistic time (not just "1 minute" for multi-kill battles)
- [ ] Check that all participating ships are displayed

### 2. Tactical Phase Detection
- [ ] Click on the "Timeline" tab in battle analysis
- [ ] Verify tactical phases are detected:
  - Setup phase (low damage, positioning)
  - Engagement phase (high damage, ship losses)
  - Resolution phase (cleanup, looting)
- [ ] Confirm phase characteristics show meaningful descriptions (not just raw data)
- [ ] Check that phase transitions make sense chronologically

### 3. Recently Viewed Battles
- [ ] After viewing a battle, check "Recently Viewed" section
- [ ] Click on a recently viewed battle
- [ ] Verify it loads correctly (even if timestamps don't match exactly)
- [ ] Confirm battle data displays properly

### 4. Multi-System Battle Correlation
- [ ] For battles with participants that fought in multiple systems:
  - Check if related battles are identified
  - Verify participant overlap percentage is calculated
  - Confirm system connections are analyzed

## DEEP-2: Character Threat Intelligence System

### 1. Ship Performance Analysis
- [ ] In battle analysis, click "Intelligence" tab
- [ ] Verify ship performance metrics show:
  - DPS efficiency ratings
  - Survivability scores
  - Tactical contribution metrics
- [ ] Check that top performers are identified correctly
- [ ] Confirm fleet statistics are calculated (average DPS, total damage, etc.)

### 2. Character Analysis
- [ ] Verify character names are resolved correctly (not showing IDs)
- [ ] Check that NPC/structure kills don't crash the analysis
- [ ] Confirm character performance metrics are realistic

## DEEP-3: Corporation Intelligence with Combat Analysis

### 1. Corporation Statistics
- [ ] In battle analysis, check corporation breakdown
- [ ] Verify unique corporations and alliances are counted
- [ ] Confirm corporation-level metrics are aggregated

### 2. Combat Doctrine Recognition
- [ ] For fleet battles, check if combat doctrines are identified:
  - Shield kiting fleets
  - Armor brawling fleets
  - EWAR heavy compositions
- [ ] Verify ship type groupings make sense

## DEEP-4: Battle Sharing & Community Curation

### 1. Battle Import Enhancement
- [ ] Test importing various zkillboard URLs:
  - Single kill: `https://zkillboard.com/kill/[id]/`
  - Related kills: `https://zkillboard.com/related/[system]/[time]/`
  - Character kills: `https://zkillboard.com/character/[id]/`
- [ ] Verify all formats import successfully
- [ ] Confirm related kills are automatically fetched for single kill imports

## DEEP-5: Intelligence Infrastructure Enhancement

### 1. Algorithm Validation
- [ ] Verify k-means clustering works for tactical phases
- [ ] Check multi-dimensional scoring produces reasonable threat scores
- [ ] Confirm pattern recognition identifies meaningful patterns

### 2. Performance & Stability
- [ ] Test with large battles (50+ participants)
- [ ] Verify no crashes when data is missing or incomplete
- [ ] Check that analyses complete in reasonable time

## Edge Cases & Error Handling

### 1. Data Quality Issues
- [ ] Test with battles containing NPCs (nil character_ids)
- [ ] Import battles with missing victim data
- [ ] Try battles with only one participant
- [ ] Test with battles spanning multiple hours

### 2. Import Resilience
- [ ] Try importing non-existent zkillboard URLs
- [ ] Test with malformed URLs
- [ ] Import very old battles
- [ ] Import battles already in the database

## Integration Validation

### 1. Context Integration (DEEP-6)
- [ ] Verify BattleAnalysis context properly calls:
  - `MultiSystemBattleCorrelator`
  - `TacticalPhaseDetector`
  - `ShipPerformanceAnalyzer`
- [ ] Check that intelligence data flows to LiveView correctly

### 2. Data Consistency
- [ ] Verify battle IDs remain consistent across views
- [ ] Check that refreshing doesn't lose battle data
- [ ] Confirm navigation between battles works smoothly

## Known Issues to Verify Fixed

### 1. Previous Sprint 8 Bugs
- [ ] Battle analysis page loads without crashes
- [ ] Intelligence tab displays correct character data (not wrong participants)
- [ ] Type mismatches between maps and lists are resolved
- [ ] ETS table initialization works properly
- [ ] Template rendering doesn't crash on complex data structures

### 2. Battle ID Matching
- [ ] Recently viewed battles load when clicked
- [ ] Battles with similar timestamps in same system are matched correctly
- [ ] 10-minute tolerance window works for timestamp differences

## Performance Metrics

### 1. Load Times
- [ ] Battle analysis loads in < 3 seconds
- [ ] Intelligence calculations complete in < 2 seconds
- [ ] Large battle analysis doesn't timeout

### 2. Accuracy
- [ ] Tactical phases align with actual battle flow
- [ ] Ship performance metrics seem reasonable
- [ ] Character threat scores reflect actual performance

## Final Validation

### 1. User Experience
- [ ] All tabs in battle analysis work without errors
- [ ] Data displays are meaningful and readable
- [ ] No placeholder or mock data visible
- [ ] Error messages are helpful when things go wrong

### 2. Algorithm Sophistication
- [ ] Verify algorithms provide insights beyond simple calculations
- [ ] Check that patterns and correlations are meaningful
- [ ] Confirm the system provides value for wormhole PvP analysis

## Sign-off Checklist

- [ ] All core features tested and working
- [ ] No critical bugs discovered
- [ ] Performance is acceptable
- [ ] Algorithms produce meaningful results
- [ ] Ready for production use

**Tester**: _____________________
**Date**: _____________________
**Overall Result**: PASS / FAIL
**Notes**: _____________________