# Sprint 15: User Experience Core Features

**Duration**: 2 weeks  
**Start Date**: 2025-07-31  
**End Date**: 2025-08-14  
**Sprint Goal**: Complete essential user-facing features and replace critical placeholder implementations  
**Philosophy**: "Finish what users see first - personalization and favorites before advanced analytics"

---

## 🎯 Sprint Objective

### Primary Goal
Implement the essential user experience features that are currently showing as placeholder data in the dashboard, focusing on user personalization, favorites system, and completing the core valuation capabilities.

### Success Criteria
- [ ] User favorites system fully functional with database persistence
- [ ] Character search returns real results from database
- [ ] Market valuation system integrated with Janice API
- [ ] Dashboard shows no placeholder/mock data in user-facing sections
- [ ] Character intelligence search and comparison functional
- [ ] All user profile features show real data

### Explicitly Out of Scope
- Advanced wormhole operations
- Complex cross-system intelligence correlation
- Battle sharing and export features
- Advanced analytics and monitoring dashboards
- Performance optimization

---

## 📊 Sprint Backlog

### **Phase 1: Core User Features (High Priority)**
*Total: 34 points*

| Story ID | Description | Points | Priority | Status in Codebase | Definition of Done |
|----------|-------------|---------|----------|-------------------|-------------------|
| UX-1 | Implement user favorites system with database | 8 | CRITICAL | UI exists, no backend | Users can star/unstar characters, corps, battles |
| UX-2 | Fix character search functionality | 5 | CRITICAL | Returns empty results | Search returns real character data |
| UX-3 | Complete character intelligence comparison feature | 5 | HIGH | Limited implementation | Side-by-side character analysis |
| UX-4 | Implement real character profile statistics | 8 | HIGH | Some real, some placeholder | All profile stats use real calculations |
| UX-5 | Replace dashboard mock surveillance data | 8 | HIGH | Hardcoded mock data | Real surveillance status from database |

### **Phase 2: Market Intelligence & Valuation (Medium Priority)**
*Total: 23 points*

| Story ID | Description | Points | Priority | Status in Codebase | Definition of Done |
|----------|-------------|---------|----------|-------------------|-------------------|
| VAL-1 | Integrate Janice API for ship pricing | 8 | HIGH | Fallback system exists | Dynamic ship prices via Janice |
| VAL-2 | Implement accurate item valuation system | 8 | HIGH | Basic ranges only | Proper module/item pricing |
| VAL-3 | Expand ship coverage beyond 26 hardcoded ships | 5 | MEDIUM | 26 ships + fallbacks | Comprehensive ship database |
| VAL-4 | Add price caching and refresh mechanisms | 2 | MEDIUM | Cache exists, no data | TTL-based price updates |

### **Phase 3: Essential TODO Completion (Medium Priority)**
*Total: 39 points*

| Story ID | Description | Points | Priority | Status in Codebase | Definition of Done |
|----------|-------------|---------|----------|-------------------|-------------------|
| TODO-1 | Complete alert service for surveillance events | 8 | MEDIUM | Returns not_implemented | Real alert generation from killmails |
| TODO-2 | Implement basic intelligence scoring algorithms | 8 | MEDIUM | Placeholder scores | Real danger/hunter scoring |
| TODO-3 | Fix fleet engagement cache implementations | 5 | MEDIUM | All placeholder | Real fleet engagement data |
| TODO-4 | Implement chain intelligence topology sync | 5 | LOW | Returns placeholder | Basic wormhole chain sync |
| BATTLE-1 | Complete tactical highlight manager implementations | 8 | MEDIUM | 40+ stub functions | Real tactical analysis and highlight creation |
| BATTLE-2 | Implement battle curator placeholder functions | 5 | MEDIUM | 15+ stub functions | Real battle rating, search, and curation |

**Total Sprint Points**: 96 (Very Aggressive - will need to defer Phase 3 items)

---

## 📈 Daily Implementation Plan

### **Week 1: Core User Experience**

**Day 1-2: User Favorites System (UX-1)**
- Database schema for user_favorites table
- Ash resource and API integration
- Star/unstar buttons on character/corp pages
- Dashboard integration with real favorites data

**Day 3-4: Character Search & Intelligence (UX-2, UX-3)**
- Fix character search to query actual database
- Implement character comparison side-by-side analysis
- Real search results with proper filtering

