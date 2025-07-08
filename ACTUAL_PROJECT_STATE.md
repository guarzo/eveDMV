# EVE DMV - Actual Project State & Development Rules

**Last Updated**: 2025-01-08  
**Status**: Resetting to Reality  
**Current Sprint**: Reality Check Sprint 1  

## 🚨 Development Rules - MUST READ

### Definition of "Done"
A feature is **ONLY** considered done when:
1. ✅ It queries real data from the database
2. ✅ Calculations use actual algorithms (no hardcoded values)
3. ✅ No placeholder/mock return values
4. ✅ Tests exist and pass with real data
5. ✅ Documentation matches actual implementation
6. ✅ No TODO comments in the implementation

### Code Standards
```elixir
# ❌ NOT ACCEPTABLE - This is NOT done
def calculate_killmail_value(_killmail) do
  {:ok, %{total_value: 0, destroyed_value: 0, dropped_value: 0}}
end

# ✅ ACCEPTABLE - This is done
def calculate_killmail_value(killmail) do
  with {:ok, items} <- fetch_killmail_items(killmail.id),
       {:ok, prices} <- PriceService.get_prices(items) do
    total = calculate_total_from_prices(items, prices)
    {:ok, %{total_value: total, destroyed_value: destroyed, dropped_value: dropped}}
  end
end
```

## 📊 Actual Working Features (As of 2025-01-08)

### ✅ Fully Functional
1. **Kill Feed** (`/feed`)
   - Real-time SSE integration with wanderer-kills
   - LiveView updates working
   - Basic killmail display

2. **Authentication**
   - EVE SSO OAuth integration
   - Session management
   - User creation/update

3. **Database & Infrastructure**
   - PostgreSQL with partitioned tables
   - Broadway pipeline receiving killmails
   - Ash Framework resources defined

### 🟡 Partially Working
1. **Character Intelligence** (`/intel/:character_id`)
   - UI renders
   - Some basic data displayed
   - Most analytics return placeholder data

2. **Surveillance System** (`/surveillance`)
   - UI exists
   - Matching engine structure in place
   - Actual matching logic incomplete

### 🔴 UI Exists but Backend is Placeholder
1. **Battle Analysis** - Returns empty arrays
2. **Fleet Composition Tools** - All calculations return 0
3. **Wormhole Features** - Every function returns mock data
4. **Market Valuation** - Returns hardcoded zeros
5. **Defense Analytics** - Stub implementations
6. **Chain Intelligence** - Empty recommendations

### ❌ Critical Issues
1. **Static Data Not Loaded** - Ship/system tables empty
2. **No Price Data** - Janice integration not connected
3. **Limited ESI Integration** - Only auth works
4. **No Real Analytics** - All calculations stubbed

## 🎯 Reality Check Sprint 1 (Starting Now)

### Goals
Transform the codebase from a placeholder-filled prototype to a working application with at least ONE complete feature.

### Sprint 1 Tasks

#### Week 1: Foundation Cleanup
1. **Remove All Placeholder Code** (2 days)
   - Delete or comment out all stub implementations
   - Add TODO markers for future real implementations
   - Update tests to skip placeholder features

2. **Fix Static Data Loading** (1 day)
   - Ensure ship types load from SDE
   - Load solar systems and regions
   - Verify data in database

3. **Document Actual State** (1 day)
   - Update all documentation to reflect reality
   - Remove false claims from README
   - Create honest roadmap

4. **Pick ONE Feature to Complete** (1 day planning)
   - Recommend: Character Intelligence
   - Define exact scope
   - List required integrations

#### Week 2: First Real Feature
5. **Implement Real Character Analytics**
   - Query actual killmails from database
   - Calculate real K/D ratios
   - Show actual recent activity
   - Display real ship usage statistics

6. **Connect Price Service**
   - Integrate Janice API with real HTTP calls
   - Cache price data appropriately
   - Show ISK values on killmails

7. **Complete Character Intelligence MVP**
   - Recent kills/losses (from DB)
   - Actual statistics calculated
   - Real timezone activity
   - Working ship preferences

### Success Criteria
- [ ] Static data loads and displays correctly
- [ ] At least ONE feature works end-to-end with real data
- [ ] No functions return hardcoded mock data in "done" features
- [ ] Documentation reflects actual state
- [ ] Can demo to a real EVE player without embarrassment

## 📝 Tracking Progress

### Placeholder Removal Checklist
- [ ] `battle_analysis_service.ex` - Remove/mark all stubs
- [ ] `fleet_composition_service.ex` - Remove/mark all stubs  
- [ ] `chain_intelligence_service.ex` - Remove/mark all stubs
- [ ] `mass_optimizer.ex` - Remove/mark all stubs
- [ ] `home_defense_analyzer.ex` - Remove/mark all stubs
- [ ] `valuation_service.ex` - Remove/mark all stubs
- [ ] Intelligence analyzers - Remove hardcoded returns

### Real Implementation Checklist
- [ ] Static data loader runs and populates tables
- [ ] Character page shows data from actual database queries
- [ ] Price service makes real HTTP calls to Janice
- [ ] At least one calculation uses real algorithm
- [ ] Tests prove features work with real data

## 🚀 Future Sprints (After Foundation is Solid)

### Sprint 2: Complete Character Intelligence
- Full killmail history
- Performance trends  
- Social connections
- Activity patterns

### Sprint 3: Price & Value Analytics  
- Complete Janice integration
- Killmail value calculations
- Loss tracking
- Efficiency metrics

### Sprint 4: Second Feature
- Choose between:
  - Battle Analysis (with real data)
  - Corporation Analytics
  - Simple Fleet Tools

## 💡 Lessons Learned

1. **No More Placeholder Code** - Either implement it or don't include it
2. **Depth Over Breadth** - One working feature > ten broken features
3. **Honest Documentation** - Never claim something works if it doesn't
4. **Test With Real Data** - Mocks hide the truth
5. **User Value First** - Can a real player use this feature today?

---

**Remember**: Every line of code should provide real value. If it returns mock data, it's not done. If it's not done, don't ship it.