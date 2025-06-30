# EVE DMV Manual Testing Script

**Version**: Sprint 2 Complete  
**Date**: June 29, 2025  
**Tester**: _____________  
**Environment**: http://localhost:4010  

## Pre-Test Setup

### ✅ Environment Check
- [ ] Phoenix server running (`mix phx.server`)
- [ ] Database migrated (`mix ecto.migrate`)
- [ ] Static data loaded (`mix eve.load_static_data`)
- [ ] Pipeline enabled (check `.env` file: `PIPELINE_ENABLED=true`)
- [ ] External APIs configured (Janice, ESI, Mutamarket)

### ✅ Test Data Preparation
- [X] Ensure killmail pipeline is receiving data (check logs for "⚔️ Processing killmail")
- [X] Have test character IDs ready (grab from recent killmails)
- [X] Have test corporation IDs ready
- [X] Clear browser cache and cookies

---

## Test Suite 1: Authentication & Navigation

### 1.1 Home Page (`/`)
- [X] **Load home page** - Should display welcome/dashboard content
    - Dev Progress needs to be updated,  shows 3 Epics complete, but sprint 2 in progress? 
- [X] **Navigation menu** - Check all menu items are visible
- [X] **EVE SSO login button** - Should be prominent and functional
- [X] **Responsive design** - Test on mobile/tablet view
- [] **No errors in browser console**
```
caught RangeError: Maximum call stack size exceeded
    at loop (topbar.js:135:21)
    at Object.progress (topbar.js:143:11)
    at loop (topbar.js:139:24)
    at Object.progress (topbar.js:143:11)
    at loop (topbar.js:139:24)
    at Object.progress (topbar.js:143:11)
    at loop (topbar.js:139:24)
    at Object.progress (topbar.js:143:11)
    at loop (topbar.js:139:24)
    at Object.progress (topbar.js:143:11)
utils.js:39 phx-GE2G8gSdmNCrcjWB mount:  -  Object
utils.js:39 phx-GE2G8gSdmNCrcjWB error: view crashed -  {}
topbar.js:61 Uncaught RangeError: Maximum call stack size exceeded
    at repaint (topbar.js:61:15)
    at Object.progress (topbar.js:131:9)
    at loop (topbar.js:139:24)
    at Object.progress (topbar.js:143:11)
    at loop (topbar.js:139:24)
    at Object.progress (topbar.js:143:11)
    at loop (topbar.js:139:24)
    at Object.progress (topbar.js:143:11)
    at loop (topbar.js:139:24)
```
other error in logs
```
solar_systems" AS e0 WHERE (e0."system_id"::bigint = $1::bigint) LIMIT $2 [30002765, 2]
↳ anonymous fn/3 in AshPostgres.DataLayer.run_query/2, at: lib/data_layer.ex:788
[error] GenServer #PID<0.2258.0> terminating
** (KeyError) key :victim_character_id not found in: %{
  id: "128225500-1751204261",
  security_class: "highsec",
  security_status: 0.550531907,
  killmail_id: 128225500,
  killmail_time: ~U[2025-06-29 13:27:39Z],
  solar_system_name: "Sivala",
  total_value: Decimal.new("1687200353.35"),
  victim_character_name: "Aenternus",
  victim_ship_name: "Occator",
  victim_corporation_name: "VVorld of Crabiis",
  solar_system_id: 30002765,
  ship_value: Decimal.new("251027780.18"),
  attacker_count: 8,
  final_blow_character_name: "Cannibal Khan",
  victim_alliance_name: "Big Green Fly",
  age_minutes: 0,
  security_color: "text-green-400",
  is_expensive: true
}
    (eve_dmv 0.1.0) lib/eve_dmv_web/live/kill_feed_live.html.heex:115: anonymous fn/4 in EveDmvWeb.KillFeedLive.render/1
    (elixir 1.17.3) lib/enum.ex:4423: anonymous fn/3 in Enum.reduce/3
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/live_stream.ex:110: Enumerable.Phoenix.LiveView.LiveStream.do_reduce/3
    (elixir 1.17.3) lib/enum.ex:4423: Enum.reduce/3
    (eve_dmv 0.1.0) lib/eve_dmv_web/live/kill_feed_live.html.heex:97: anonymous fn/2 in EveDmvWeb.KillFeedLive.render/1
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/diff.ex:391: Phoenix.LiveView.Diff.traverse/7
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/diff.ex:555: anonymous fn/4 in Phoenix.LiveView.Diff.traverse_dynamic/7
    (elixir 1.17.3) lib/enum.ex:2531: Enum."-reduce/3-lists^foldl/2-0-"/3
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/diff.ex:389: Phoenix.LiveView.Diff.traverse/7
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/diff.ex:136: Phoenix.LiveView.Diff.render/3
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/channel.ex:994: anonymous fn/4 in Phoenix.LiveView.Channel.render_diff/3
    (telemetry 1.3.0) /workspace/deps/telemetry/src/telemetry.erl:324: :telemetry.span/3
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/channel.ex:989: Phoenix.LiveView.Channel.render_diff/3
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/channel.ex:819: Phoenix.LiveView.Channel.handle_changed/4
    (stdlib 6.2.2) gen_server.erl:2345: :gen_server.try_handle_info/3
    (stdlib 6.2.2) gen_server.erl:2433: :gen_server.handle_msg/6
    (stdlib 6.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3
Last message: %Phoenix.Socket.Broadcast{topic: "kill_feed", event: "new_kill", payload: %{"attacker_count" => 8, "attackers" => [%{"character_id" => 2116654157, "character_name" => "Cannibal Khan", "corporation_id" => 98672562, "corporation_name" => "R.E.M.N.A.N.T.S", "corporation_ticker" => "UNGA", "damage_done" => 3400, "final_blow" => true, "security_status" => -0.5, "ship_name" => "Thrasher", "ship_type_id" => 16242, "weapon_type_id" => 2889}, %{"alliance_id" => 99010015, "alliance_name" => "BLACKFLAG.", "alliance_ticker" => "S4LTY", "character_id" => 2117613923, "character_name" => "Timeloh Regho", "corporation_id" => 98724133, "corporation_name" => "Brazilian Templars", "corporation_ticker" => "BR.TE", "damage_done" => 2628, "final_blow" => false, "security_status" => -2, "ship_name" => "Thrasher", "ship_type_id" => 16242, "weapon_type_id" => 16242}, %{"character_id" => 2119446838, "character_name" => "Ecch0", "corporation_id" => 98672562, "corporation_name" => "R.E.M.N.A.N.T.S", "corporation_ticker" => "UNGA", "damage_done" => 2468, "final_blow" => false, "security_status" => -0.7, "ship_name" => "Caracal", "ship_type_id" => 621, "weapon_type_id" => 24488}, %{"alliance_id" => 99010015, "alliance_name" => "BLACKFLAG.", "alliance_ticker" => "S4LTY", "character_id" => 2118633948, "character_name" => "V4ld3Sp4R", "corporation_id" => 98724133, "corporation_name" => "Brazilian Templars", "corporation_ticker" => "BR.TE", "damage_done" => 2266, "final_blow" => false, "security_status" => -0.6, "ship_name" => "Thrasher", "ship_type_id" => 16242, "weapon_type_id" => 16242}, %{"alliance_id" => 99010015, "alliance_name" => "BLACKFLAG.", "alliance_ticker" => "S4LTY", "character_id" => 2112989088, "character_name" => "Mamica de Cadela", "corporation_id" => 98724133, "corporation_name" => "Brazilian Templars", "corporation_ticker" => "BR.TE", "damage_done" => 2248, "final_blow" => false, "security_status" => -0.4, "ship_name" => "Thrasher", "ship_type_id" => 16242, "weapon_type_id" => 16242}, %{"alliance_id" => 99010015, "alliance_name" => "BLACKFLAG.", "alliance_ticker" => "S4LTY", "character_id" => 2119049912, "character_name" => "Bitch of blaster", "corporation_id" => 98724133, "corporation_name" => "Brazilian Templars", "corporation_ticker" => "BR.TE", "damage_done" => 2201, "final_blow" => false, "security_status" => -0.5, "ship_name" => "Thrasher", "ship_type_id" => 16242, "weapon_type_id" => 16242}, %{"alliance_id" => 99010015, "alliance_name" => "BLACKFLAG.", "alliance_ticker" => "S4LTY", "character_id" => 2119046916, "character_name" => "Dr4kka", "corporation_id" => 98724133, "corporation_name" => "Brazilian Templars", "corporation_ticker" => "BR.TE", "damage_done" => 2067, "final_blow" => false, "security_status" => -0.5, "ship_name" => "Thrasher", "ship_type_id" => 16242, "weapon_type_id" => 16242}, %{"alliance_id" => 99010015, "alliance_name" => "BLACKFLAG.", "alliance_ticker" => "S4LTY", "character_id" => 2122517533, "character_name" => "Creme Rinse", "corporation_id" => 98724133, "corporation_name" => "Brazilian Templars", "corporation_ticker" => "BR.TE", "damage_done" => 2066, "final_blow" => false, "security_status" => -0.7, "ship_name" => "Thrasher", "ship_type_id" => 16242, "weapon_type_id" => 16242}], "kill_time" => "2025-06-29T13:27:39Z", "killmail_id" => 128225500, "solar_system_name" => "Sivala", "system_id" => 30002765, "victim" => %{"alliance_id" => 99011248, "alliance_name" => "Big Green Fly", "alliance_ticker" => "BGF", "character_id" => 2122327123, "character_name" => "Aenternus", "corporation_id" => 98776997, "corporation_name" => "VVorld of Crabiis", "corporation_ticker" => "VVOR", "damage_taken" => 19344, "position" => %{"x" => 1351951466403.411, "y" => -231496624954.5029, "z" => -1817005773110.3628}, "ship_name" => "Occator", "ship_type_id" => 12745}, "zkb" => %{"awox" => false, "destroyedValue" => 251027780.18, "droppedValue" => 1436172573.17, "fittedValue" => 281343718.15, "hash" => "8bb0ec9ae2f7aa1b5fc6aab0b4ab2ed8f84aec72", "labels" => ["cat:6", "#:5+", "pvp", "loc:highsec", "isk:1b+"], "locationID" => 50001299, "npc" => false, "points" => 1, "solo" => false, "totalValue" => 1687200353.35}}}
State: %{socket: #Phoenix.LiveView.Socket<id: "phx-GE2G8gSdmNCrcjWB", endpoint: EveDmvWeb.Endpoint, view: EveDmvWeb.KillFeedLive, parent_pid: nil, root_pid: #PID<0.2258.0>, router: EveDmvWeb.Router, assigns: %{__changed__: %{}, flash: %{}, streams: %{__changed__: MapSet.new([]), __configured__: %{}, __ref__: 1, killmail_stream: %Phoenix.LiveView.LiveStream{name: :killmail_stream, dom_id: #Function<3.9968781/1 in Phoenix.LiveView.LiveStream.new/4>, ref: "0", inserts: [], deletes: [], reset?: false, consumable?: false}}, live_action: nil, total_isk_destroyed: Decimal.new("2279390657.61"), killmails: [%{id: "128225758-1751204203", security_class: "nullsec", security_status: -0.3243123619, victim_character_id: 2118734424, final_blow_character_id: 94690025, killmail_id: 128225758, killmail_time: ~U[2025-06-29 13:36:43Z], solar_system_name: "319-3D", total_value: Decimal.new("10000.00"), victim_character_name: "CDK LOOK", victim_ship_name: "Capsule", victim_corporation_name: "ChuangShi", solar_system_id: 30004722, ship_value: Decimal.new("0.00"), attacker_count: 4, final_blow_character_name: "Azateki", victim_alliance_name: "Fraternity.", age_minutes: 0, security_color: "text-red-400", is_expensive: false}, %{id: "128225757-1751204202", security_class: "highsec", security_status: 0.9459131167, victim_character_id: 2113181145, final_blow_character_id: 2114971784, killmail_id: 128225757, killmail_time: ~U[2025-06-29 13:36:42Z], solar_system_name: "Jita", total_value: Decimal.new("342489288.08"), victim_character_name: "Lord II Tryal", victim_ship_name: "Capsule",  (truncated)
[debug] MOUNT EveDmvWeb.KillFeedLive
  Parameters: %{}
  Session: %{"_csrf_token" => "K8aKI7r5wHGgkSWOzXc5IANU", "current_user_id" => "8281cf41-4dcd-4323-a05a-0db1c9a453f9"}
  ```

