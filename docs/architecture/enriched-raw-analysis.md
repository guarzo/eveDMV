# Enriched vs Raw Killmail Architecture Analysis

## Current State

### Tables
1. **killmails_raw** 
   - Stores complete killmail JSON from wanderer-kills SSE feed
   - Contains all character/corp/alliance names in the JSON
   - Used by Character Analysis page and Kill Feed
   - 3 killmails in test data

2. **killmails_enriched**
   - Intended for "enriched" data with ISK values and analysis
   - Currently just duplicates raw data with empty/zero enrichment fields
   - NOT used by any UI components
   - Same 3 killmails as raw table

### "Enrichment" Process
The `KillmailDataTransformer` creates enriched records but:
- `total_value`: Always 0.0 (no price API integration)
- `ship_value`: Always 0.0
- `fitted_value`: Always 0.0
- `price_data_source`: Always "wanderer_kills"
- `kill_category`: Basic attacker count categorization
- `module_tags`: Always empty []
- `noteworthy_modules`: Always empty []

### Current Usage
- **Kill Feed**: Uses `killmails_raw` directly
- **Character Analysis**: Queries `killmails_raw` directly
- **No UI component uses `killmails_enriched`**

## Problems

1. **No Real Enrichment**: The enriched table doesn't add any value
2. **Duplicate Data**: Same killmail stored twice
3. **Insertion Errors**: We had to fix field mismatch errors for a table we don't use
4. **Performance Impact**: Double writes for every killmail
5. **Confusion**: Developers unsure which table to query

## Options

### Option A: Remove Enriched Table Entirely ✅ RECOMMENDED
**Pros:**
- Simplifies architecture significantly
- Halves storage requirements
- Eliminates duplicate insertion errors
- Reduces pipeline complexity
- All data already available in raw table

**Cons:**
- None identified - enriched table provides no value currently

**Implementation:**
1. Stop inserting into enriched table
2. Drop enriched table and related code
3. Rename "raw" to just "killmails" for clarity

### Option B: Implement Real Enrichment
**Pros:**
- Could add real value with price data
- Could pre-calculate analytics

**Cons:**
- Requires integrating price APIs (Janice, etc.)
- Adds complexity and potential failure points
- Price data changes frequently
- Still duplicates core killmail data

**What Real Enrichment Would Include:**
- Actual ISK values from price APIs
- Pre-calculated threat scores
- Pattern detection results
- Enriched ship/module metadata

### Option C: Use Enriched as Materialized View
**Pros:**
- Could optimize complex queries
- Separate analytics from raw data

**Cons:**
- PostgreSQL already has real materialized views
- Adds complexity for minimal benefit
- Still requires maintenance

## Recommendation

**Remove the enriched table entirely (Option A)**

Reasons:
1. It provides no value currently
2. All needed data exists in raw table
3. Simpler is better
4. Can always add real enrichment later if needed
5. Reduces errors and complexity

## Implementation Plan

1. **Phase 1: Stop Writing to Enriched**
   - Comment out enriched insertion in pipeline
   - Monitor for any issues

2. **Phase 2: Remove Code**
   - Remove `KillmailEnriched` resource
   - Remove enriched changeset building
   - Clean up transformer

3. **Phase 3: Drop Table**
   - Migration to drop `killmails_enriched` table
   - Update any documentation

4. **Phase 4: Rename Raw**
   - Consider renaming `killmails_raw` to just `killmails`
   - Update all references