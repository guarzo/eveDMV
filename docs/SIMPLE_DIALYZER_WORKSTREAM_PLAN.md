# Simple Dialyzer Workstream Plan

## Current Status
- **Total Errors**: 1,840
- **Target**: <200 errors
- **Approach**: 5 parallel workstreams, simple and methodical

## Error Distribution
- unused_fun: 713
- pattern_match: 237
- no_return: 175
- call: 109
- extra_range: 58
- guard_fail: 37
- invalid_contract: 31
- Other: ~480

---

## 5 Workstreams - Simple Division

### Workstream A: Infrastructure (368 errors target)
**Files**: 
- `lib/eve_dmv/platform/`
- `lib/eve_dmv/external/`
- `lib/eve_dmv/cache/`

**Work**: Fix all dialyzer errors in these files. Start with unused functions, then move to other error types.

### Workstream B: Battle Analysis (368 errors target)
**Files**:
- `lib/eve_dmv/contexts/battle_analysis/`
- `lib/eve_dmv/contexts/combat/`

**Work**: Fix all dialyzer errors in these files. Focus on battle-related modules.

### Workstream C: Intelligence (368 errors target)
**Files**:
- `lib/eve_dmv/contexts/*intelligence*/`
- `lib/eve_dmv/contexts/surveillance/`

**Work**: Fix all dialyzer errors in these files. Handle intelligence and surveillance modules.

### Workstream D: Wormhole & Corporation (368 errors target)
**Files**:
- `lib/eve_dmv/contexts/wormhole_operations/`
- `lib/eve_dmv/contexts/corporation*/`

**Work**: Fix all dialyzer errors in these files. Deal with wormhole and corp modules.

### Workstream E: Web & Remaining (368 errors target)
**Files**:
- `lib/eve_dmv_web/`
- All remaining files not covered by other workstreams

**Work**: Fix all dialyzer errors in web layer and any remaining modules.

---

## Simple Working Process

### For Each Workstream:

1. **Get your file list**
   - Look at the files assigned to your workstream
   - Run dialyzer and filter for just your files

2. **Fix errors methodically**
   - Start with unused_fun errors (easiest)
   - Then pattern_match errors
   - Then other error types
   - Fix a few errors at a time
   - Commit regularly

3. **Basic safety**
   - Run `mix compile` after changes to ensure it compiles
   - If you break something, use git to revert that file only

4. **Coordination**
   - Work on your own files (no conflicts)
   - Merge to main branch daily
   - If you need to change a shared file, communicate with the team

---

## Timeline

### Week 1-2
- Each workstream reduces their errors by 50%
- Focus on unused_fun and easy fixes

### Week 3-4
- Continue working through remaining errors
- Focus on pattern_match and call errors

### Week 5-6
- Handle the harder errors (guard_fail, invalid_contract)
- Start cleanup of remaining issues

### Week 7-8
- Final push to get under 200 errors
- Use @dialyzer :no_match for truly unfixable issues

---

## That's It

No scripts. No fancy automation. Just:
1. Each workstream takes their files
2. Fix the dialyzer errors in those files
3. Commit regularly
4. Communicate if there are cross-workstream dependencies
5. Keep working until we're under 200 errors

Simple and methodical.