**Expected**: Clean home page with navigation and login option

### 1.2 EVE SSO Authentication
- [X] **Click "Sign in with EVE"** - Should redirect to EVE SSO
- [X] **Complete EVE SSO flow** - Login with test character
- [X] **Successful redirect** - Should return to app with character logged in
- [X] **Character name displayed** - Should show logged-in character name
- [X] **Login state persists** - Refresh page, should stay logged in
- [X] **Logout functionality** - Should clear session and redirect

**Expected**: Full authentication flow working with session persistence

---

## Test Suite 2: Live Kill Feed

### 2.1 Kill Feed Page (`/feed`)
- [X] **Navigation** - Access from menu or direct URL
- [X] **Real-time updates** - Should see new killmails appearing automatically
- [X] **Killmail display** - Each kill shows victim, ship, system, value
    - we should use eveImagetech images for ships / characters / corporations / alliances
- [X] **ISK formatting** - Values displayed as "1.2B", "500M", etc.
- [X] **Time stamps** - "X minutes ago" format
- [X] **System names** - Should resolve to actual system names, not IDs
- [ ] **Character names** - Should be clickable links
    - name is clickable but page does not load
```
    ype_id", k0."victim_ship_name", k0."total_value", k0."ship_value", k0."fitted_value", k0."attacker_count", k0."final_blow_character_id", k0."final_blow_character_name", k0."kill_category", k0."victim_ship_category", k0."module_tags", k0."noteworthy_modules", k0."enriched_at", k0."price_data_source", k0."inserted_at", k0."updated_at" FROM "killmails_enriched" AS k0 INNER JOIN "participants" AS p1 ON p1."killmail_id" = k0."killmail_id" WHERE ((p1."character_id" = $1) AND (k0."killmail_time" >= $2)) ORDER BY k0."killmail_time" DESC [2119113381, ~U[2025-03-31 13:40:10Z]]
↳ EveDmv.Intelligence.CharacterAnalyzer.get_recent_killmails/1, at: lib/eve_dmv/intelligence/character_analyzer.ex:163
[error] GenServer #PID<0.2502.0> terminating
** (ArgumentError) schema EveDmv.Killmails.KillmailEnriched does not have association or embed :participants
    (elixir 1.17.3) lib/enum.ex:2531: Enum."-reduce/3-lists^foldl/2-0-"/3
    (ecto 3.13.2) lib/ecto/repo/queryable.ex:247: Ecto.Repo.Queryable.execute/4
    (ecto 3.13.2) lib/ecto/repo/queryable.ex:19: Ecto.Repo.Queryable.all/3
    (eve_dmv 0.1.0) lib/eve_dmv/intelligence/character_analyzer.ex:163: EveDmv.Intelligence.CharacterAnalyzer.get_recent_killmails/1
    (eve_dmv 0.1.0) lib/eve_dmv/intelligence/character_analyzer.ex:42: EveDmv.Intelligence.CharacterAnalyzer.analyze_character/1
    (eve_dmv 0.1.0) lib/eve_dmv_web/live/character_intel_live.ex:51: EveDmvWeb.CharacterIntelLive.handle_info/2
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/channel.ex:360: Phoenix.LiveView.Channel.handle_info/2
    (stdlib 6.2.2) gen_server.erl:2345: :gen_server.try_handle_info/3
    (stdlib 6.2.2) gen_server.erl:2433: :gen_server.handle_msg/6
    (stdlib 6.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3
Last message: {:load_character, 2119113381}
State: %{socket: #Phoenix.LiveView.Socket<id: "phx-GE2HFqWE50Jb6x6F", endpoint: EveDmvWeb.Endpoint, view: EveDmvWeb.CharacterIntelLive, parent_pid: nil, root_pid: #PID<0.2502.0>, router: EveDmvWeb.Router, assigns: %{error: nil, loading: true, stats: nil, __changed__: %{}, flash: %{}, character_id: 2119113381, live_action: nil, tab: :overview}, transport_pid: #PID<0.2408.0>, sticky?: false, ...>, components: {%{}, %{}, 1}, topic: "lv:phx-GE2HFqWE50Jb6x6F", serializer: Phoenix.Socket.V2.JSONSerializer, join_ref: "41", redirect_count: 0, upload_names: %{}, upload_pids: %{}}
[debug] MOUNT EveDmvWeb.CharacterIntelLive
  Parameters: %{"character_id" => "2119113381"}
  Session: %{"_csrf_token" => "K8aKI7r5wHGgkSWOzXc5IANU", "current_user_id" => "8281cf41-4dcd-4323-a05a-0db1c9a453f9"}
[debug] Replied in 284µs
[debug] HANDLE PARAMS in EveDmvWeb.CharacterIntelLive
  Parameters: %{"character_id" => "2119113381"}
[debug] Replied in 55µs
[debug] QUERY OK source="character_stats" db=0.7ms idle=1014.1ms
SELECT c0."id", c0."alliance_name", c0."character_name", c0."corporation_name", c0."alliance_id", c0."character_id", c0."corporation_id", c0."inserted_at", c0."updated_at", c0."active_systems", c0."aggression_index", c0."avg_gang_size", c0."batphone_probability", c0."dangerous_rating", c0."data_completeness", c0."flies_capitals", c0."frequent_associates", c0."has_logi_support", c0."home_system_id", c0."home_system_name", c0."identified_weaknesses", c0."isk_efficiency", c0."kill_death_ratio", c0."last_calculated_at", c0."prime_timezone", c0."ship_usage", c0."solo_kills", c0."solo_losses", c0."target_profile", c0."total_kills", c0."total_losses", c0."uses_cynos" FROM "character_stats" AS c0 WHERE (c0."character_id"::bigint = $1::bigint) [2119113381]
↳ anonymous fn/3 in AshPostgres.DataLayer.run_query/2, at: lib/data_layer.ex:788
[info] Analyzing character 2119113381
[debug] QUERY OK source="participants" db=0.6ms idle=1013.7ms
SELECT p0."id", p0."killmail_id", p0."killmail_time", p0."character_id", p0."character_name", p0."corporation_id", p0."corporation_name", p0."alliance_id", p0."alliance_name", p0."faction_id", p0."faction_name", p0."ship_type_id", p0."ship_name", p0."weapon_type_id", p0."weapon_name", p0."damage_done", p0."security_status", p0."is_victim", p0."final_blow", p0."is_npc", p0."solar_system_id", p0."inserted_at", p0."updated_at" FROM "participants" AS p0 WHERE ((p0."character_id" = $1) AND (p0."is_victim" = TRUE)) ORDER BY p0."killmail_time" DESC LIMIT 1 [2119113381]
↳ EveDmv.Intelligence.CharacterAnalyzer.get_character_info/1, at: lib/eve_dmv/intelligence/character_analyzer.ex:115
[debug] QUERY OK source="killmails_enriched" db=2.1ms idle=1012.7ms
SELECT k0."killmail_id", k0."killmail_time", k0."victim_character_id", k0."victim_character_name", k0."victim_corporation_id", k0."victim_corporation_name", k0."victim_alliance_id", k0."victim_alliance_name", k0."solar_system_id", k0."solar_system_name", k0."victim_ship_type_id", k0."victim_ship_name", k0."total_value", k0."ship_value", k0."fitted_value", k0."attacker_count", k0."final_blow_character_id", k0."final_blow_character_name", k0."kill_category", k0."victim_ship_category", k0."module_tags", k0."noteworthy_modules", k0."enriched_at", k0."price_data_source", k0."inserted_at", k0."updated_at" FROM "killmails_enriched" AS k0 INNER JOIN "participants" AS p1 ON p1."killmail_id" = k0."killmail_id" WHERE ((p1."character_id" = $1) AND (k0."killmail_time" >= $2)) ORDER BY k0."killmail_time" DESC [2119113381, ~U[2025-03-31 13:40:11Z]]
↳ EveDmv.Intelligence.CharacterAnalyzer.get_recent_killmails/1, at: lib/eve_dmv/intelligence/character_analyzer.ex:163
[error] GenServer #PID<0.2504.0> terminating
** (ArgumentError) schema EveDmv.Killmails.KillmailEnriched does not have association or embed :participants
    (elixir 1.17.3) lib/enum.ex:2531: Enum."-reduce/3-lists^foldl/2-0-"/3
    (ecto 3.13.2) lib/ecto/repo/queryable.ex:247: Ecto.Repo.Queryable.execute/4
    (ecto 3.13.2) lib/ecto/repo/queryable.ex:19: Ecto.Repo.Queryable.all/3
    (eve_dmv 0.1.0) lib/eve_dmv/intelligence/character_analyzer.ex:163: EveDmv.Intelligence.CharacterAnalyzer.get_recent_killmails/1
    (eve_dmv 0.1.0) lib/eve_dmv/intelligence/character_analyzer.ex:42: EveDmv.Intelligence.CharacterAnalyzer.analyze_character/1
    (eve_dmv 0.1.0) lib/eve_dmv_web/live/character_intel_live.ex:51: EveDmvWeb.CharacterIntelLive.handle_info/2
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/channel.ex:360: Phoenix.LiveView.Channel.handle_info/2
    (stdlib 6.2.2) gen_server.erl:2345: :gen_server.try_handle_info/3
    (stdlib 6.2.2) gen_server.erl:2433: :gen_server.handle_msg/6
    (stdlib 6.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3
Last message: {:load_character, 2119113381}
State: %{socket: #Phoenix.LiveView.Socket<id: "phx-GE2HFqWE50Jb6x6F", endpoint: EveDmvWeb.Endpoint, view: EveDmvWeb.CharacterIntelLive, parent_pid: nil, root_pid: #PID<0.2504.0>, router: EveDmvWeb.Router, assigns: %{error: nil, loading: true, stats: nil, __changed__: %{}, flash: %{}, character_id: 2119113381, live_action: nil, tab: :overview}, transport_pid: #PID<0.2408.0>, sticky?: false, ...>, components: {%{}, %{}, 1}, topic: "lv:phx-GE2HFqWE50Jb6x6F", serializer: Phoenix.Socket.V2.JSONSerializer, join_ref: "42", redirect_count: 0, upload_names: %{}, upload_pids: %{}}
iex(1)> 
BREAK: (a)bort (A)bort with dump (c)ontinue (p)roc info (i)nfo
```

