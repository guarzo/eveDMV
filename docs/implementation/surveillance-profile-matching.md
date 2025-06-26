# Surveillance Profile Matching

Here's a deep‐dive into Surveillance Profile Matching, covering the exact JSON syntax, how we'd handle complex conditions, and the performance implications of 1,000+ active profiles.

## 1. JSON Schema for Filter Chaining

Each profile is represented as a logical tree of rules. We use a recursive structure with `condition` ("and"/"or") and a list of `rules`, where each rule is either a leaf test or another nested group.

```json
{
  "profile_id": "uuid-1234",
  "name": "High-ISK T2 Alerts",
  "filter_tree": {
    "condition": "and",
    "rules": [
      {
        "field": "module_tags",
        "operator": "contains_any",
        "value": ["T2"]
      },
      {
        "condition": "or",
        "rules": [
          {
            "field": "isk_value",
            "operator": "gt",
            "value": 100000000
          },
          {
            "field": "system_id",
            "operator": "in",
            "value": [30000142, 30000144]
          }
        ]
      }
    ]
  },
  "notification_settings": {
    "volume": 0.5,
    "duration_s": 5
  }
}
```

### Supported Operators

| Operator | Description |
|---|---|
| `eq` / `ne` | equals / not equals |
| `gt` / `lt` | greater than / less than |
| `gte` / `lte` | ≥ / ≤ |
| `in` / `not_in` | value is (not) in array |
| `contains_any` | array field contains any of the given values |
| `contains_all` | array field contains all of the given values |
| `not_contains` | array field contains none of the given values |

## 2. Handling Complex Conditions

Chaining is simply nesting groups.

**Example "T2 modules AND ISK > 100 M":**

```json
{
  "condition": "and",
  "rules": [
    { "field": "module_tags", "operator": "contains_any", "value": ["T2"] },
    { "field": "isk_value",   "operator": "gt",            "value": 100000000 }
  ]
}
```

You can nest as deep as you need for combinations of "and"/"or".

## 3. Runtime Matching Engine

### 3.1 Pre-Compilation

1. Load all active profiles at startup (or on change) into an ETS table as `{profile_id, compiled_fun}` pairs
2. Compile each `filter_tree` into an Elixir anonymous function of shape:
   ```elixir
   fn killmail ->
     # returns true if killmail matches
   end
   ```
3. Using pattern‐matching and guard clauses for simple operators, recursion for nested groups

### 3.2 Inverted Indexes for Pruning

To avoid evaluating every profile against every killmail:

**Build ETS indexes** for "hot" filter types:
- **module_tags** → Map each tag (e.g. "T2") to the set of profile_ids that test `contains_*` on that tag
- **system_id** → mapping system → profiles
- **isk thresholds** → a sorted list of `{threshold, profiles}` so we can quickly find those with `gt`/`lt` filters that could match this kill's ISK

### 3.3 Matching Algorithm (per incoming killmail)

```elixir
def match_profiles(killmail) do
  # 1) Gather candidate IDs from each inverted index
  candidates_by_tag    = Enum.flat_map(killmail.module_tags, &ETS.lookup(:by_module_tag, &1))
  candidates_by_system = ETS.lookup(:by_system_id, killmail.system_id)
  candidates_by_isk    = lookup_isk_candidates(killmail.isk_value)

  # 2) Union all candidate lists
  candidate_ids = MapSet.new(candidates_by_tag ++ candidates_by_system ++ candidates_by_isk)

  # 3) Final filter: apply each profile's compiled function
  for id <- candidate_ids,
      {:ok, fun} <- ETS.lookup(:compiled_profiles, id),
      fun.(killmail),
      do: id
end
```

Profiles that don't reference any of the fields present in this killmail simply aren't in the candidate set—so we avoid testing them.

## 4. Performance Impact

**Naïve:** 1,000 profiles × 1,000 kills/sec = 1,000,000 function calls/sec → high CPU.

**With indexing:**
- Typical killmail has ~5 tags → pulls maybe 100 profile IDs
- ISK and system filters may add another 50–100
- Total candidates ≈ 150, so ≈ 150 function calls per kill
- At 1,000 kills/sec → 150,000 calls/sec, easily handled on a 16-core BEAM

**Memory:**
- ETS tables for indexes and compiled funs ~ a few MB each

**Latency:**
- Candidate lookup via ETS: <100 µs
- Function eval per killmail: ≈200 µs for 150 calls
- Well within our sub-200 ms end-to-end for alerting

**Scalability:**
- If profiles grow to 10,000, inverted indexes keep candidates small
- You can shard by module tag or region to spread across nodes

## Bottom Line

By representing filters as a nested JSON tree, compiling to fast BEAM functions, and using ETS‐based inverted indexes to prune the search space, we can support thousands of active profiles with negligible per-kill overhead.