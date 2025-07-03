# EVE DMV - Comprehensive Manual Testing Plan

**Version**: Sprint 4.5 - ESI Integration  
**Date**: 2025-07-01  
**Environment**: http://localhost:4010  
**Project Status**: Phase 2.5 - Integration & Production Readiness

## Pre-Test Setup

### ✅ Environment Preparation
- [ ] Phoenix server running (`mix phx.server`)
- [ ] Database migrated (`mix ecto.migrate` or `mix ash_postgres.migrate`)
- [ ] Static data loaded (`mix eve.load_static_data`)
- [ ] Pipeline enabled (check `.env` file: `PIPELINE_ENABLED=true`)
- [ ] External APIs configured (EVE ESI, wanderer-kills, Janice, Mutamarket)
- [ ] Browser cache and cookies cleared

### 🚀 Test Data Generation (REQUIRED)
**Use the automated test data generator to prepare for manual testing:**

1. **Start Phoenix with interactive shell:**
   ```bash
   iex -S mix phx.server
   ```

2. **Load the data generator:**
   ```elixir
   Code.compile_file("manual_testing_data_generator.exs")
   ```

3. **Generate complete testing environment:**
   ```elixir
   ManualTestingDataGenerator.setup_complete_testing_environment()
   ```

This will:
- ✅ Check system status (database, pipeline, surveillance engine)
- ✅ Generate fresh test IDs from recent killmail data
- ✅ Create sample surveillance profile templates
- ✅ Print all test URLs organized by category
- ✅ Provide authentication and testing instructions

### ✅ Test Data Verification
- [ ] Test data generator completed successfully
- [ ] Recent killmail activity confirmed (> 0 killmails in last 10 minutes)
- [ ] Character, corporation, and alliance IDs collected
- [ ] Surveillance engine status verified
- [ ] Test URLs printed and ready for use

### 🔧 Additional Data Generator Commands
If you need fresh data during testing:

```elixir
# Check recent activity
ManualTestingDataGenerator.show_recent_activity(10)

# Get fresh test IDs
ManualTestingDataGenerator.get_fresh_test_ids()

# Check surveillance engine status
ManualTestingDataGenerator.check_surveillance_engine()

# Regenerate all test data
ManualTestingDataGenerator.generate_test_data()
```

---

## Test Suite 1: Public Pages & Basic Navigation

### 1.1 Home Page (`/`)
**Status**: Public access, no authentication required

- [ ] **Page loads successfully** - Clean landing page display
- [ ] **Navigation menu present** - All menu items visible and clickable
- [ ] **EVE SSO login button** - Prominent and functional
- [ ] **Responsive design** - Test mobile/tablet viewport
- [ ] **No console errors** - Check browser developer tools
- [ ] **Page performance** - Loads within 2 seconds

**Expected**: Professional landing page with clear navigation and login option

### 1.2 Kill Feed Page (`/feed`)
**Status**: Public access, real-time updates

- [ ] **Page loads with killmail data** - Shows recent EVE killmails
- [ ] **Real-time updates** - New kills appear automatically (wait 1-2 minutes)
- [ ] **Data formatting correct** - ISK values, timestamps, ship names
- [ ] **System names resolved** - Shows actual system names, not IDs
- [ ] **Character portraits** - EVE character images display correctly
- [ ] **Ship icons** - Proper ship type images
- [ ] **Time stamps** - "X minutes ago" format working
- [ ] **Kill details** - Each kill shows victim, attackers, system, value
- [ ] **Clickable elements** - Character names link to intelligence pages
- [ ] **Auto-scroll behavior** - Page handles new content gracefully
- [ ] **Mobile responsive** - Works on mobile devices

**Expected**: Live-updating feed with properly formatted EVE killmail data

---

## Test Suite 2: Authentication System

### 2.1 EVE SSO Login Flow
**Test Path**: Home → Login → EVE SSO → Callback → Dashboard