### 2.2 Kill Feed Interactions
- [ ] **Click character name** - Should navigate to character intelligence 
      - unable to acess
- [X] **System statistics** - Should show hot zones/activity data
    - we should allow filter here / and potentially allow link to map api for auto filter
- [X] **Page updates** - New kills appear without refresh
- [X] **Auto-scroll behavior** - Should handle new content gracefully
- [X] **Loading states** - Should show appropriate loading indicators

**Expected**: Live-updating kill feed with properly formatted data and working links

---

## Test Suite 3: Character Intelligence

### 3.1 Character Intel Page (`/intel/:character_id`)
**Test with multiple character IDs from recent killmails** - unable to access

- [ ] **Direct navigation** - Enter URL with character ID
- [ ] **From kill feed** - Click character name from feed
- [ ] **Character header** - Shows name, corporation, alliance
- [ ] **Danger rating** - 1-5 star rating display
- [ ] **Tabbed interface** - Multiple tabs for different analysis

### 3.2 Intel Tabs Content
- [ ] **Overview tab** - General character information
- [ ] **Ship usage patterns** - Shows preferred ships
- [ ] **Associates tracking** - Who they fly with
- [ ] **Geographic activity** - System/region preferences
- [ ] **Weakness identification** - Tactical analysis
- [ ] **Recent activity** - Latest kills/losses

