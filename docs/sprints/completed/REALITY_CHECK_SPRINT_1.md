# Reality Check Sprint 1 - Getting Back to Basics

**Sprint Duration**: 2 weeks (2025-01-08 to 2025-01-22)  
**Sprint Goal**: Remove all placeholder code and deliver ONE fully functional feature  
**Primary Focus**: Character Intelligence with real data  

## 📋 Sprint Backlog

### Day 1-2: Placeholder Cleanup
**Goal**: Remove or clearly mark all stub implementations

#### Tasks:
1. **Audit & Mark Stubs** (4 hours)
   ```elixir
   # Change this:
   def calculate_value(_killmail) do
     {:ok, 0}
   end
   
   # To this:
   def calculate_value(_killmail) do
     # TODO: Implement real price calculation
     # Requires: Janice API integration
     # Original stub returned: {:ok, 0}
     {:error, :not_implemented}
   end
   ```

2. **Update Service Returns** (4 hours)
   - [ ] Battle Analysis Service - Return {:error, :not_implemented}
   - [ ] Fleet Composition Service - Return {:error, :not_implemented}
   - [ ] Wormhole services - Return {:error, :not_implemented}
   - [ ] Update UI to handle :not_implemented gracefully

3. **Fix Test Suite** (4 hours)
   - [ ] Skip tests for stub features
   - [ ] Add @tag :skip_until_implemented
   - [ ] Ensure remaining tests pass

### Day 3: Static Data Loading
**Goal**: Populate database with EVE static data

#### Tasks:
1. **Fix Static Data Loader** (6 hours)
   - [ ] Debug why tables are empty
   - [ ] Run static data import
   - [ ] Verify ships, systems, regions loaded
   - [ ] Add mix task for easy re-running

2. **Verify Data Integrity** (2 hours)
   ```bash
   mix ecto.query "SELECT COUNT(*) FROM static_ship_types"
   mix ecto.query "SELECT COUNT(*) FROM static_solar_systems"
   mix ecto.query "SELECT COUNT(*) FROM static_regions"
   ```

### Day 4: Documentation Reality Check
**Goal**: Update all docs to reflect actual state

#### Tasks:
1. **Update README.md** (2 hours)
   - [ ] Remove feature claims for unimplemented features
   - [ ] Add "Coming Soon" section
   - [ ] Update setup instructions

2. **Archive Misleading Docs** (1 hour)
   ```bash
   mkdir docs/archive/optimistic-planning
   mv PROJECT_STATUS.md docs/archive/optimistic-planning/
   mv SPRINT_*.md docs/archive/optimistic-planning/
   ```

3. **Create Honest Roadmap** (2 hours)
   - [ ] Write REALISTIC_ROADMAP.md
   - [ ] 3-month plan with achievable goals
   - [ ] Clear milestones

### Day 5: Feature Selection & Planning
**Goal**: Define scope for ONE complete feature

#### Decision: Character Intelligence MVP
**Why**: 
- Most UI elements already exist
- Clear value proposition
- Builds on working kill feed
- Data model supports it

**MVP Scope**:
1. Recent Activity (last 30 days)
2. Kill/Death Statistics  
3. Top Ships Used
4. ISK Efficiency
5. Timezone Activity

### Week 2: Implement Character Intelligence

### Day 6-7: Data Layer
**Goal**: Real database queries for character data

#### Tasks:
1. **Character Queries** (8 hours)
   ```elixir
   def get_character_kills(character_id, days \\ 30) do
     cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60)
     
     KillmailRaw
     |> where([k], k.victim_character_id == ^character_id or 
                   fragment("? @> ?", k.attackers, ^[%{character_id: character_id}]))
     |> where([k], k.kill_time > ^cutoff)
     |> select([k], %{
       killmail_id: k.killmail_id,
       kill_time: k.kill_time,
       ship_type_id: k.victim_ship_type_id,
       value: k.total_value,
       is_loss: k.victim_character_id == ^character_id
     })
     |> Repo.all()
   end
   ```