- [ ] **Login button redirect** - Clicking login redirects to EVE SSO
- [ ] **EVE SSO page loads** - CCP's OAuth page displays correctly
- [ ] **Character selection** - Can select EVE character to authenticate
- [ ] **Authorization flow** - Complete OAuth authorization
- [ ] **Successful callback** - Returns to EVE DMV with authentication
- [ ] **Session creation** - User session established correctly
- [ ] **Character data loaded** - EVE character name/corp displayed
- [ ] **Navigation updates** - User menu shows logged-in state
- [ ] **Dashboard redirect** - Redirected to dashboard after login

**Expected**: Complete OAuth flow with EVE Online integration

### 2.2 Session Management
- [ ] **Session persistence** - Login state survives page refresh
- [ ] **Multi-tab consistency** - Same login state across browser tabs
- [ ] **Logout functionality** - Sign out clears session
- [ ] **Protected route access** - Can access authenticated pages
- [ ] **Token expiration handling** - Graceful handling of expired tokens
- [ ] **Unauthorized redirect** - Unauthenticated users redirected to login

**Expected**: Robust session management with proper security

---

## Test Suite 3: Dashboard & User Profile

### 3.1 Dashboard Page (`/dashboard`)
**Status**: Requires authentication

- [ ] **Authentication check** - Redirects to login if not authenticated
- [ ] **User welcome message** - Shows EVE character information
- [ ] **Corporation/Alliance display** - Shows current affiliations
- [ ] **Killmail statistics** - Displays recent activity count
- [ ] **Recent kills section** - Shows user's recent killmail participation
- [ ] **Price monitor component** - Real-time price data display
- [ ] **Navigation links** - Quick access to other features
- [ ] **Real-time updates** - Updates with new activity

**Expected**: Personalized dashboard with user statistics and activity

### 3.2 User Profile Page (`/profile`)
**Status**: Requires authentication

- [ ] **Profile information** - EVE character details displayed
- [ ] **Account settings** - User preferences and options
- [ ] **Character data accuracy** - Correct EVE Online information
- [ ] **Navigation to other features** - Links to dashboard and feed work
- [ ] **Settings persistence** - Any changes save correctly

**Expected**: User account management with EVE character integration

---

## Test Suite 4: Character Intelligence System

### 4.1 Character Intelligence Page (`/intel/:character_id`)
**Status**: Requires authentication, hunter-focused analysis

Test with multiple character IDs from recent killmails:

- [ ] **Direct URL access** - Enter URL with character ID works
- [ ] **From kill feed navigation** - Click character name from feed
- [ ] **Character header display** - Name, corporation, alliance shown
- [ ] **EVE character portrait** - Official EVE image displayed
- [ ] **Multiple tabs interface** - All tabs load without errors
- [ ] **Data loading states** - Shows loading indicators appropriately
- [ ] **Error handling** - Invalid character IDs handled gracefully

#### 4.1.1 Overview Tab
- [ ] **Ship preferences** - Shows commonly used ships
- [ ] **Gang composition** - Displays typical fleet setups
- [ ] **Combat statistics** - Kill/death ratios and efficiency
- [ ] **Recent activity** - Latest killmail participation
- [ ] **Threat assessment** - Danger level indicators

#### 4.1.2 Ships Tab
- [ ] **Ship usage patterns** - Detailed ship preference analysis
- [ ] **Typical fits** - Common fitting patterns
- [ ] **Ship performance** - Effectiveness by ship type
- [ ] **Interactive elements** - Clickable ship types for details

#### 4.1.3 Gang Tab
- [ ] **Frequent associates** - Who they fly with regularly
- [ ] **Gang roles** - What role they typically fill
- [ ] **Fleet composition** - Common fleet makeups
- [ ] **Associate analysis** - Details on flying partners

#### 4.1.4 Geography Tab
- [ ] **Active regions** - Where they typically operate
- [ ] **System preferences** - Favorite hunting grounds
- [ ] **Route patterns** - Common travel patterns
- [ ] **Geographic heatmaps** - Visual activity display

#### 4.1.5 Targets Tab
- [ ] **Target preferences** - What they like to hunt
- [ ] **Engagement patterns** - How they choose fights
- [ ] **Success rates** - Effectiveness against different targets
- [ ] **Risk assessment** - How much risk they typically take

