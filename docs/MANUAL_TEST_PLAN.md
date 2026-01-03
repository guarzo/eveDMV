# EVE DMV Manual Test Plan

**Version**: 1.0
**Date**: December 27, 2025
**Based on**: PRD Version 5.2

---

## Overview

This document provides a comprehensive manual test plan for EVE DMV, covering all production features documented in the PRD. Each test case includes steps, expected results, and space to document issues found.

---

## Prerequisites

Before testing, ensure:
1. Application is running (`mix phx.server` or `iex -S mix phx.server`)
2. Database is seeded with test data
3. EVE SSO credentials are configured (for authentication tests)
4. Broadway pipeline is enabled (`PIPELINE_ENABLED=true`)
5. Access to at least one EVE Online character for SSO testing

---

## Test Sections

1. [Authentication & User Management](#1-authentication--user-management)
2. [Live Kill Feed](#2-live-kill-feed)
3. [Character Intelligence](#3-character-intelligence)
4. [Battle Analysis](#4-battle-analysis)
5. [Fleet Operations](#5-fleet-operations)
6. [System Activity Analytics](#6-system-activity-analytics)
7. [Surveillance Profiles](#7-surveillance-profiles)
8. [Corporation Intelligence](#8-corporation-intelligence)
9. [Universal Search](#9-universal-search)
10. [API Endpoints](#10-api-endpoints)
11. [Admin Features](#11-admin-features)
12. [Performance & Real-time Updates](#12-performance--real-time-updates)

---

## 1. Authentication & User Management

### 1.1 EVE SSO Login

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/` (home page) | Home page loads with "Sign in with EVE" button visible |
| 2 | Click "Sign in with EVE" button | Redirected to EVE Online SSO login page |
| 3 | Authenticate with EVE credentials | Redirected back to EVE DMV |
| 4 | Observe the UI after redirect | User is logged in, character name/portrait displayed |
| 5 | Check session persistence | Refresh page - user remains logged in |

**Issues Found:**
- [ ] _None yet_

---

### 1.2 Multi-Character Support

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Log in with first EVE character | Account created with first character |
| 2 | Click "Add Character" or similar option | EVE SSO login page appears |
| 3 | Log in with different EVE character | Second character added to same account |
| 4 | View account settings/profile | Both characters listed |
| 5 | Verify character count | Shows "2 characters" or similar |

**Issues Found:**
- [x] **ISSUE-001**: "Add Another Character" button returned 404 Not Found - URL was `/auth/eve_sso` but should be `/auth/user/eve_sso`. **FIXED** in `character_switcher.ex` and `character_switcher_live.ex`
- [x] **ISSUE-002**: Adding a character created a new account instead of linking to existing account. The `link_to_account` parameter wasn't being processed. **FIXED** by:
  - Created `LinkToAccountPlug` to capture intent in session before OAuth redirect
  - Updated `AuthController.success/4` to check session for link flag and call `AccountManager.link_character_to_account/2`
  - Fixed plug to only check initial request path (not callback) to preserve session flag
  - Added handling for characters already linked to different accounts via `AccountManager.relink_character_to_account/2`
- [x] **ISSUE-003**: Profile page only showed current character, not all account characters. **FIXED** by adding "Account Characters" section to `profile_live.ex` that displays all characters with switch buttons.

---

### 1.3 Character Switching

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | With multiple characters, find character switcher | Character switcher UI element visible |
| 2 | Click on alternate character | UI updates to show new character context |
| 3 | Navigate to authenticated page | Data shown is for switched character |
| 4 | Set a character as primary | Primary character indicator updates |
| 5 | Log out and log back in | Primary character is default selection |

**Issues Found:**
- [ ] _None yet_

---

### 1.4 Logout

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | While logged in, find logout button | Logout option visible |
| 2 | Click logout | Session ends, redirected to home/login |
| 3 | Try to access authenticated route | Redirected to login or shown error |

**Issues Found:**
- [ ] _None yet_

---

## 2. Live Kill Feed

### 2.1 Real-time Kill Feed Display

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/feed` | Kill feed page loads |
| 2 | Observe killmail cards | Killmails display with ship icon, victim name, location |
| 3 | Wait for new killmails (if pipeline active) | New kills appear at top without refresh |
| 4 | Check killmail details | Each kill shows: ship type, ISK value, system, time |
| 5 | Verify no placeholder data | All data appears real (no "Test Kill" or random values) |

**Issues Found:**
- [x] **ISSUE-007**: All kills showed "Unknown Corp" for victim corporation. The raw killmail data from wanderer-kills contains `corporation_id` but not `corporation_name`. **FIXED** by:
  - Added corporation ID extraction and batch preloading via `NameResolver.corporation_names()` in `preload_raw_killmail_names/1`
  - Updated `build_killmail_from_raw/1` to resolve corporation names via `NameResolver.corporation_name()` when not provided
  - Updated `build_killmail_display/1` (for real-time SSE) with same resolution logic
  - Added `resolve_corporation_name/1` helper function

---

### 2.2 Kill Feed Filtering

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open filter panel on kill feed | Filter options visible |
| 2 | Filter by minimum ISK value (e.g., 100M) | Only kills >= 100M ISK shown |
| 3 | Filter by ship type | Only matching ship types shown |
| 4 | Filter by solar system | Only kills in that system shown |
| 5 | Filter by alliance | Only kills involving that alliance shown |
| 6 | Clear all filters | Full kill feed returns |
| 7 | Combine multiple filters | Filters work together correctly |

**Issues Found:**
- [ ] _None yet_

---

### 2.3 Infinite Scroll / Pagination

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Load kill feed with many kills | Initial batch loads (50 items) |
| 2 | Scroll to bottom of list | "Load more" or auto-load triggers |
| 3 | Additional kills load | More kills appended to list |
| 4 | Continue scrolling | Pagination continues working |
| 5 | Check for duplicate kills | No duplicate entries in list |

**Issues Found:**
- [ ] _None yet_

---

### 2.4 Optimized Kill Feed (`/feed` with high volume)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to optimized feed view | Page loads with virtualized list |
| 2 | Scroll rapidly through large dataset | No lag or stuttering |
| 3 | Apply filters | Filters apply quickly |
| 4 | Check memory usage (dev tools) | Memory remains stable |

**Issues Found:**
- [ ] _None yet_

---

## 3. Character Intelligence

### 3.1 Character Analysis Page

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/character/:id` (valid character) | Character intelligence page loads |
| 2 | Check threat score display | Threat score shown (0-100 scale) |
| 3 | Verify threat breakdown | Component scores visible (combat, ship mastery, etc.) |
| 4 | Check ship preferences | Ship usage statistics displayed |
| 5 | Verify activity patterns | Temporal activity data shown |
| 6 | Check gang size analysis | Solo vs fleet participation shown |

**Issues Found:**
- [ ] _None yet_

---

### 3.2 Threat Scoring Accuracy

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View character with known high activity | High threat score displayed |
| 2 | Check score breakdown values | Values are reasonable (not 0.5 placeholders) |
| 3 | Verify ship classification | Ships classified correctly by role |
| 4 | Check ISK efficiency calculation | Efficiency based on actual K/D ISK |
| 5 | Verify no hardcoded values | Scores change based on actual data |

**Issues Found:**
- [ ] _None yet_

---

### 3.3 Character Comparison

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to character comparison page | Comparison UI loads |
| 2 | Add first character | Character data loads |
| 3 | Add second character | Side-by-side comparison shows |
| 4 | Compare threat scores | Scores displayed for both |
| 5 | Compare ship preferences | Ship usage compared |
| 6 | Add up to 10 characters | System handles multiple characters |

**Issues Found:**
- [ ] _None yet_

---

### 3.4 Gang Synergy Analysis

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View character who flies in groups | Gang synergy section visible |
| 2 | Check coordination score | Score based on real fleet data |
| 3 | View frequent fleet mates | Actual character names shown |
| 4 | Check fleet role analysis | Role detection based on ships flown |

**Issues Found:**
- [ ] _None yet_

---

## 4. Battle Analysis

### 4.1 Battle List/Detection

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/battle` | Battle analysis page loads |
| 2 | View list of detected battles | Battles listed with timestamps |
| 3 | Check battle clustering | Related kills grouped together |
| 4 | Verify battle metadata | System, time, participant count shown |

**Issues Found:**
- [ ] _None yet_

---

### 4.2 Battle Detail View

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click on a battle | Battle detail page loads |
| 2 | View timeline reconstruction | Events shown chronologically |
| 3 | Check side determination | Attackers vs defenders identified |
| 4 | View participant list | All participants shown with roles |
| 5 | Check ISK efficiency | ISK destroyed/lost calculated |
| 6 | View fleet composition | Ship types on each side shown |

**Issues Found:**
- [ ] _None yet_

---

### 4.3 Multi-System Battle Detection

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Find battle spanning multiple systems | Multi-system indicator visible |
| 2 | View system correlation | Related systems shown |
| 3 | Check timeline across systems | Events from all systems in timeline |

**Issues Found:**
- [ ] _None yet_

---

### 4.4 Battle Sharing

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View battle detail | Share button visible |
| 2 | Click share button | Share link generated |
| 3 | Copy share link | Link copied to clipboard |
| 4 | Open link in incognito/new browser | Battle report accessible |
| 5 | Rate a shared battle | Rating submitted successfully |

**Issues Found:**
- [ ] _None yet_

---

## 5. Fleet Operations

### 5.1 Fleet Composition Analysis

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/fleet` | Fleet operations page loads |
| 2 | Input pilot names or paste fleet data | Fleet data accepted |
| 3 | View composition breakdown | Ships categorized by role |
| 4 | Check role distribution | DPS, logi, tackle, etc. shown |
| 5 | View fleet balance assessment | Balance recommendations given |

**Issues Found:**
- [ ] _None yet_

---

### 5.2 Fleet Statistics

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View fleet with ship data | Statistics section visible |
| 2 | Check total DPS estimate | DPS calculated from ship types |
| 3 | Check total EHP estimate | EHP calculated from ship types |
| 4 | Check mass calculations | Mass calculated using EVE static data |
| 5 | Verify no hardcoded values | Stats based on actual ship attributes |

**Issues Found:**
- [ ] _None yet_

---

### 5.3 Fleet Recommendations

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View fleet composition | Recommendations section visible |
| 2 | Check for balance suggestions | Suggestions for missing roles |
| 3 | View doctrine compliance | Compliance percentage if doctrine set |

**Issues Found:**
- [ ] _None yet_

---

## 6. System Activity Analytics

### 6.1 System Detail Page

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/system/:id` | System page loads |
| 2 | View system information | Name, security status, region shown |
| 3 | Check activity statistics | Kill counts, ISK destroyed shown |
| 4 | View danger assessment | Danger score (0-100) displayed |
| 5 | Check alliance presence | Active alliances in system listed |
| 6 | Check wormhole classification | J-space systems show "wormhole" not "nullsec" |
| 7 | View recent kills section | Recent kills displayed prominently |
| 8 | Click on stat cards | Detail panel shows kills/pilots/corps |
| 9 | Check structure kills | Structure kills shown at bottom |

**Issues Found:**
- [x] **ISSUE-008**: Wormhole systems (J-space) were showing as "nullsec" instead of "wormhole". **FIXED** by:
  - Added `is_wormhole_system?/1` helper in `StaticDataCache` to detect J-space systems by ID range (31000000-31999999)
  - Updated `determine_security_class/1` to check for wormholes before using database value
  - Updated `SystemLive` to use `NameResolver.system_security()` for corrected security class
- [x] **ISSUE-009**: System page lacked prominent recent kills display. **FIXED** by:
  - Added `get_recent_kills/1` function to fetch last 7 days of kills
  - Added prominent "Recent Kills" section after activity stats
  - Separated ship kills from structure kills in display
- [x] **ISSUE-010**: Structure/citadel kills were not clearly organized. **FIXED** by:
  - Moved structure kills section to bottom of page
  - Added detection for structure kills via `is_structure_kill?/2`
  - Shows both aggregated structure types and recent structure kills
- [x] **ISSUE-011**: Stats cards not interactive. **FIXED** by:
  - Made Total Kills, Unique Pilots, and Corporations cards clickable
  - Added detail panel that shows expanded list when clicking stats
  - Panel replaces the quick overview section with detailed breakdowns
- [x] **ISSUE-012**: System page crashed with `FunctionClauseError` when displaying recent kills. **FIXED** by:
  - Added `NaiveDateTime` handling to `format_relative_time/1` in `TimeFormatter`
  - SQL query returns `NaiveDateTime` which is now converted to `DateTime` for formatting

---

### 6.2 Activity Heatmap

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View system with activity | 24-hour heatmap visible |
| 2 | Check heatmap data | Hours with activity highlighted |
| 3 | Hover over heatmap cells | Tooltip shows activity details |
| 4 | Verify timezone inference | Peak activity times identified |

**Issues Found:**
- [ ] _None yet_

---

### 6.3 Regional Correlation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View system in active region | Regional tab/section visible |
| 2 | Check correlated systems | Nearby systems with activity shown |
| 3 | View activity spillover | Cross-system activity patterns visible |

**Issues Found:**
- [ ] _None yet_

---

## 7. Surveillance Profiles

### 7.1 Profile CRUD Operations

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/surveillance-profiles` | Profile list loads |
| 2 | Click "Create Profile" | Profile creation form opens |
| 3 | Enter profile name and basic criteria | Form accepts input |
| 4 | Save profile | Profile appears in list |
| 5 | Edit existing profile | Edit form opens with current data |
| 6 | Update profile | Changes saved successfully |
| 7 | Delete profile | Profile removed from list |

**Issues Found:**
- [ ] _None yet_

---

### 7.2 Filter Builder

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create new profile | Filter builder visible |
| 2 | Add character filter | Character search/autocomplete works |
| 3 | Add ISK range filter | Min/max ISK inputs work |
| 4 | Add temporal filter | Time of day selection works |
| 5 | Add system filter | System search works |
| 6 | Add nested group (AND/OR) | Nested conditions supported |
| 7 | Combine multiple filter types | Complex criteria saved |

**Issues Found:**
- [ ] _None yet_

---

### 7.3 Real-time Matching

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enable a surveillance profile | Profile shows as active |
| 2 | Wait for matching killmail | Alert triggers when criteria met |
| 3 | Navigate to `/surveillance-alerts` | Alert visible in list |
| 4 | Check alert details | Matched killmail info shown |
| 5 | Test with live preview | Preview shows matching kills |

**Issues Found:**
- [ ] _None yet_

---

### 7.4 Profile Toggle and Management

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Toggle profile enable/disable | Status changes immediately |
| 2 | Disabled profile doesn't match | No alerts from disabled profile |
| 3 | Re-enable profile | Matching resumes |

**Issues Found:**
- [ ] _None yet_

---

## 8. Corporation Intelligence

### 8.1 Corporation Detail Page

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/corporation/:id` | Corporation page loads |
| 2 | View corporation overview | Name, ticker, member count shown |
| 3 | Check activity statistics | PvP metrics displayed |
| 4 | View member list | Members shown with pagination |
| 5 | Check timezone analysis | Peak activity times shown |

**Issues Found:**
- [ ] _None yet_

---

### 8.2 Doctrine Analysis

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View corporation with PvP history | Doctrine section visible |
| 2 | Check detected doctrines | Common fleet compositions shown |
| 3 | View ship preferences | Most used ship types listed |
| 4 | Check doctrine descriptions | Meaningful descriptions (not placeholders) |

**Issues Found:**
- [ ] _None yet_

---

### 8.3 Member Performance

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View member list | Performance metrics visible |
| 2 | Check individual member stats | Kill/death counts, efficiency shown |
| 3 | Sort by different metrics | Sorting works correctly |
| 4 | Click member to view detail | Links to character page |

**Issues Found:**
- [ ] _None yet_

---

## 9. Universal Search

### 9.1 Search Functionality

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/search` or use search bar | Search UI visible |
| 2 | Type character name (2+ chars) | Autocomplete results appear |
| 3 | Search for corporation | Corporation results shown |
| 4 | Search for solar system | System results shown |
| 5 | Click on result | Navigates to correct detail page |

**Issues Found:**
- [ ] _None yet_

---

### 9.2 Search Categories

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Search ambiguous term | Results categorized (Character, Corp, System) |
| 2 | Check category labels | Clear indication of result type |
| 3 | Verify result ranking | More active entities ranked higher |

**Issues Found:**
- [ ] _None yet_

---

### 9.3 Keyboard Navigation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Type in search box | Results appear |
| 2 | Press down arrow | Selection moves down |
| 3 | Press up arrow | Selection moves up |
| 4 | Press Enter | Selected result opens |
| 5 | Press Escape | Search closes/clears |

**Issues Found:**
- [ ] _None yet_

---

## 10. API Endpoints

### 10.1 API Key Management

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to API key management (profile/settings) | API key section visible |
| 2 | Create new API key | Key generated and displayed once |
| 3 | Copy API key | Key copied to clipboard |
| 4 | List API keys | Keys shown (values hidden) |
| 5 | Delete API key | Key removed from list |

**Issues Found:**
- [ ] _None yet_

---

### 10.2 Battle Intelligence API

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | GET `/api/v1/battles/:id/intelligence` | Battle intelligence JSON returned |
| 2 | GET `/api/v1/battles/:id/multi_system` | Multi-system data returned |
| 3 | POST `/api/v1/battles/:id/share` | Share URL returned |
| 4 | POST `/api/v1/battles/:id/rate` | Rating accepted |
| 5 | Test with invalid battle ID | 404 error returned |

**Issues Found:**
- [ ] _None yet_

---

### 10.3 Character Intelligence API

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | GET `/api/v1/characters/:id/threat_score` | Threat score JSON returned |
| 2 | GET `/api/v1/characters/:id/behavioral_patterns` | Patterns JSON returned |
| 3 | Test with invalid character ID | Appropriate error returned |
| 4 | Verify response structure | All expected fields present |

**Issues Found:**
- [ ] _None yet_

---

### 10.4 Corporation Intelligence API

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | GET `/api/v1/corporations/:id/doctrine_analysis` | Doctrine JSON returned |
| 2 | GET `/api/v1/corporations/:id/threat_assessment` | Assessment JSON returned |
| 3 | Test with invalid corporation ID | Appropriate error returned |

**Issues Found:**
- [ ] _None yet_

---

## 11. Admin Features

### 11.1 Performance Dashboard

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Log in as admin user | Admin menu visible |
| 2 | Navigate to `/admin/performance` | Performance dashboard loads |
| 3 | View system metrics | CPU, memory, cache stats shown |
| 4 | Check cache hit rate | Real percentage (not placeholder) |
| 5 | View query performance | Slow queries identified |

**Issues Found:**
- [ ] _None yet_

---

### 11.2 User Management (if applicable)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to admin user section | User list visible |
| 2 | View user details | User info displayed |
| 3 | Check admin controls | Appropriate actions available |

**Issues Found:**
- [ ] _None yet_

---

## 12. Performance & Real-time Updates

### 12.1 Real-time PubSub Updates

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open kill feed in one tab | Feed visible |
| 2 | Open same feed in another tab | Both tabs show same data |
| 3 | Wait for new kill (or trigger test) | Both tabs update simultaneously |
| 4 | Check surveillance alerts | Real-time alert notifications work |

**Issues Found:**
- [ ] _None yet_

---

### 12.2 Page Load Performance

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Time home page load | < 2 seconds |
| 2 | Time kill feed initial load | < 2 seconds |
| 3 | Time character page load | < 2 seconds |
| 4 | Time battle detail load | < 3 seconds |
| 5 | Check for loading indicators | Proper loading states shown |

**Issues Found:**
- [ ] _None yet_

---

### 12.3 Error Handling

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to invalid character ID | Graceful error message |
| 2 | Navigate to invalid system ID | Graceful error message |
| 3 | Navigate to non-existent route | 404 page shown |
| 4 | Test with network interruption | Reconnection handling |

**Issues Found:**
- [ ] _None yet_

---

## Issues Summary

### Critical Issues
_Issues that block core functionality_

| ID | Section | Description | Status |
|----|---------|-------------|--------|
| ISSUE-001 | 1.2 Multi-Character | "Add Another Character" button 404 - wrong URL path | FIXED |
| ISSUE-002 | 1.2 Multi-Character | New character creates separate account instead of linking | FIXED |
| ISSUE-003 | 1.2 Multi-Character | Profile page only shows single character | FIXED |

### High Priority Issues
_Issues that significantly impact user experience_

| ID | Section | Description | Status |
|----|---------|-------------|--------|
| ISSUE-004 | 1.1 Auth | TokenRefreshPlug timeout blocks page access | FIXED |
| ISSUE-005 | 1.3 Switch | TokenRefreshService crashes with Ash.Changeset bug | FIXED |
| ISSUE-006 | 1.4 Logout | Sign out link uses wrong URL (underscore vs hyphen) | FIXED |

### Medium Priority Issues
_Issues that cause inconvenience but have workarounds_

| ID | Section | Description | Status |
|----|---------|-------------|--------|
| ISSUE-007 | 2.1 Kill Feed | All kills showed "Unknown Corp" - corporation names not being resolved | FIXED |
| ISSUE-008 | 6.1 System | Wormhole systems (J-space) showing as "nullsec" instead of "wormhole" | FIXED |
| ISSUE-009 | 6.1 System | System page lacked prominent recent kills display | FIXED |
| ISSUE-010 | 6.1 System | Structure/citadel kills not clearly organized | FIXED |
| ISSUE-011 | 6.1 System | Stats cards (kills, pilots, corps) not interactive | FIXED |
| ISSUE-012 | 6.1 System | System page crashed with NaiveDateTime in format_relative_time | FIXED |

### Low Priority Issues
_Minor issues, cosmetic problems, or nice-to-haves_

| ID | Section | Description | Status |
|----|---------|-------------|--------|
| - | - | _None found yet_ | - |

---

## Test Execution Log

| Date | Tester | Sections Tested | Issues Found | Notes |
|------|--------|-----------------|--------------|-------|
| _YYYY-MM-DD_ | _Name_ | _1.1, 1.2, ..._ | _0_ | _Initial run_ |

---

## Notes

- This test plan covers UI functionality. For API testing, use tools like `curl`, Postman, or similar.
- Some tests require the Broadway pipeline to be active for real-time data.
- Character/Corporation/System IDs can be obtained from the EVE Online ESI or from existing database records.
- Admin tests require an account with admin privileges.

---

**Document maintained by**: EVE DMV Development Team
**Last updated**: December 27, 2025
