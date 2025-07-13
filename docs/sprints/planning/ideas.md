Below is a structured review of the Eve DMV code‑base as provided in repomix‑output.xml. I focus on issues that will have the largest quality, performance and architectural impact during your upcoming “quality sprint”, beyond simply driving Credo, Dialyzer and compile warnings to zero.

1 · High‑impact findings & recommendations
Area Finding Impact Recommended action
Task supervision Three near‑identical supervisors – UiTaskSupervisor, BackgroundTaskSupervisor, RealtimeTaskSupervisor – each duplicate ~100 lines of configuration/monitoring logic Code duplication, diverging behaviour, harder to evolve Extract a GenericTaskSupervisor behaviour + macro so that each concrete module supplies only its policy (timeouts, limits). See sample implementation below.
Process dictionary Task metadata is stored with Process.put/2 Hidden mutable state, leaks on crash, Dialyzer blind‑spot Replace with ETS table scoped to the supervisor, or pass metadata in process messages/state.
Timeout & shutdown Many helpers call Task.await/Task.yield but fall back to Task.shutdown(task, :brutal_kill) which can silently drop work Lost work, difficult debugging Prefer Task.Supervisor + DynamicSupervisor.one_for_one with :shutdown values tuned to task duration; propagate explicit error tuples.
System commands in runtime code System.cmd("mix", ["credo", …]) is executed inside application processes Heavy I/O, blocks schedulers, security risk in prod Move static‑analysis runners to CI; keep only telemetry API in application code.
Secret detection & handling Scripts scan for secrets but code still interpolates tokens from ENV at runtime, logging can leak them (e.g. Logger.warning("…#{inspect(reason)}") when reason may contain credential) Compliance & incident risk Add Logger.filter_parameters/1 (or Scrubbers) and never log full exception structs that might embed secrets.
Large modules Automated script already flags >300‑line files ; several supervisors & pipelines exceed this Cognitive load, Credo complexity warnings After extracting common supervision code, most flagged files should shrink naturally.
Observability gaps Telemetry events exist for tasks , but no central span context nor linkage to web‑request IDs Harder to trace latency spikes Add :otel spans around start_task/run_with_monitoring and propagate %{trace_id: …} in metadata.

2 · Quick wins (1–2 days)
Turn on compiler warnings‑as‑errors in mix.exs:

elixir
Copy
elixirc_options: [warnings_as_errors: Mix.env() != :prod]
Enable Credo’s “strict” preset and automatically fail CI if issue count > N (ties into your goal).

Run mix xref graph --label compile-connected to catch cyclic dependencies between contexts; break them with behaviours or boundary modules.

Add property‑based tests (e.g. StreamData) for the killmail pipeline to guard against malformed JSON (currently only unit tests cover a few cases ).

3 · Detailed observations & guidance
3.1 Concurrency & supervision
Deduplicate supervisors. Each module repeats config constants, run*with*\* helpers, metric emission etc. A single macro can generate a concrete supervisor in ~10 loc:

elixir
Copy
defmodule EveDmv.TaskSupervisor do
@callback config() :: keyword()

defmacro **using**(opts) do
quote do
use DynamicSupervisor
require Logger
@behaviour EveDmv.TaskSupervisor
@impl DynamicSupervisor
def init(\_), do: DynamicSupervisor.init(strategy: :one_for_one, max_children: Keyword.fetch!(config(), :max_children)) # …shared run_with_monitoring/2 etc, using config() for limits…
end
end
end
Each concrete supervisor then becomes:

elixir
Copy
defmodule EveDmv.Workers.UiTaskSupervisor do
use EveDmv.TaskSupervisor

@impl EveDmv.TaskSupervisor
def config,
do: [max_task_duration: 30_000, warning_duration: 10_000, max_children: 100]
end
Benefit: removes ~250 duplicated lines, guarantees consistent logging/telemetry.

Process dictionary ⇒ ETS: replace Process.put(:task*info, …) with :ets.insert/2 keyed by pid. On handle_info({:DOWN, *, :process, pid, \_}, state) clean up row.

3.2 Resource & error handling
Graceful shutdown: use DynamicSupervisor.start_child/2 with child spec shutdown: timeout + 1_000. Avoid brutal kills unless process misbehaves.

Back‑pressure: Task.async_stream/3 uses max_concurrency: 10 ; measure typical task latency and right‑size. Consider partitioned GenStage if batch size grows.

3.3 Observability
Emit OpenTelemetry spans from start_task/3, run_with_resource_monitoring/5.

Surface queue length & capacity utilisation already computed in supervisors (e.g. capacity_used field ) via :telemetry.execute.