### 3.3 Intel Data Quality
- [ ] **Real data populated** - Not just placeholder text
- [ ] **Accurate metrics** - K/D ratios, ISK efficiency
- [ ] **Time-based data** - Recent vs historical analysis
- [ ] **Interactive elements** - Clickable ship types, systems
- [ ] **Error handling** - Graceful handling of unknown characters

**Expected**: Comprehensive character analysis with accurate EVE data

---

## Test Suite 4: Player Analytics

### 4.1 Player Profile Page (`/player/:character_id`)
- [ ] **Profile header** - Character info with stats overview
    - page loads, but no character information, and generate stats gives this error
    ```
    [error] GenServer #PID<0.2666.0> terminating
** (ArgumentError) schema EveDmv.Killmails.KillmailEnriched does not have association or embed :participants
    (elixir 1.17.3) lib/enum.ex:2531: Enum."-reduce/3-lists^foldl/2-0-"/3
    (ecto 3.13.2) lib/ecto/repo/queryable.ex:247: Ecto.Repo.Queryable.execute/4
    (ecto 3.13.2) lib/ecto/repo/queryable.ex:19: Ecto.Repo.Queryable.all/3
    (eve_dmv 0.1.0) lib/eve_dmv/intelligence/character_analyzer.ex:163: EveDmv.Intelligence.CharacterAnalyzer.get_recent_killmails/1
    (eve_dmv 0.1.0) lib/eve_dmv/intelligence/character_analyzer.ex:42: EveDmv.Intelligence.CharacterAnalyzer.analyze_character/1
    (eve_dmv 0.1.0) lib/eve_dmv_web/live/player_profile_live.ex:107: EveDmvWeb.PlayerProfileLive.create_player_stats/1
    (eve_dmv 0.1.0) lib/eve_dmv_web/live/player_profile_live.ex:72: EveDmvWeb.PlayerProfileLive.handle_event/3
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/channel.ex:509: anonymous fn/3 in Phoenix.LiveView.Channel.view_handle_event/3
    (telemetry 1.3.0) /workspace/deps/telemetry/src/telemetry.erl:324: :telemetry.span/3
    (phoenix_live_view 1.0.17) lib/phoenix_live_view/channel.ex:260: Phoenix.LiveView.Channel.handle_info/2
    (stdlib 6.2.2) gen_server.erl:2345: :gen_server.try_handle_info/3
    (stdlib 6.2.2) gen_server.erl:2433: :gen_server.handle_msg/6
    (stdlib 6.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3
Last message: %Phoenix.Socket.Message{topic: "lv:phx-GE2HRRuwCICh1TGC", event: "event", payload: %{"event" => "generate_stats", "type" => "click", "value" => %{"value" => ""}}, ref: "12", join_ref: "4"}
State: %{socket: #Phoenix.LiveView.Socket<id: "phx-GE2HRRuwCICh1TGC", endpoint: EveDmvWeb.Endpoint, view: EveDmvWeb.PlayerProfileLive, parent_pid: nil, root_pid: #PID<0.2666.0>, router: EveDmvWeb.Router, assigns: %{error: nil, loading: false, __changed__: %{}, current_user: %EveDmv.Users.User{id: "8281cf41-4dcd-4323-a05a-0db1c9a453f9", eve_character_id: 2115778369, eve_character_name: "Astrella Esubria", eve_corporation_id: nil, eve_corporation_name: nil, eve_alliance_id: nil, eve_alliance_name: nil, token_expires_at: ~U[2025-06-29 13:57:49Z], scopes: [], last_login_at: ~U[2025-06-29 13:37:50Z], inserted_at: ~U[2025-06-29 11:11:09.523942Z], updated_at: ~U[2025-06-29 13:37:50.167776Z], __meta__: #Ecto.Schema.Metadata<:loaded, "users">}, flash: %{}, character_id: 92838268, live_action: nil, player_stats: nil, character_intel: nil}, transport_pid: #PID<0.2659.0>, sticky?: false, ...>, components: {%{}, %{}, 1}, topic: "lv:phx-GE2HRRuwCICh1TGC", serializer: Phoenix.Socket.V2.JSONSerializer, join_ref: "4", redirect_count: 0, upload_names: %{}, upload_pids: %{}}
[debug] Cleaned up 4 expired cache entries
[debug] MOUNT EveDmvWeb.PlayerProfileLive
  Parameters: %{"character_id" => "92838268"}
  Session: %{"_csrf_token" => "K8aKI7r5wHGgkSWOzXc5IANU", "current_user_id" => "8281cf41-4dcd-4323-a05a-0db1c9a453f9"}
[debug] QUERY OK source="users" db=0.8ms idle=1327.5ms
```
- [ ] **Performance metrics** - Kill/death ratios, ISK efficiency
- [ ] **Activity timeline** - Historical performance data
- [ ] **Solo vs gang analysis** - Performance breakdown by engagement type
- [ ] **Ship performance** - Effectiveness by ship type
- [ ] **Charts/visualizations** - Data presented clearly