#### 4.1.6 Patterns Tab
- [ ] **Behavioral analysis** - Combat patterns and tendencies
- [ ] **Timing patterns** - When they're most active
- [ ] **Weaknesses identified** - Tactical vulnerabilities
- [ ] **Predictability metrics** - How predictable their behavior is

**Expected**: Comprehensive hunter-focused intelligence with actionable insights

### 4.2 Player Profile Page (`/player/:character_id`)
**Status**: Requires authentication, performance analytics focus

- [ ] **Profile header** - Character info with statistical overview
- [ ] **Generate stats functionality** - Creates/updates character statistics
- [ ] **ESI integration** - Real EVE character data integration
- [ ] **Performance metrics** - Kill/death ratios, ISK efficiency
- [ ] **Activity timeline** - Historical performance data
- [ ] **Ship performance breakdown** - Effectiveness by ship type
- [ ] **Solo vs gang analysis** - Performance by engagement type
- [ ] **Charts and visualizations** - Data presented clearly
- [ ] **Export functionality** - Data export options (if available)
- [ ] **Comparison features** - Relative performance indicators

**Expected**: Detailed performance analytics with accurate EVE data

---

## Test Suite 5: Corporation & Alliance Analytics

### 5.1 Corporation Page (`/corp/:corporation_id`)
**Status**: Requires authentication

Use corporation IDs from active characters in killmail feed:

- [ ] **Corporation header** - Name, ticker, member count
- [ ] **Member statistics** - Active member analysis
- [ ] **Corporation performance** - Aggregate metrics
- [ ] **Recent activity** - Corporation's recent killmails
- [ ] **Top pilots** - Most active/effective members
- [ ] **Activity indicators** - Recent activity per member
- [ ] **Member navigation** - Click members to view their profiles
- [ ] **Kill navigation** - Click kills for detailed view
- [ ] **Refresh functionality** - Manual data refresh
- [ ] **Time-based filtering** - Recent activity periods
- [ ] **Error handling** - Invalid corporation IDs handled gracefully

**Expected**: Corporation overview with member activity and performance tracking

### 5.2 Alliance Page (`/alliance/:alliance_id`)
**Status**: Requires authentication

- [ ] **Alliance header** - Name, ticker, corporation count
- [ ] **Member corporations** - List of corps in alliance
- [ ] **Alliance-wide statistics** - Aggregate performance data
- [ ] **Top pilots leaderboard** - Best performers across alliance
- [ ] **Activity trends** - Historical alliance activity
- [ ] **Performance metrics** - Kill/death ratios, ISK efficiency
- [ ] **Corporation comparison** - Performance comparison between corps
- [ ] **Navigation links** - Links to individual corporations
- [ ] **Data accuracy** - Correct alliance composition

**Expected**: Alliance-wide analytics with corporation comparison and leaderboards

---

## Test Suite 6: Surveillance System

### 6.1 Surveillance Page (`/surveillance`)
**Status**: Requires authentication, personal monitoring system

- [ ] **Authentication enforcement** - Redirects to login if not authenticated
- [ ] **Profile list display** - Shows user's existing surveillance profiles
- [ ] **Create profile interface** - Profile creation modal/form
- [ ] **Engine statistics** - Matching engine status and performance
- [ ] **Recent matches** - Displays recent profile matches with details
- [ ] **Notification system** - Real-time notifications for matches
- [ ] **Unread notification count** - Badge showing unread notifications

### 6.2 Profile Creation & Management
- [ ] **Create profile modal** - Opens when clicking "Create Profile"
- [ ] **Form validation** - Required fields and data validation
- [ ] **JSON filter rules** - Complex filter creation with valid JSON
- [ ] **Error handling** - Shows errors for invalid input
- [ ] **Profile saving** - Successfully creates and saves new profiles
- [ ] **Profile listing** - New profiles appear in list immediately
- [ ] **Profile activation** - Toggle profiles active/inactive
- [ ] **Profile editing** - Modify existing profiles
- [ ] **Profile deletion** - Remove profiles with confirmation
- [ ] **Auto-reload** - Matching engine reloads profiles automatically

