# Sprint 2: Technical Debt, UI Polish & PvP Analytics

**Duration**: 2 weeks  
**Total Points**: 24 points  

## Sprint 2 Scope

### Part 1: PR Feedback & Technical Debt (3 days)

#### 1. PR Feedback Fixes (3 pts) ✅ COMPLETE
- [x] Fix hardcoded similarity threshold in `solar_system.ex:193`
- [x] Fix unused variable underscore in `mutamarket_client.ex:353`
- [x] Fix HEEx template syntax in `surveillance_live.html.heex:92`
- [x] Replace dummy UUID with proper auth in `surveillance_live.ex:20-21`
- [x] Add Task.Supervisor for spawned processes in `re_enrichment_worker.ex`
- [x] Address TODO for killmail relationship in `profile_match.ex:107`

#### 2. UI Review & Polish (3 pts) ✅ COMPLETE
- [x] Review all 6 LiveView pages for consistency and functionality:
  - [x] `/` - Home page (updated with current sprint info)
  - [x] `/feed` - Kill feed (working)
  - [x] `/dashboard` - Dashboard (updated with navigation and features)
  - [x] `/profile` - User profile (added auth and navigation)
  - [x] `/intel/:character_id` - Character intelligence (working)
  - [x] `/surveillance` - Surveillance profiles (needs UI completion)
- [x] Fix any broken pages or navigation issues
- [x] Ensure consistent styling and user experience
- [x] Add loading states and error handling

### Part 2: Complete Sprint 1 (4 days)

#### 4. Task 5.1: Complete Surveillance UI (3 pts) ✅ COMPLETE
- [x] Build profile creation/management UI at `/surveillance`
- [x] Add notification preferences to profiles
- [x] Create match history view
- [x] Note: The matching engine already exists and works!

#### 5. Task 5.2: Automated Re-enrichment (2 pts) ✅ COMPLETE
- [x] Implement background worker for stale data
- [x] Add re-enrichment triggers for price updates

### Part 3: PvP Analytics Foundation (1 week) ✅ COMPLETE

#### 6. Player Effectiveness Metrics (4 pts) ✅ COMPLETE
- [x] Create `PlayerStats` Ash resource
- [x] Build analytics engine for:
  - [x] Solo vs gang performance
  - [x] ISK efficiency trends
  - [x] Kill/death patterns over time
- [x] Create player profile page (`/player/:character_id`)

#### 7. Ship Performance Analytics (3 pts) ✅ COMPLETE
- [x] Create `ShipStats` Ash resource
- [x] Analyze ship effectiveness by:
  - [x] Overall K/D ratio per ship
  - [x] Average damage dealt/taken
  - [x] Popular fitting patterns
- [x] Add ship analytics tab to character intelligence

#### 8. Corporation Overview (2 pts) ✅ COMPLETE
- [x] Create basic corp page (`/corp/:corporation_id`)
- [x] Show member list with activity indicators
- [x] Display top pilots and recent kills
- [x] Foundation for Sprint 3's deeper corp analytics

## 🚀 Sprint 2 Complete! Bonus Tasks Added

### Bonus Tasks Completed
#### 9. Foreign Key Error Resolution (3 pts) ✅ COMPLETE
- [x] Fix missing ship_type_id and weapon_type_id errors
- [x] Implement ESI resolution for missing item types
- [x] Add TypeResolver service with proper error handling

#### 10. Surveillance Engine Optimization (4 pts) ✅ COMPLETE
- [x] Implement match result caching with TTL
- [x] Add batch recording for database efficiency
- [x] Optimize candidate finding with inverted indexes
- [x] Add parallel evaluation for large candidate sets
- [x] Implement profile prioritization and cache cleanup

## Timeline

- **Days 1-3**: PR feedback fixes and UI review
- **Days 4-7**: Complete Sprint 1 tasks
- **Days 8-14**: PvP analytics foundation

## Success Criteria

- All PR feedback issues resolved
- All UI pages functional and consistent
- Sprint 1 features complete
- Player and ship analytics live
- Basic corporation pages available
- No critical bugs or security issues
- All features have real-time updates via PubSub

## Technical Notes

### PR Feedback Priority
1. **Security**: Fix authentication in surveillance (dummy UUID)
2. **Reliability**: Add proper supervision for background tasks
3. **Code Quality**: Fix variable naming and template syntax
4. **Configuration**: Make similarity threshold configurable

### UI Consistency Checklist
- Consistent navigation across all pages
- Proper error states for missing data
- Loading indicators for async operations
- Mobile-responsive design
- Consistent color scheme and styling

### Architecture Patterns to Follow
- Use Ash resources for all new data models
- Implement bulk operations with `Ash.bulk_create`
- Add ETS caching for frequently accessed data
- Use Phoenix PubSub for real-time updates
- Follow existing LiveView patterns

## Sprint 1 Completion Status

### Already Completed (Day 1)
- ✅ Task 1.1: Static Data Automation (2 pts)
- ✅ Task 1.2: Fix Foreign Key Relationships (2 pts)
- ✅ Task 2.1: Janice API Client (4 pts)
- ✅ Task 2.2: Price Resolution Service (2 pts)
- ✅ Task 3.1: EVE ESI Client (2 pts)
- ✅ Task 3.2: Enhanced Name Resolution (2 pts)
- ✅ BONUS: Mutamarket Integration
- ✅ BONUS: Character Intelligence Feature (8 pts)

### To Complete in Sprint 2
- Task 4.1: Killmail Value Enrichment (4 pts)
- Task 4.2: Name Resolution Enhancement (2 pts) - partially done
- Task 5.1: Surveillance Profile System (4 pts) - backend complete, needs UI
- Task 5.2: Automated Re-enrichment (2 pts)
- Task 6.1 & 6.2: Performance work deferred to later sprints

## Definition of Done

A task is complete when:
1. Feature is implemented and working
2. Code passes quality checks (format, credo)
3. UI is polished and consistent
4. Real-time updates work via PubSub
5. Error handling is comprehensive
6. Any security issues are addressed