3.4 Build & deployment
Docker optimisations:

Cache assets/node_modules by copying only assets/package\* before npm install.

After mix release, slim runtime image to FROM debian:bookworm‑slim (openssl musl issue on alpine 3.18 sometimes breaks SSL).

Health‑check endpoints: scripts check router for “health” and “metrics” strings ; ensure you actually expose /api/health & Prometheus /metrics.

3.5 Secret hygiene
The compose file references many env vars . Add an automated check that every required secret is defined and masked in logs.

4 · Proposed refactor: generic_task_supervisor.ex
Below is a complete new file demonstrating how to centralise the common supervision logic (per your instruction to include full files for code suggestions):

elixir
Copy
defmodule EveDmv.Supervisors.GenericTaskSupervisor do
@moduledoc """
Behaviour + macro that generates purpose‑specific DynamicSupervisors
(UI, realtime, background) with consistent limits, logging and telemetry.

Usage:

      defmodule EveDmv.Workers.UiTaskSupervisor do
        use EveDmv.Supervisors.GenericTaskSupervisor,
          max_task_duration: 30_000,
          warning_duration: 10_000,
          max_children: 100,
          telemetry_prefix: [:eve_dmv, :ui_task]
      end

"""

defmacro **using**(opts) do
max_task_duration = Keyword.fetch!(opts, :max_task_duration)
warning_duration = Keyword.fetch!(opts, :warning_duration)
max_children = Keyword.fetch!(opts, :max_children)
telemetry_prefix = Keyword.get(opts, :telemetry_prefix, [:eve_dmv, :task])

    quote bind_quoted: [
            max_task_duration: max_task_duration,
            warning_duration:  warning_duration,
            max_children:      max_children,
            telemetry_prefix:  telemetry_prefix
          ] do
      use DynamicSupervisor
      require Logger

      @max_task_duration max_task_duration
      @warning_duration  warning_duration

      ## Public API ----------------------------------------------------------

      def start_link(opts \\ []),
        do: DynamicSupervisor.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

      @doc """
      Start a task function `fun` with optional `timeout` and metadata `desc`.
      """
      def start_task(fun, desc \\ "task", timeout \\ @max_task_duration) do
        timeout = min(timeout, @max_task_duration)

        spec = %{
          id: make_ref(),
          start: {Task, :start_link, [fn -> run_with_monitoring(fun, desc, timeout) end]},
          restart: :temporary,
          type: :worker,
          shutdown: timeout + 1_000
        }

        DynamicSupervisor.start_child(__MODULE__, spec)
      end

      ## DynamicSupervisor callbacks ----------------------------------------

      @impl DynamicSupervisor
      def init(_), do: DynamicSupervisor.init(strategy: :one_for_one, max_children: max_children)

      ## Internal helpers ----------------------------------------------------

      defp run_with_monitoring(fun, desc, timeout) do
        start  = System.monotonic_time(:millisecond)
        warn_t = Process.send_after(self(), :warn, @warning_duration)
        kill_t = Process.send_after(self(), :kill, timeout)

        try do
          {:ok, res} = {fun.(), nil}
          emit(:completed, start, desc)
          res
        catch
          kind, reason ->
            emit(:failed, start, desc, {kind, reason})
            :erlang.raise(kind, reason, __STACKTRACE__)
        after
          Process.cancel_timer(warn_t)
          Process.cancel_timer(kill_t)
        end
      end

      defp emit(event, start_ms, desc, err \\ nil) do
        dur = System.monotonic_time(:millisecond) - start_ms
        meta = %{description: desc}
        meas = %{duration: dur}

        :telemetry.execute(telemetry_prefix ++ [event], meas, Map.merge(meta, if(err, do: %{error: err}, else: %{})))
      end

      ## Info messages -------------------------------------------------------

      @impl true
      def handle_info(:warn, state) do
        Logger.warning("[#{__MODULE__}] task exceeding #{@warning_duration}ms")
        {:noreply, state}
      end

      def handle_info(:kill, state) do
        Logger.error("[#{__MODULE__}] task exceeded #{@max_task_duration}ms – killing")
        {:stop, :shutdown, state}
      end
    end

end
end
Drop‑in conversion of existing supervisors will remove duplicated constants, make future policy changes one‑liner edits, and keep Dialyzer specs in one place.

5 · Next steps
Merge the GenericTaskSupervisor and migrate existing supervisors.

Replace process‑dictionary tracking with ETS.

Move static‑analysis runners to CI workflow (mix credo --strict, mix dialyzer).

