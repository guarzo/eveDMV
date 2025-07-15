# Fix Pipeline Usage Issues (Part of 742 Readability Issues)

You are an AI assistant tasked with resolving pipeline usage issues found by Credo in an Elixir Phoenix codebase. Focus ONLY on [R] "Use a function call when a pipeline is only one function long" issues.

## Instructions

1. **Single Function Pipelines**: Replace single-function pipelines with direct function calls for better readability.

2. **Pattern to Follow**:
   ```elixir
   # Before (single function pipeline)
   result = value |> SomeModule.function()
   
   # After (direct function call)
   result = SomeModule.function(value)
   ```

3. **Key Files to Address** (focus on these directories to minimize conflicts):
   - `lib/eve_dmv_web/live/universal_search_live.ex`
   - `lib/eve_dmv_web/live/system_search_live.ex`
   - `lib/eve_dmv_web/live/surveillance_profiles_live.ex`
   - `lib/eve_dmv_web/live/surveillance_live/batch_operation_service.ex`
   - `lib/eve_dmv_web/live/surveillance_alerts_live.ex`
   - `lib/eve_dmv/shared/killmail_queries.ex`
   - `lib/eve_dmv/monitoring/missing_data_tracker.ex`
   - `lib/eve_dmv/monitoring/error_recovery_worker.ex`
   - `lib/eve_dmv/eve/esi_request_client.ex`
   - `lib/eve_dmv_web/live/system_live.ex`
   - `lib/eve_dmv_web/live/surveillance_dashboard_live.ex`

4. **Transformation Examples**:
   ```elixir
   # Before
   socket |> assign(:key, value)
   
   # After
   assign(socket, :key, value)
   
   # Before  
   data |> Enum.map(&transform/1)
   
   # After
   Enum.map(data, &transform/1)
   
   # Before
   string |> String.trim()
   
   # After
   String.trim(string)
   ```

5. **Rules**:
   - Only change pipelines with exactly one function call
   - Preserve all existing functionality and behavior
   - Keep multi-step pipelines unchanged
   - Maintain proper argument order in function calls
   - Be careful with LiveView assigns and socket operations

6. **Special Cases**:
   - For LiveView: `socket |> assign(...)` becomes `assign(socket, ...)`
   - For database queries: `query |> Repo.all()` becomes `Repo.all(query)`
   - For string operations: `str |> String.trim()` becomes `String.trim(str)`

## Important Notes

- This is part of a parallel fix effort - only modify single-function pipeline issues
- Do NOT modify TODO comments, module aliases, number formatting, or other issue types  
- Focus on LiveView and web-related files to avoid conflicts with other prompts
- Run `mix compile` and basic smoke test after changes
- Preserve all existing functionality

## Success Criteria

- All single-function pipelines are converted to direct function calls
- Code compiles without errors
- LiveView functionality remains intact
- No behavioral changes in the application
- Code is more readable and follows Elixir conventions