### 4.2 Analytics Accuracy
- [ ] **Calculation accuracy** - Verify math on displayed metrics
- [ ] **Data recency** - Shows recent activity appropriately
- [ ] **Comparison features** - Relative performance indicators
- [ ] **Export functionality** - Any data export options

**Expected**: Detailed player analytics with accurate calculations

---

## Test Suite 5: Corporation Intelligence

### 5.1 Corporation Page (`/corp/:corporation_id`) - page does not load
**Use corporation IDs from active characters**
```
no function clause matching in Float.round/2
# FunctionClauseError at GET /corp/98759555

Exception:

    ** (FunctionClauseError) no function clause matching in Float.round/2
        (elixir 1.17.3) lib/float.ex:347: Float.round(0, 2)
        (eve_dmv 0.1.0) lib/eve_dmv_web/live/corporation_live.ex:195: EveDmvWeb.CorporationLive.calculate_corp_stats/1
        (eve_dmv 0.1.0) lib/eve_dmv_web/live/corporation_live.ex:26: EveDmvWeb.CorporationLive.mount/3
        (phoenix_live_view 1.0.17) lib/phoenix_live_view/utils.ex:348: anonymous fn/6 in Phoenix.LiveView.Utils.maybe_call_live_view_mount!/5
        (telemetry 1.3.0) /workspace/deps/telemetry/src/telemetry.erl:324: :telemetry.span/3
        (phoenix_live_view 1.0.17) lib/phoenix_live_view/static.ex:321: Phoenix.LiveView.Static.call_mount_and_handle_params!/5
        (phoenix_live_view 1.0.17) lib/phoenix_live_view/static.ex:155: Phoenix.LiveView.Static.do_render/4
        (phoenix_live_view 1.0.17) lib/phoenix_live_view/controller.ex:39: Phoenix.LiveView.Controller.live_render/3
        (phoenix 1.7.21) lib/phoenix/router.ex:484: Phoenix.Router.__call__/5
        (eve_dmv 0.1.0) lib/eve_dmv_web/endpoint.ex:1: EveDmvWeb.Endpoint.plug_builder_call/2
        (eve_dmv 0.1.0) deps/plug/lib/plug/debugger.ex:155: EveDmvWeb.Endpoint."call (overridable 3)"/2
        (eve_dmv 0.1.0) lib/eve_dmv_web/endpoint.ex:1: EveDmvWeb.Endpoint.call/2
        (phoenix 1.7.21) lib/phoenix/endpoint/sync_code_reload_plug.ex:22: Phoenix.Endpoint.SyncCodeReloadPlug.do_call/4
        (bandit 1.7.0) lib/bandit/pipeline.ex:131: Bandit.Pipeline.call_plug!/2
        (bandit 1.7.0) lib/bandit/pipeline.ex:42: Bandit.Pipeline.run/5
        (bandit 1.7.0) lib/bandit/http1/handler.ex:13: Bandit.HTTP1.Handler.handle_data/3
        (bandit 1.7.0) lib/bandit/delegating_handler.ex:18: Bandit.DelegatingHandler.handle_data/3
        (bandit 1.7.0) lib/bandit/delegating_handler.ex:8: Bandit.DelegatingHandler.handle_continue/2
        (stdlib 6.2.2) gen_server.erl:2335: :gen_server.try_handle_continue/3
        (stdlib 6.2.2) gen_server.erl:2244: :gen_server.loop/7
    

Code:

`lib/float.ex`

    342     # This implementation is slow since it relies on big integers.
    343     # Faster implementations are available on more recent papers
    344     # and could be implemented in the future.
    345     def round(float, precision \\ 0)
    346   
    347>    def round(float, 0) when float == 0.0, do: float
    348   
    349     def round(float, 0) when is_float(float) do
    350       case float |&gt; :erlang.round() |&gt; :erlang.float() do
    351         zero when zero == 0.0 and float &lt; 0.0 -&gt; -0.0
    352         rounded -&gt; rounded
    
  Called with 2 arguments

  * `0`
  * `2`
  
  Attempted function clauses (showing 4 out of 4)

     def round(float, 0) when float == 0.0
     def round(float, 0) when is_float(float)
     def round(float, precision) when is_float(float) and is_integer(precision) and precision &gt;= 0 and precision &lt;= 15
     def round(float, precision) when is_float(float)
    

`lib/eve_dmv_web/live/corporation_live.ex`

    190       %{
    191         total_members: total_members,
    192         total_kills: total_kills,
    193         total_losses: total_losses,
    194         total_activity: total_activity,
    195>        kill_death_ratio: Float.round(kd_ratio, 2),
    196         avg_activity_per_member: Float.round(avg_activity, 1),
    197         most_active_member: most_active,
    198         active_members: active_members
    199       }
    200     end
    
`lib/eve_dmv_web/live/corporation_live.ex`

    21         {corporation_id, &quot;&quot;} -&gt;
    22           # Load corporation data
    23           corp_info = load_corporation_info(corporation_id)
    24           members = load_corp_members(corporation_id)
    25           recent_activity = load_recent_activity(corporation_id)
    26>          corp_stats = calculate_corp_stats(members)
    27   
    28           socket =
    29             socket
    30             |&gt; assign(:corporation_id, corporation_id)
    31             |&gt; assign(:corp_info, corp_info)
    
`lib/phoenix_live_view/utils.ex`

    343           %{socket: socket, params: params, session: session, uri: uri},
    344           fn -&gt;
    345             socket =
    346               case Lifecycle.mount(params, session, socket) do
    347                 {:cont, %Socket{} = socket} when exported? -&gt;
    348>                  view.mount(params, session, socket)
    349   
    350                 {_, %Socket{} = socket} -&gt;
    351                   {:ok, socket}
    352               end
    353               |&gt; handle_mount_result!({view, :mount, 3})
    
`/workspace/deps/telemetry/src/telemetry.erl`

    319           EventPrefix ++ [start],
    320           #{monotonic_time =&gt; StartTime, system_time =&gt; erlang:system_time()},
    321           merge_ctx(StartMetadata, DefaultCtx)
    322       ),
    323   
    324>      try SpanFunction() of
    325         {Result, StopMetadata} -&gt;
    326             StopTime = erlang:monotonic_time(),
    327             execute(
    328                 EventPrefix ++ [stop],
    329                 #{duration =&gt; StopTime - StartTime, monotonic_time =&gt; StopTime},
    
`lib/phoenix_live_view/static.ex`

    316   
    317     defp call_mount_and_handle_params!(socket, view, session, params, uri) do
    318       mount_params = if socket.router, do: params, else: :not_mounted_at_router
    319   
    320       socket
    321>      |&gt; Utils.maybe_call_live_view_mount!(view, mount_params, session, uri)
    322       |&gt; mount_handle_params(view, params, uri)
    323       |&gt; case do
    324         {:noreply, %Socket{redirected: {:live, _, _}} = socket} -&gt;
    325           {:stop, socket}
    326   
    
`lib/phoenix_live_view/static.ex`

    150           action,
    151           flash,
    152           host_uri
    153         )
    154   
    155>      case call_mount_and_handle_params!(socket, view, mount_session, conn.params, request_url) do
    156         {:ok, socket} -&gt;
    157           data_attrs = [
    158             phx_session: sign_root_session(socket, router, view, to_sign_session, live_session),
    159             phx_static: sign_static_token(socket)
    160           ]
    
`lib/phoenix_live_view/controller.ex`

    34           end
    35         end
    36   
    37     &quot;&quot;&quot;
    38     def live_render(%Plug.Conn{} = conn, view, opts \\ []) do
    39>      case LiveView.Static.render(conn, view, opts) do
    40         {:ok, content, socket_assigns} -&gt;
    41           conn
    42           |&gt; Plug.Conn.fetch_query_params()
    43           |&gt; ensure_format()
    44           |&gt; Phoenix.Controller.put_view(LiveView.Static)
    
`lib/phoenix/router.ex`

    479           :telemetry.execute([:phoenix, :router_dispatch, :stop], measurements, metadata)
    480           halted_conn
    481   
    482         %Plug.Conn{} = piped_conn -&gt;
    483           try do
    484>            plug.call(piped_conn, plug.init(opts))
    485           else
    486             conn -&gt;
    487               measurements = %{duration: System.monotonic_time() - start}
    488               metadata = %{metadata | conn: conn}
    489               :telemetry.execute([:phoenix, :router_dispatch, :stop], measurements, metadata)
    
`lib/eve_dmv_web/endpoint.ex`

    1>  defmodule EveDmvWeb.Endpoint do
    2     @moduledoc &quot;&quot;&quot;
    3     Phoenix endpoint for the EVE DMV web application.
    4   
    5     Handles HTTP requests, WebSocket connections, and static file serving
    6     for the EVE Online PvP data tracking application.
    
`deps/plug/lib/plug/debugger.ex`

    150             case conn do
    151               %Plug.Conn{path_info: [&quot;__plug__&quot;, &quot;debugger&quot;, &quot;action&quot;], method: &quot;POST&quot;} -&gt;
    152                 Plug.Debugger.run_action(conn)
    153   
    154               %Plug.Conn{} -&gt;
    155>                super(conn, opts)
    156             end
    157           rescue
    158             e in Plug.Conn.WrapperError -&gt;
    159               %{conn: conn, kind: kind, reason: reason, stack: stack} = e
    160               Plug.Debugger.__catch__(conn, kind, reason, stack, @plug_debugger)
    
`lib/eve_dmv_web/endpoint.ex`

    1>  defmodule EveDmvWeb.Endpoint do
    2     @moduledoc &quot;&quot;&quot;
    3     Phoenix endpoint for the EVE DMV web application.
    4   
    5     Handles HTTP requests, WebSocket connections, and static file serving
    6     for the EVE Online PvP data tracking application.
    
`lib/phoenix/endpoint/sync_code_reload_plug.ex`

    17   
    18     def call(conn, {endpoint, opts}), do: do_call(conn, endpoint, opts, true)
    19   
    20     defp do_call(conn, endpoint, opts, retry?) do
    21       try do
    22>        endpoint.call(conn, opts)
    23       rescue
    24         exception in [UndefinedFunctionError] -&gt;
    25           case exception do
    26             %UndefinedFunctionError{module: ^endpoint} when retry? -&gt;
    27               # Sync with the code reloader and retry once
    
`lib/bandit/pipeline.ex`

    126       end
    127     end
    128   
    129     @spec call_plug!(Plug.Conn.t(), plug_def()) :: Plug.Conn.t() | no_return()
    130     defp call_plug!(%Plug.Conn{} = conn, {plug, plug_opts}) when is_atom(plug) do
    131>      case plug.call(conn, plug_opts) do
    132         %Plug.Conn{} = conn -&gt; conn
    133         other -&gt; raise(&quot;Expected #{plug}.call/2 to return %Plug.Conn{} but got: #{inspect(other)}&quot;)
    134       end
    135     end
    136   
    
`lib/bandit/pipeline.ex`

    37         conn = build_conn!(transport, method, request_target, headers, conn_data, opts)
    38         span = Bandit.Telemetry.start_span(:request, measurements, Map.put(metadata, :conn, conn))
    39   
    40         try do
    41           conn
    42>          |&gt; call_plug!(plug)
    43           |&gt; maybe_upgrade!()
    44           |&gt; case do
    45             {:no_upgrade, conn} -&gt;
    46               %Plug.Conn{adapter: {_mod, adapter}} = conn = commit_response!(conn)
    47               Bandit.Telemetry.stop_span(span, adapter.metrics, %{conn: conn})
    
`lib/bandit/http1/handler.ex`

    8     def handle_data(data, socket, state) do
    9       transport = %Bandit.HTTP1.Socket{socket: socket, buffer: data, opts: state.opts}
    10       connection_span = ThousandIsland.Socket.telemetry_span(socket)
    11       conn_data = Bandit.SocketHelpers.conn_data(socket)
    12   
    13>      case Bandit.Pipeline.run(transport, state.plug, connection_span, conn_data, state.opts) do
    14         {:ok, transport} -&gt; maybe_keepalive(transport, state)
    15         {:error, _reason} -&gt; {:close, state}
    16         {:upgrade, _transport, :websocket, opts} -&gt; do_websocket_upgrade(opts, state)
    17       end
    18     end
    
`lib/bandit/delegating_handler.ex`

    13       |&gt; handle_bandit_continuation(socket)
    14     end
    15   
    16     @impl ThousandIsland.Handler
    17     def handle_data(data, socket, %{handler_module: handler_module} = state) do
    18>      handler_module.handle_data(data, socket, state)
    19       |&gt; handle_bandit_continuation(socket)
    20     end
    21   
    22     @impl ThousandIsland.Handler
    23     def handle_shutdown(socket, %{handler_module: handler_module} = state) do
    
`lib/bandit/delegating_handler.ex`

    3     # Delegates all implementation of the ThousandIsland.Handler behaviour
    4     # to an implementation specified in state. Allows for clean separation
    5     # between protocol implementations &amp; friction free protocol selection &amp;
    6     # upgrades.
    7   
    8>    use ThousandIsland.Handler
    9   
    10     @impl ThousandIsland.Handler
    11     def handle_connection(socket, %{handler_module: handler_module} = state) do
    12       handler_module.handle_connection(socket, state)
    13       |&gt; handle_bandit_continuation(socket)
    
`gen_server.erl`

    No code available.

`gen_server.erl`

    No code available.


## Connection details

### Params

    %{"corporation_id" => "98759555"}

### Request info

  * URI: http://localhost:4010/corp/98759555
  * Query string: 

### Headers
  
  * accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8
  * accept-encoding: gzip, deflate, br, zstd
  * accept-language: en-US,en;q=0.9
  * cache-control: no-cache
  * connection: keep-alive
  * cookie: session=MTc1MDgyMjEwMnxEWDhFQVFMX2dBQUJFQUVRQUFEX2tfLUFBQUVHYzNSeWFXNW5EQk1BRVhWelpYSmZjMlZ6YzJsdmJsOXFjMjl1Qm5OMGNtbHVad3hxQUdoN0ltMWhhVzVmWTJoaGNtRmpkR1Z5WDJsa0lqb3lNVEUxTnpVME1UY3lMQ0poYkd4ZllYVjBhR1Z1ZEdsallYUmxaRjkxYzJWeWN5STZXekl4TVRVM05UUXhOekpkTENKd1pXNWthVzVuWDNWd1pHRjBaWE1pT25SeWRXVXNJbVYwWVdjaU9pSWlmUT09fH1ZuUWHegc8PGNI2VtObyYE262Clx6FsxotGBl_vItn; _wanderer_app_key=SFMyNTY.g3QAAAACbQAAAAtfY3NyZl90b2tlbm0AAAAYMkR5THR0dXhyOU45TVZsVU1wWnMtRW5xbQAAAAd1c2VyX2lkbQAAACQxZjdiYzZkZi0wOTRiLTQ0ODEtOTEzOS0xMjkyNzdkOGFjZDk.5EC3cC0ADHIJYC9kuxWklRpy21LpNIYJH5T5GSc6K0c; _eve_dmv_key=SFMyNTY.g3QAAAACbQAAAAtfY3NyZl90b2tlbm0AAAAYSzhhS0k3cjV3SEdna1NXT3pYYzVJQU5VbQAAAA9jdXJyZW50X3VzZXJfaWRtAAAAJDgyODFjZjQxLTRkY2QtNDMyMy1hMDVhLTBkYjFjOWE0NTNmOQ.CBWCfeBDGB88B134sW6fYeVDEgPFtnACRVN_d7_vT5w
  * host: localhost:4010
  * pragma: no-cache
  * sec-ch-ua: "Brave";v="137", "Chromium";v="137", "Not/A)Brand";v="24"
  * sec-ch-ua-mobile: ?0
  * sec-ch-ua-platform: "Windows"
  * sec-fetch-dest: document
  * sec-fetch-mode: navigate
  * sec-fetch-site: none
  * sec-fetch-user: ?1
  * sec-gpc: 1
  * upgrade-insecure-requests: 1
  * user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36

### Session

    %{"_csrf_token" => "K8aKI7r5wHGgkSWOzXc5IANU", "current_user_id" => "8281cf41-4dcd-4323-a05a-0db1c9a453f9"}

lib/float.ex
  # This implementation is slow since it relies on big integers.
  # Faster implementations are available on more recent papers
  # and could be implemented in the future.
  def round(float, precision \\ 0)
  def round(float, 0) when float == 0.0, do: float
  def round(float, 0) when is_float(float) do
    case float |> :erlang.round() |> :erlang.float() do
      zero when zero == 0.0 and float < 0.0 -> -0.0
      rounded -> rounded
      ```