#### 📋 Sample Surveillance Profiles for Testing
Use these pre-built profile configurations (generated by the test data generator):

**Profile 1: High Value Targets**
- Name: `High Value Targets`
- Description: `Tracks killmails with total value > 100M ISK`
- Filter JSON:
```json
{
  "condition": "and",
  "rules": [
    {
      "field": "total_value",
      "operator": "gt",
      "value": 100000000
    }
  ]
}
```

**Profile 2: Jita Activity Monitor**
- Name: `Jita Activity Monitor`
- Description: `Monitors all activity in Jita system`
- Filter JSON:
```json
{
  "condition": "and",
  "rules": [
    {
      "field": "solar_system_id",
      "operator": "eq",
      "value": 30000142
    }
  ]
}
```

**Profile 3: Capital Ship Kills**
- Name: `Capital Ship Kills`
- Description: `Tracks capital ship destructions`
- Filter JSON:
```json
{
  "condition": "and",
  "rules": [
    {
      "field": "ship_group_id",
      "operator": "in",
      "value": [547, 485, 513]
    }
  ]
}
```

### 6.3 Real-time Notifications
- [ ] **Live notifications** - New matches appear immediately
- [ ] **Notification details** - Rich killmail information in notifications
- [ ] **Priority indicators** - High/urgent notification styling
- [ ] **Mark as read** - Individual and bulk read actions
- [ ] **Notification persistence** - Notifications survive page refresh
- [ ] **Audio alerts** - Sound notifications (if enabled)
- [ ] **Visual indicators** - Clear unread/read status

**Expected**: Full surveillance profile management with real-time killmail matching

---

## Test Suite 7: Wormhole Features

### 7.1 Chain Intelligence Page (`/chain-intelligence` and `/chain-intelligence/:map_id`)
**Status**: Requires authentication, wormhole-specific

- [ ] **Page access** - Both general and map-specific URLs work
- [ ] **Wormhole chain topology** - Visual representation of chain structure
- [ ] **System inhabitant tracking** - Shows pilots in each system
- [ ] **Real-time updates** - Chain changes update automatically
- [ ] **Threat monitoring** - Hostile detection and alerts
- [ ] **Map integration** - Wanderer map integration (if configured)
- [ ] **System information** - Wormhole class, security status
- [ ] **Pilot intelligence** - Quick access to pilot information
- [ ] **Connection status** - Wormhole connection lifecycle tracking

### 7.2 Wormhole Vetting (`/wh-vetting`)
**Status**: Requires authentication, recruitment tool

- [ ] **Dashboard view** - Default tab view with overview
- [ ] **J-space experience assessment** - Wormhole activity analysis
- [ ] **Security risk evaluation** - Risk scoring for pilots
- [ ] **Eviction group detection** - Known hostile entity identification
- [ ] **Alt character analysis** - Related character detection
- [ ] **Small gang competency** - Combat effectiveness scoring
- [ ] **Multiple tabs interface** - Tabbed navigation works correctly
- [ ] **Character lookup** - Search and analyze specific characters
- [ ] **Vetting reports** - Comprehensive recruitment analysis

**Expected**: Specialized wormhole corporation recruitment and vetting tools

---

## Test Suite 8: Cross-Page Navigation & URL Handling

### 8.1 Navigation Flow Testing
- [ ] **Kill feed → Character intel** - Click character names from feed
- [ ] **Kill feed → Player profile** - Access player analytics
- [ ] **Character intel → Player profile** - Cross-navigation between views
- [ ] **Character intel → Corporation** - Click corporation links
- [ ] **Corporation → Member intel** - Click member names
- [ ] **Corporation → Alliance** - Navigation to parent alliance
- [ ] **Alliance → Corporation** - Navigate to member corporations
- [ ] **Back navigation** - Browser back button works correctly
- [ ] **Forward navigation** - Browser forward button works
- [ ] **Breadcrumb navigation** - Clear navigation path indicators