**Day 5: Dashboard Surveillance Integration (UX-5)**
- Replace hardcoded "J123456" chain data
- Connect to real surveillance system status
- Remove placeholder alert counts

### **Week 2: Market Intelligence & Critical TODOs**

**Day 6-7: Janice API Integration (VAL-1, VAL-2)**
- Create JaniceClient module with rate limiting
- Implement ship price lookups
- Enhanced item categorization and pricing
- Fallback mechanisms for API failures

**Day 8-9: Complete Character Profile (UX-4)**
- Real activity heatmaps
- Accurate ship specialization analysis
- Performance trend calculations
- Complete profile statistics dashboard

**Day 10: Critical TODOs & Testing**
- Complete alert service implementation (TODO-1)
- Basic intelligence scoring (TODO-2)
- Testing and bug fixes

### **Phase 3 Deferral (Due to Scope)**
**Battle Sharing Implementation** (BATTLE-1, BATTLE-2) - **DEFERRED TO SPRINT 16**
Due to the addition of 13 points for battle sharing placeholders, Phase 3 items will be deferred:
- Fleet engagement cache implementations (TODO-3)
- Chain intelligence topology sync (TODO-4)  
- Tactical highlight manager implementations (BATTLE-1)
- Battle curator placeholder functions (BATTLE-2)

**Revised Sprint 15 Total**: 57 points (Achievable scope)

---

## 🔍 Implementation Details

### User Favorites System Database Schema
```sql
CREATE TABLE user_favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('character', 'corporation', 'battle')),
  entity_id VARCHAR(100) NOT NULL,
  entity_name VARCHAR(200) NOT NULL,
  custom_name VARCHAR(200),
  notes TEXT,
  tags TEXT[],
  favorited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, entity_type, entity_id)
);

CREATE INDEX idx_user_favorites_user_id ON user_favorites(user_id);
CREATE INDEX idx_user_favorites_entity ON user_favorites(entity_type, entity_id);
```

### Janice API Integration Architecture
```elixir
defmodule EveDmv.MarketIntelligence.Infrastructure.JaniceClient do
  @janice_base_url "https://janice.e-351.com/api/rest/v2"
  
  def get_item_price(type_id) do
    with {:ok, response} <- HTTPoison.get("#{@janice_base_url}/appraisal", 
                                         headers: headers(),
                                         params: [items: [%{typeID: type_id, quantity: 1}]]) do
      parse_price_response(response)
    end
  end
  
  defp handle_rate_limit(response) do
    # Implement exponential backoff for rate limits
  end
end
```

### Character Search Implementation
```elixir
def search_characters(query, limit \\ 10) do
  # Search both local database and ESI
  local_results = search_local_characters(query, limit)
  
  if length(local_results) < limit do
    esi_results = search_esi_characters(query, limit - length(local_results))
    combine_and_deduplicate(local_results, esi_results)
  else
    local_results
  end
end
```

### Battle Sharing Placeholders Implementation

**Critical Tactical Highlight Manager Functions (40+ stubs)**:
```elixir
# High Priority - Core functionality
defp fetch_battle_report_data(battle_report_id) do
  # Replace {:ok, %{killmails: [], duration_seconds: 0}}
  case BattleAnalysisService.get_battle_details(battle_report_id) do
    {:ok, battle} ->
      killmails = BattleAnalysisService.get_battle_killmails(battle_report_id)
      duration = calculate_battle_duration(killmails)
      {:ok, %{killmails: killmails, duration_seconds: duration, battle: battle}}
    error -> error
  end
end

defp analyze_tactical_context_at_timestamp(timestamp, battle_data) do
  # Replace placeholder with real tactical analysis
  time_window = 60  # seconds
  relevant_kills = extract_killmails_near_timestamp(timestamp, battle_data, time_window)
  
  tactical_situation = %{
    intensity: calculate_combat_intensity(relevant_kills),
    ship_types: analyze_ship_composition(relevant_kills),
    participants: count_unique_participants(relevant_kills),
    tactical_phase: determine_tactical_phase(timestamp, battle_data)
  }
  
  {:ok, tactical_situation}
end

defp calculate_combat_intensity(killmails) do
  # Replace simple count with sophisticated analysis
  count = length(killmails)
  total_value = Enum.sum(Enum.map(killmails, & &1.total_value || 0))
  participant_count = count_unique_participants(killmails)
  
  # Intensity factors: kill rate, value destroyed, participant density
  base_intensity = min(count / 5.0, 1.0)  # Normalize to kills per minute
  value_factor = min(total_value / 1_000_000_000, 1.0)  # Normalize to billions
  participant_factor = min(participant_count / 50.0, 1.0)  # Normalize to 50 pilots
  
  (base_intensity * 0.4 + value_factor * 0.3 + participant_factor * 0.3) * 100
end
```