2. **Statistics Calculations** (8 hours)
   - [ ] Real K/D ratio
   - [ ] ISK destroyed/lost
   - [ ] Ship usage frequency
   - [ ] Activity by hour

### Day 8-9: Price Integration
**Goal**: Connect Janice API for real ISK values

#### Tasks:
1. **Janice HTTP Client** (6 hours)
   ```elixir
   def get_prices(type_ids) when is_list(type_ids) do
     # Real HTTP call to Janice
     # Handle rate limits
     # Cache results
   end
   ```

2. **Price Enrichment** (6 hours)
   - [ ] Update existing killmails with prices
   - [ ] Add to pipeline for new killmails
   - [ ] Handle API failures gracefully

### Day 10: Complete Character Intelligence
**Goal**: Fully functional character analysis page

#### Tasks:
1. **Wire Everything Together** (6 hours)
   - [ ] LiveView fetches real data
   - [ ] Display actual statistics
   - [ ] Show recent kills/losses
   - [ ] Activity heatmap from real data

2. **Polish & Error Handling** (2 hours)
   - [ ] Loading states
   - [ ] Error messages
   - [ ] Empty state handling

## 📊 Sprint Metrics

### Definition of Success
- [ ] Zero functions return mock data in Character Intelligence
- [ ] Static data tables have actual EVE data
- [ ] Character page works with any valid character_id
- [ ] Janice integration returns real prices
- [ ] Can demo to EVE players without caveats
- [ ] Manual testing completed and documented

### Day 11-12: Manual Testing & Verification
**Goal**: Ensure everything actually works in a real browser

#### Manual Testing Checklist:
1. **Static Data Verification**
   - [ ] Visit kill feed, verify ship names display
   - [ ] Check that system names show correctly
   - [ ] Confirm region data loads

2. **Character Intelligence Testing**
   - [ ] Test with 5 different real character IDs
   - [ ] Verify K/D calculations match manual count
   - [ ] Check ISK values are reasonable
   - [ ] Confirm timezone activity graph shows data
   - [ ] Test with character that has no kills (edge case)
   - [ ] Test with very active character (performance)

3. **Error Handling**
   - [ ] Test with invalid character ID
   - [ ] Disconnect internet, test offline behavior
   - [ ] Test when Janice API is down
   - [ ] Verify error messages are user-friendly

4. **Cross-Browser Testing**
   - [ ] Chrome/Chromium
   - [ ] Firefox
   - [ ] Safari (if available)
   - [ ] Mobile responsive check

5. **Performance Testing**
   - [ ] Page load time < 2 seconds
   - [ ] No memory leaks after 10 min usage
   - [ ] LiveView reconnects properly

Document all findings in `SPRINT_1_MANUAL_TEST_RESULTS.md`

### Sprint Velocity Tracking
```
Planned: 10 story points
- Cleanup: 3 pts
- Static Data: 2 pts  
- Character Intelligence: 5 pts

Completed: [Track daily]
```

## 🚧 Risk Mitigation

### Risk 1: Janice API Complexity
**Mitigation**: Start with simple price lookup, add features incrementally

### Risk 2: Query Performance  
**Mitigation**: Add database indexes, use materialized views if needed

### Risk 3: Scope Creep
**Mitigation**: MVP scope is locked - no additions this sprint

## 📝 Daily Standup Template

```markdown
### Day X - Date

**Yesterday**: 
- Completed: [specific tasks]
- Blocker: [any issues]

**Today**:
- [ ] Task 1
- [ ] Task 2

**Real Implementation Count**: X functions now use real data
**Remaining Stubs**: Y functions still return mock data
```

## 🎯 Next Sprint Preview

**Sprint 2**: Expand Character Intelligence
- Add social connections graph
- Fleet participation analysis
- Performance trends over time
- Favorite systems/regions

Only start Sprint 2 after Sprint 1 delivers a fully functional Character Intelligence feature with zero placeholder code.

---

**Remember the new rule**: If it returns mock data, it's not done. Focus on depth, not breadth.