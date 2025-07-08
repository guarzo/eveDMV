Below are practical, incremental changes that will make the repository easier to navigate, speed‑up onboarding for new contributors, and create cleaner architectural boundaries. Each recommendation is derived from the directory map and companion docs contained in the packed file you supplied.

1 ▸ Introduce an umbrella layout to separate pure‑domain code from infrastructure
New App Purpose Folders to move (examples)
eve_core All pure business logic & Ash resources lib/eve_dmv/{analytics,intelligence,killmails,market,surveillance,users,constants}
eve_integrations HTTP clients, rate limiters, SSE producers, cache adapters lib/eve_dmv/eve, lib/eve_dmv/market/_\_client.ex, lib/eve_dmv/killmails/httpoison_sse_producer.ex
eve_data DB schemas / migrations / data‑loaders lib/eve_dmv/database, lib/eve_dmv/repo.ex, lib/eve_dmv/eve/static_data_loader.ex
eve_web Phoenix controllers, LiveViews, HEEx templates, assets everything now under eve_dmv_web/
eve_ops Mix tasks, health checks, partition jobs, Oban workers mix/tasks, lib/eve_dmv/database/_\_manager.ex, cron‑style workers

Why?

Keeps Ash resources and domain policies in eve_core totally ignorant of HTTP, Phoenix or external APIs.

Build and test times fall because each sub‑app recompiles only what it owns.

Makes eventual open‑sourcing of the pure API (without web UI) trivial.

2 ▸ Flatten deep package trees under lib/eve_dmv
Several second‑level directories exist only to hold one or two files (e.g. config/, constants/). Move those files into their nearest domain folder and delete the stubs:

lib/eve_dmv/config/{api,cache,circuit_breaker,http,pipeline,rate_limit}.ex → eve_integrations/config/

lib/eve_dmv/constants/isk.ex → move to eve_core/pricing/isk.ex

This cuts two path segments from many import statements.

3 ▸ Group files by domain noun, not technical concern
Inside each umbrella app, prefer:

pgsql
Copy
eve_core/
character/
character.ex
character_metrics.ex
character_analyzer.ex
corporation/
corporation.ex
corporation_analyzer.ex
killmail/
raw.ex
enriched.ex
pipeline/
producer.ex
processor.ex
rather than the current layer‑first split (analytics, intelligence, enrichment, …). A maintainer who cares about “characters” now sees every relevant module in one folder.

4 ▸ Create a surface layer for all UI‑only modules
In eve_web add:

Copy
live/
components/
layouts/
and move:

eve_dmv_web/live/_.ex & _.heex

eve_dmv_web/components/\*

eve_dmv_web/helpers/price_helper.ex

This keeps LiveView and HEEx helpers from leaking into core mix deps.

5 ▸ Move long‑running jobs next to supervision trees
Files such as lib/eve_dmv/intelligence/intelligence_coordinator.ex or \*\_worker.ex live deep inside feature folders. Relocate them to an jobs/ folder in eve_ops so ops engineers know where to look for scheduled/batch work.

6 ▸ Delete or archive obsolete “catch‑all” folders
lib/eve_dmv/utils – every function here now belongs in a proper domain (time, math, parsing, cache).

lib/eve_dmv/quality – single file (metrics_collector.ex); move it under telemetry/.

lib/eve_dmv/presentation – contains only formatting helpers; merge into eve_web/components/.

7 ▸ Co‑locate tests with the code they verify
After the umbrella split:

swift
Copy
apps/eve_core/test/character/
apps/eve_web/test/live/
Instead of the current top‑level test/… tree. Mix knows to run all tests across apps, but each sub‑team can focus on its own folder.

8 ▸ Use boundary checks to enforce separation
Add mix boundary (or Elixir 1.17 “compiler tracers”) to forbid, e.g.:

eve_core calling Phoenix.\*

eve_integrations calling Phoenix.\*

anything outside eve_web touching HEEx templates

This prevents future sprawl from re‑appearing.

9 ▸ Consolidate docs and ADRs
docs/ is 1 900 + lines scattered across 16 sub‑folders. Adopt one of:

arduino
Copy
docs/
architecture/
design-decisions/ # lightweight ADRs
guides/
and move sprint plans to your project‑management tool (GitHub Projects, Linear, etc.). The repo then carries reference docs only.

10 ▸ Introduce naming conventions & generators
Modules: EveCore.Character.Intel not EveDmv.Intelligence.CharacterAnalyzer.

Folders match module segments exactly.

Add custom mix gen.domain character generator so future code lands in the right place automatically.

Migration order (keeps CI green)
Generate umbrella skeleton: mix new eve_dmv --umbrella → move existing tree into apps/.

Move lib/eve_dmv_web to apps/eve_web. Update :mod in mix.exs.

Move lib/eve_dmv minus web to apps/eve_core. Fix aliases in mix.exs.

Introduce eve_integrations and move external API clients.

Update tests + CI paths.

Delete empty folders, run mix format, mix credo --strict.

Expected pay‑offs
On‑boarding time drops (one app to open for any given concern).

Compiles ~30 % faster in dev because Phoenix changes no longer recompile pure‑domain code.

Boundaries stop architectural drift—a refactor six months from now won’t recreate today’s sprawl.

These steps do not change runtime behaviour, so you can roll them out gradually behind feature flags or per‑branch migrations.