### 8.2 URL Handling & Error Management
- [ ] **Direct URL access** - All pages work with direct URLs
- [ ] **Bookmarkable URLs** - Pages can be bookmarked and revisited
- [ ] **Invalid character IDs** - Graceful error handling with user feedback
- [ ] **Non-existent corporations** - Appropriate error messages
- [ ] **Malformed URLs** - Redirect to safe pages or show errors
- [ ] **Authentication redirects** - Proper login flow for protected pages
- [ ] **Deep linking** - Direct links to tabs and specific content work
- [ ] **URL parameters** - Query parameters handled correctly

**Expected**: Seamless navigation with comprehensive error handling

---

## Test Suite 9: Real-Time Features & Performance

### 9.1 Live Updates & WebSocket Connectivity
- [ ] **Kill feed real-time** - New killmails appear automatically within 5 seconds
- [ ] **Surveillance alerts** - Real-time profile match notifications
- [ ] **Chain intelligence updates** - Live wormhole chain changes
- [ ] **Dashboard updates** - Real-time statistics refresh
- [ ] **WebSocket connection stability** - Check browser dev tools for stable connection
- [ ] **Connection recovery** - Reconnects after network interruption
- [ ] **Multi-tab consistency** - Updates across multiple open tabs

### 9.2 Performance Testing
- [ ] **Initial page load** - All pages load within 3 seconds
- [ ] **Real-time responsiveness** - Updates appear within 10 seconds of source
- [ ] **Memory usage** - No memory leaks during extended use (check dev tools)
- [ ] **CPU usage** - Reasonable resource consumption
- [ ] **Multiple tabs performance** - App works correctly in multiple browser tabs
- [ ] **Large dataset handling** - Performance with high-activity characters/corps
- [ ] **Concurrent user simulation** - Multiple browsers/incognito windows

**Expected**: Responsive real-time updates without performance degradation

---

## Test Suite 10: Error Handling & Edge Cases

### 10.1 Network & API Issues
- [ ] **Offline handling** - Graceful degradation when network is offline
- [ ] **ESI API failures** - Appropriate error messages for EVE API issues
- [ ] **wanderer-kills API failures** - Fallback behavior for external API issues
- [ ] **Database connection issues** - Error handling for database problems
- [ ] **Timeout handling** - Long-running requests handled appropriately
- [ ] **Rate limiting** - Proper handling of API rate limits
- [ ] **Partial data loading** - Graceful handling of incomplete data

### 10.2 Data Edge Cases
- [ ] **Empty datasets** - Handle characters/corporations with no data
- [ ] **New characters** - Characters with minimal EVE history
- [ ] **Invalid killmail data** - Graceful handling of malformed data
- [ ] **Missing character information** - Handle incomplete ESI data
- [ ] **Large activity datasets** - Performance with very active characters
- [ ] **Special characters** - Unicode names and descriptions
- [ ] **Null/undefined values** - Proper handling of missing data fields

### 10.3 Browser Compatibility
- [ ] **Chrome (latest)** - Full functionality verification
- [ ] **Firefox (latest)** - Full functionality verification
- [ ] **Safari (latest)** - Full functionality verification
- [ ] **Edge (latest)** - Full functionality verification
- [ ] **Mobile Chrome** - Responsive design functionality
- [ ] **Mobile Safari** - iOS compatibility
- [ ] **JavaScript disabled** - Graceful degradation where possible
- [ ] **Local storage disabled** - Functionality without browser storage

**Expected**: Robust error handling and broad browser compatibility

---

## Test Suite 11: Security & Data Privacy

### 11.1 Authentication & Authorization
- [ ] **Session security** - Sessions expire appropriately
- [ ] **CSRF protection** - Forms protected against CSRF attacks
- [ ] **Data isolation** - Users only see appropriate data
- [ ] **Protected route enforcement** - Authentication required where specified
- [ ] **Token handling** - Secure OAuth token management
- [ ] **Logout security** - Complete session cleanup on logout