**Battle Curator Implementation (15+ stubs)**:
```elixir
defp fetch_battle_report(report_id) do
  # Replace hardcoded example with real data fetch
  case Ash.get(EveDmv.BattleSharing.BattleReport, report_id) do
    {:ok, report} -> {:ok, report}
    {:error, _} -> {:error, :not_found}
  end
end

defp create_rating_record(report_id, rater_id, rating, comment, categories) do
  # Replace stub with real database insert
  rating_data = %{
    battle_report_id: report_id,
    character_id: rater_id,
    rating: rating,
    comment: comment,
    categories: categories,
    created_at: DateTime.utc_now()
  }
  
  case Ash.create(EveDmv.BattleSharing.BattleRating, rating_data) do
    {:ok, rating_record} -> {:ok, rating_record}
    error -> error
  end
end

defp perform_battle_report_search(query, filters, sort_by, limit) do
  # Replace {:ok, []} with real search implementation
  base_query = from(r in EveDmv.BattleSharing.BattleReport)
  
  query_with_filters = 
    base_query
    |> maybe_filter_by_title(filters[:title])
    |> maybe_filter_by_date_range(filters[:date_range])
    |> maybe_filter_by_rating(filters[:min_rating])
    |> order_by_sort_option(sort_by)
    |> limit(^limit)
  
  {:ok, Repo.all(query_with_filters)}
end
```

---

## ✅ Sprint Completion Criteria

### User Experience Validation
- [ ] User can favorite characters from intelligence pages
- [ ] Dashboard favorites section shows real user bookmarks
- [ ] Character search returns relevant results from database
- [ ] Character comparison works with real statistics
- [ ] Profile page shows comprehensive real data

### Market Intelligence Validation
- [ ] Ship prices update from Janice API
- [ ] Item valuation uses proper categorization
- [ ] Price caching reduces API calls effectively
- [ ] Fallback pricing works when API unavailable

### Technical Quality
- [ ] No placeholder data visible in user interfaces
- [ ] All new features have comprehensive tests
- [ ] Database queries optimized for performance
- [ ] Error handling for external API failures

---

## 🚨 Risk Management

### High Risk Items
1. **Janice API Integration** - External dependency with rate limits
   - *Mitigation*: Implement robust caching and fallback systems
   
2. **User Favorites Performance** - Could impact dashboard load times
   - *Mitigation*: Efficient queries with proper indexing
   
3. **Character Search Performance** - ESI API calls can be slow
   - *Mitigation*: Async search with loading states

### Critical Dependencies
- Janice API availability and documentation
- EVE ESI API for character search
- Database performance for favorites queries

---

## 📊 Sprint Success Metrics

### Completion Metrics
- **Feature Completion**: 100% of Phase 1 items, 80% of Phase 2
- **User Experience**: No visible placeholder data
- **Performance**: All features respond within 3 seconds
- **Quality**: 90%+ test coverage for new features

### Business Value Metrics
- **User Engagement**: Favorites usage tracking
- **Data Accuracy**: Valuation system accuracy vs market
- **Feature Adoption**: Character search usage rates

---

## 🚀 Next Sprint Preview

**Sprint 16** should focus on:
1. **Advanced Intelligence Features**: Cross-system correlation, pattern analysis
2. **Wormhole Operations**: Chain topology, mass optimization
3. **Battle Analysis Enhancement**: Advanced tactical analysis
4. **Performance Optimization**: Query optimization, caching strategies

---

## 📝 Implementation Notes

### Priority Rationale
This sprint focuses on user-visible features first because:
- Dashboard currently shows placeholder data that undermines user trust
- Favorites system is essential for user retention and workflow
- Market valuation affects every killmail and fleet analysis
- Character search is fundamental to intelligence workflows

### Code Quality Focus
- All new features must include comprehensive tests
- Database migrations must be reversible
- API integrations must handle failures gracefully
- UI components must show loading and error states

---

**Remember**: This sprint prioritizes finishing user-facing features over adding new advanced functionality. Every completed item should eliminate placeholder data and provide real value to users.