## 🤖 AI CLEANUP & QUALITY ANALYSIS PROMPT — Elixir Phoenix Edition

When re-running cleanup reviews on an Elixir Phoenix codebase, use this prompt. Tweak paths, thresholds, and tools as needed:

---
Please analyze the **`lib/`**, **`config/`**, **`test/`**, and **`priv/`** directories of this Phoenix project for **cleanup**, **code quality**, and **long-term maintainability**. Focus on:

### 1. Dead Code & Unused Artifacts  
- Unused functions, private helpers, module attributes, typespecs  
- Modules, behaviours, plugs, controllers, or contexts that are imported but never invoked  
- Obsolete test files, fixtures, factories (ExMachina), mocks (Mox)  
- Configuration keys in `config/*.exs` that aren’t referenced  
- Deprecated migrations or SQL files in `priv/repo/migrations`

### 2. Over-Engineering & Simplicity  
- Modules exceeding **300 lines** or **50 functions**—identify where to split into contexts or sub-modules  
- Excessive use of multi-arity functions when defaults would suffice  
- Deep nesting of `with` / `case` / `cond`—suggest early returns or refactoring into helper modules  
- Over-abstraction: behaviours, protocols, or builder patterns wrapping trivial logic  
- “Enterprise” patterns (event sourcing, CQRS) applied to simple CRUD flows

### 3. Structural & Naming Consistency  
- Contexts mixing unrelated domains (e.g. user logic + billing in same context)  
- Controllers handling business logic—should delegate to contexts/services  
- Templates or LiveViews with inline complex logic—should move into helpers or components  
- Duplicate module/function names across contexts  
- File and module names not matching Phoenix conventions (`MyAppWeb.FooController` in the wrong directory)

### 4. OTP & Supervision Trees  
- Poorly structured supervision trees—missing `:restart` strategies or overly broad supervisors  
- GenServers, Tasks, or Channels without proper `shutdown` timeouts  
- Processes started in controllers or LiveViews instead of supervised workers  
- Unmonitored processes (e.g. Task.async without `Task.Supervisor`)  

### 5. Ecto & Database Patterns  
- Unprefetched associations causing N+1 queries—missing `preload/2` in queries  
- Raw SQL fragments where Ecto queries suffice  
- Repeated schema definitions—DRY using shared embeddeds or macros  
- Migrations with data-transform SQL that should be in a separate data-migration task  
- Unsized pools or missing `prepare` flags for pluggable repos  

### 6. Elixir Idioms & Best Practices  
- Overuse of `any()` or no typespecs—add `@spec` for public functions  
- Missing or inconsistent `@doc` comments on public modules/functions  
- Pattern-matching on maps or keyword lists without guard clauses—risk of runtime errors  
- Use of `Enum` over `Stream` for large collections in pipelines  
- Unchecked failures in `Regex.run/2`, `Integer.parse/1`, external API calls—should handle `:error` tuples  

### 7. Testing & Coverage  
- Modules without any unit or integration tests  
- Controller/Channel tests lacking `conn`/`socket` assertions or `Plug.Test` coverage  
- No property-based tests for critical pure functions (PropEr, StreamData)  
- Missing test coverage for error paths (2xx vs 4xx/5xx in controllers)  
- Test factories creating excessive data—slow test suite

### 8. Security & Configuration  
- Hard-coded secrets or tokens in config; missing `Mix.Config` environment checks  
- Insecure parameter whitelisting in controllers; missing `Ecto.Changeset.cast/4` filters  
- Missing rate-limiting plugs or CSRF protection in LiveViews  
- Outdated dependencies flagged by `mix deps.audit` or `Dependabot`

### 9. Performance & Resource Management  
- Blocking calls (e.g. long DB transactions) in request pipeline  
- Unbounded GenServer state growth—no eviction strategy  
- Large template assigns passed to views—suggest pagination or chunking  
- Inefficient string concatenation in loops—use `IO.iodata()`  

### 10. Documentation & Maintenance  
- Missing or outdated `README.md`, `docs/`, or module docs  
- No `mix format` / `Credo` configuration in project  
- Lack of CONTRIBUTING or CODE_STYLE guidelines  
- Unused files in `assets/` (JS/CSS) or stale Webpack/Vite configs  

---

**Output Requirements**  
- **File & Line References**: list each issue with path + line numbers  
- **Priority**: mark as Critical / High / Medium / Low  
- **LOC Estimate**: approximate lines that can be removed or refactored  
- **Examples**: show before/after snippets for complex refactors  
- **Recommendations**: concrete refactoring strategies (e.g. “extract into `MyApp.Billing` context,” “replace this GenServer with DynamicSupervisor,” “use `Ecto.Multi` for atomic operations”)

**Methodology**  
1. Map directory & module layout; identify large files or hotspots  
2. Run and review `mix credo`, `dialyzer`, `excoveralls`, `mix deps.audit`  
3. Grep for patterns (`TODO`, `deprecated`, `with`, `case`)  
4. Cross-check Ecto schemas vs. actual DB usage  
5. Inspect test coverage report to find untested code  

Apply especially to  any files over **1,000 lines**.  