- [ ] **Corporation header** - Name, ticker, member count
- [ ] **Member list** - Active corporation members
- [ ] **Activity indicators** - Recent activity per member
- [ ] **Top pilots** - Most active/effective members
- [ ] **Recent kills** - Corporation's recent killmails
- [ ] **Corporation stats** - Aggregate performance metrics

### 5.2 Corp Navigation
- [ ] **Member links** - Click member to view their intel
- [ ] **Kill links** - Click kills to view details
- [ ] **Sorting options** - Sort members by activity/performance
- [ ] **Time filters** - Filter by recent activity periods

**Expected**: Corporation overview with member activity tracking

---

## Test Suite 6: Surveillance System

### 6.1 Surveillance Page (`/surveillance`)
**Requires authentication**

- [X] **Access control** - Redirects to login if not authenticated
- [X] **Profile list** - Shows user's existing surveillance profiles
- [X] **Create profile button** - Opens profile creation modal
- [X] **Engine statistics** - Shows matching engine status
- [X] **Recent matches** - Displays recent profile matches

### 6.2 Profile Creation
- [X] **Create modal** - Opens when clicking "Create Profile"
- [X] **Form fields** - Name, description, filter rules
- [X] **JSON validation** - Accepts valid filter JSON
- [X] **Error handling** - Shows errors for invalid input
- [ ] **Profile saving** - Successfully creates new profiles
   - dopesn't appear to save, 