### 11.2 Input Validation & Security
- [ ] **XSS prevention** - User input properly escaped in display
- [ ] **SQL injection protection** - Database queries properly parameterized (Ash handles this)
- [ ] **Input sanitization** - Form inputs validated and sanitized
- [ ] **Rate limiting** - API calls appropriately rate limited
- [ ] **Data validation** - Server-side validation of all inputs
- [ ] **Error message security** - No sensitive information in error messages

**Expected**: Secure application with proper access controls and data protection

---

## Test Suite 12: Integration Testing

### 12.1 External API Integration
- [ ] **EVE ESI integration** - Character, corporation, alliance data accuracy
- [ ] **wanderer-kills feed** - Real-time killmail ingestion
- [ ] **Janice API** - ISK value calculations accuracy
- [ ] **Mutamarket API** - Market price data integration
- [ ] **Static data consistency** - EVE universe data accuracy
- [ ] **API error handling** - Graceful handling of external API failures

### 12.2 Database Operations
- [ ] **Data persistence** - User data saves correctly
- [ ] **Data retrieval** - Queries return accurate results
- [ ] **Real-time subscriptions** - PubSub notifications work correctly
- [ ] **Data consistency** - No data corruption or loss
- [ ] **Migration compatibility** - Database schema is current
- [ ] **Performance** - Database queries execute efficiently

**Expected**: Reliable integration with all external services and data systems

---

## Bug Reporting Template

When issues are found, document them using this format:

### Bug Report #[NUMBER]

**Page/Feature**: _[Specific page or feature affected]_  
**Severity**: Critical / High / Medium / Low  
**Browser**: _[Browser version and OS]_  
**User Authentication**: Authenticated / Guest  
**Reproducible**: Always / Sometimes / Once  

**Steps to Reproduce**:
1. [First step]
2. [Second step]
3. [Third step]

**Expected Behavior**: 
[What should happen]

**Actual Behavior**: 
[What actually happens]

**Screenshots/Video**: 
[Attach visual evidence if applicable]

**Console Errors**: 
```
[Copy any JavaScript console errors]
```

**Server Logs**: 
```
[Copy any relevant server log entries]
```

**Additional Context**: 
[Any other relevant information]

---

## Test Results Summary

**Total Test Categories**: 12  
**Total Test Cases**: ~180  

### Completion Status
- [ ] **Test Suite 1**: Public Pages & Navigation ___/6
- [ ] **Test Suite 2**: Authentication System ___/15
- [ ] **Test Suite 3**: Dashboard & Profile ___/13
- [ ] **Test Suite 4**: Character Intelligence ___/30
- [ ] **Test Suite 5**: Corporation & Alliance ___/18
- [ ] **Test Suite 6**: Surveillance System ___/21
- [ ] **Test Suite 7**: Wormhole Features ___/17
- [ ] **Test Suite 8**: Navigation & URLs ___/17
- [ ] **Test Suite 9**: Real-time & Performance ___/13
- [ ] **Test Suite 10**: Error Handling ___/18
- [ ] **Test Suite 11**: Security ___/12
- [ ] **Test Suite 12**: Integration ___/12

### Issue Summary
**Critical Issues**: _____  
**High Priority Issues**: _____  
**Medium Priority Issues**: _____  
**Low Priority Issues**: _____

### Overall Assessment
- [ ] **Ready for production** - All critical functionality working
- [ ] **Minor fixes needed** - Small issues that don't block deployment
- [ ] **Major fixes required** - Significant issues need resolution
- [ ] **Significant rework needed** - Major functionality broken

### Recommendations
1. **Priority 1 (Critical)**: [List critical issues to fix immediately]
2. **Priority 2 (High)**: [List important issues for next sprint]
3. **Priority 3 (Medium)**: [List improvements for future releases]

**Tester**: _________________  
**Testing Environment**: _________________  
**Date Started**: _________________  
**Date Completed**: _________________  

---

*This comprehensive testing plan covers all functionality documented in the codebase and ensures thorough validation of the EVE DMV application before production deployment.*