Add OTEL spans and Grafana dashboards for the new unified telemetry.

Address remaining Credo/Dialyzer issues – they will shrink once duplication is removed.

Plan a follow‑up sprint to tackle DB query efficiency (Repo.preload, N+1 warnings) – outside the scope of this review but likely next on the performance list.

Implementing the above should give you measurable improvements in maintainability, observability and runtime stability, and will make subsequent Credo & Dialyzer cleanup far easier. Feel free to reach out for deeper dives into any specific subsystem.

1. Module Size & Single-Responsibility
   Many modules (e.g. EveDmv.Analytics.FleetAnalyzer, EveDmv.Analytics.BattleDetector, and the LiveView controllers) exceed several hundred lines, mixing data-access, complex business logic, and presentation.

Refactor into smaller, focused modules or behaviours (e.g. separate SQL-heavy query builders from mapping/transformation logic).

Extract common utilities (e.g. date/time bucketing, log-level helpers) into shared helper modules to reduce duplication and surface reuse.

2. Raw SQL & Query Patterns
   Numerous modules use Repo.query/2 with raw SQL strings:

elixir
Copy
Edit
query = """
WITH character_killmails AS ( … )
SELECT … FROM battle_clusters …
"""
Repo.query(query, [character_id, thirty_days_ago, limit])
Risk: harder to maintain, prone to SQL injection if interpolated.

Recommendation:

Where possible, migrate to Ecto’s query DSL for composability, compile-time validation, and automatic parameterization.

Encapsulate raw queries in dedicated “SQL modules” or contexts, with proper documentation and unit tests for correctness.

3. Domain Boundaries & Context Coupling
   Your lib/eve_dmv/contexts/\* directories suggest DDD-style bounded contexts, but many “analytics” and “intelligence” modules cross-call each other directly.

Opportunity: enforce clearer API boundaries—design behaviour contracts (callbacks) or protocols between contexts.

Benefit: reduces interdependence, makes it easier to swap or mock implementations in tests.

4. Performance & Caching
   You already have some caching (e.g. EveDmv.Analytics.CacheHelper, analysis_cache.ex), but many heavy queries re-run each request.

Action: Introduce TTL-backed caches (e.g. ETS via con_cache or Redis) around expensive aggregations.

Consider: background pre-aggregation jobs (using Oban) for metrics that don’t need real-time precision.

In background workers (e.g. ShipRoleAnalysisWorker), grouping and aggregations are done in Elixir.

Tip: push more of this grouping back into the database (window functions, materialized views) where it’s usually faster.

5. Test Coverage & CI Quality Gates
   While there are many tests in test/, focus on gaps around error branches (e.g. SQL failures, empty result sets).

Ensure your CI (via quality_gates.sh, check_moduledocs.exs) actually fails on missing @moduledoc, coverage drops, or style violations.

Suggestion: integrate a coverage tool (Coveralls or ExCoveralls) to track and report untested code slices.

6. Documentation & Public API Contracts
   Some public functions lack @doc or examples, which makes onboarding harder.

Improve:

Add inline examples and type specs (@spec) especially for modules that form your public API (contexts, web controllers).

Generate generated docs (ExDoc) as part of your release pipeline to keep them up-to-date.

7. Configuration & Secrets Management
   I see raw HTTP clients and ESI credentials managed in config/\*.exs.

Best practice: extract secrets into environment variables or vaults; avoid checking anything sensitive into source.

Validate configuration at compile or application start to fail fast on missing keys.

8. Phoenix & LiveView Structuring
   Your LiveViews (e.g. KillmailLive) currently just redirect; if these are placeholders, track them in a “roadmap” so they don’t linger.

Pattern: consider a folder-per-feature structure (lib/.../live/battle/ vs. monolithic live/) to group related components, helpers, and templates.

9. Logging & Telemetry
   You sprinkle Logger.info/debug/error throughout; consider standardizing a structured log format (JSON or maps) for easier ingestion by log aggregators.

Leverage :telemetry events for critical business and performance metrics (e.g. query durations, cache hit/miss ratios) so you can build dashboards in Grafana or Prometheus.

10. Dependency Updates & Security
    Run mix deps.audit (via mix hex.audit) to catch any known vulnerabilities.

Lock down version constraints in mix.exs to avoid “latest” floating versions.

Next Steps:

Prioritize: pick one or two modules to refactor as a proof-of-concept (e.g. one of the large analytics modules).

Add benchmarks around critical paths (you already have benchmarks/).

Roll out small, disciplined PRs with CI enforcement of new quality gates (coverage thresholds, dialyzer failures as errors, credo strict configs).