- [ ] **Auto-reload** - Matching engine reloads profiles

### 6.3 Profile Management - unable to test
- [ ] **Toggle active/inactive** - Enable/disable profiles
- [ ] **Edit profiles** - Modify existing profiles
- [ ] **Delete profiles** - Remove profiles with confirmation
- [ ] **Profile status** - Visual indicators for active/inactive

### 6.4 Notifications System - unable to test
- [ ] **Real-time notifications** - New matches appear immediately
- [ ] **Notification count** - Unread notification badge
- [ ] **Notification list** - View all notifications
- [ ] **Mark as read** - Individual and bulk read actions
- [ ] **Notification details** - Rich killmail information
- [ ] **Priority indicators** - High/urgent notification styling

**Expected**: Full surveillance profile management with real-time notifications

---

## Test Suite 7: Cross-Page Navigation

### 7.1 Navigation Flow
- [x] **Kill feed → Character intel** - Click character names
- [x] **Character intel → Player profile** - Navigation between analysis views
- [x] **Character intel → Corporation** - Click corporation links
- [x] **Corporation → Member intel** - Click member names
- [x] **Back navigation** - Browser back button works correctly
- [x] **Bookmarkable URLs** - All pages work with direct URLs

### 7.2 URL Handling
- [ ] **Invalid character IDs** - Graceful error handling - displays page as normal, doesn't appear to validate
- [ ] **Non-existent corporations** - Appropriate error messages - uanble to test
- [X] **Malformed URLs** - Redirect to safe pages
- [X] **Authentication redirects** - Proper login flow for protected pages

**Expected**: Seamless navigation between all sections with proper error handling

---

## Test Suite 8: Real-Time Features

### 8.1 Live Updates
- [X] **Kill feed updates** - New killmails appear automatically
- [?] **Surveillance alerts** - Real-time profile match notifications
- [?] **Character intel refresh** - Data updates with new activity
- [x] **WebSocket connection** - Check browser dev tools for stable connection

### 8.2 Performance Testing
- [x] **Page load times** - All pages load within 3 seconds
- [x] **Real-time responsiveness** - Updates appear within 10 seconds
- [x] **Memory usage** - No memory leaks during extended use
- [x] **Multiple tabs** - App works correctly in multiple browser tabs

**Expected**: Responsive real-time updates without performance issues

---

## Test Suite 9: Error Handling & Edge Cases

### 9.1 Network Issues
- [ ] **Offline handling** - Graceful degradation when offline
- [ ] **API failures** - Appropriate error messages for external API issues
- [ ] **Database errors** - Fallback behavior for database issues
- [ ] **Timeout handling** - Long-running requests handled appropriately

### 9.2 Data Edge Cases
- [ ] **Empty datasets** - Handle characters/corps with no data
- [ ] **Large datasets** - Performance with high-activity characters
- [ ] **Invalid data** - Graceful handling of malformed killmail data
- [ ] **Missing data** - Handle incomplete character/corp information

### 9.3 Browser Compatibility
- [ ] **Chrome** - Full functionality
- [ ] **Firefox** - Full functionality  
- [ ] **Safari** - Full functionality
- [ ] **Mobile browsers** - Responsive design works
- [ ] **JavaScript disabled** - Graceful degradation

**Expected**: Robust error handling and cross-browser compatibility

---

## Test Suite 10: Security & Authentication

### 10.1 Access Control
- [ ] **Protected routes** - Unauthenticated users redirected to login
- [ ] **Session security** - Sessions expire appropriately
- [ ] **CSRF protection** - Forms protected against CSRF attacks
- [ ] **Data isolation** - Users only see their own surveillance profiles

### 10.2 Input Validation
- [ ] **XSS prevention** - User input properly escaped
- [ ] **SQL injection** - Database queries properly parameterized
- [ ] **File upload security** - If any file uploads exist
- [ ] **Rate limiting** - API calls appropriately rate limited

**Expected**: Secure application with proper access controls

---

## Bug Reporting Template

When you find issues, please report them using this format:

### Bug Report #___

**Page/Feature**: _____________  
**Severity**: Critical / High / Medium / Low  
**Browser**: _____________  
**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Behavior**: 

**Actual Behavior**: 

**Screenshots**: 

**Console Errors**: 

**Additional Notes**: 

---

## Test Results Summary

**Total Test Cases**: _____ / _____  
**Passed**: _____  
**Failed**: _____  
**Blocked**: _____  

**Critical Issues**: _____  
**High Priority Issues**: _____  
**Medium Priority Issues**: _____  
**Low Priority Issues**: _____  

**Overall Assessment**: 
- [ ] Ready for production
- [ ] Minor fixes needed
- [ ] Major fixes required
- [ ] Significant rework needed

**Tester Signature**: _____________  
**Date Completed**: _____________