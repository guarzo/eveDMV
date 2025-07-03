In priv/resource_snapshots/repo/killmails_raw/20250701041612.json at line 153,
the hash value has changed in isolation. Verify that this change reflects a
genuine update in the underlying data or state rather than a nondeterministic or
transient build artifact. If the hash changes are not deterministic, consider
locking the snapshot ordering process or excluding these volatile hash values
from source control to prevent unnecessary diffs.

In priv/resource_snapshots/repo/surveillance_profile_matches/20250701041612.json
at line 290, the hash value is changing without any actual schema or content
changes, causing unnecessary snapshot churn. Review the snapshot generation
pipeline to ensure the hash is computed deterministically based on stable
content only, or exclude volatile metadata like timestamps or non-deterministic
fields from the snapshot to prevent these noisy diffs.

In priv/resource_snapshots/repo/participants/20250701041612.json at line 505,
only the hash field was updated without changes to participant attributes,
indicating a no-op data change. Verify if any actual participant data changed
upstream; if not, either stabilize the snapshot generation to produce consistent
hashes or exclude this hash update from the snapshot to avoid unnecessary review
noise.

In lib/eve_dmv/telemetry/performance_monitor.ex lines 1 to 10, add a module
attribute or configuration map defining default slow operation thresholds for
database queries, API calls, and liveview renders. Also, implement a private
function safe_execute that wraps function execution in a try-rescue block to
catch errors, log them using Logger.error with the error details, and return an
{:error, error} tuple on failure or {:ok, result} on success. This will add
error handling and make thresholds configurable as suggested.

In lib/eve_dmv/telemetry/performance_monitor.ex lines 38 to 57, the
track_api_call function duplicates timing and telemetry logic seen elsewhere.
Refactor by extracting the timing and telemetry execution into a reusable helper
function, then call this helper from track_api_call to reduce code duplication
and improve maintainability.

In lib/eve_dmv/telemetry/performance_monitor.ex around lines 99 to 118, the
function track_liveview_render duplicates timing and telemetry logic that should
be extracted into a helper function for consistency. Refactor this function to
call the existing extracted helper that handles timing, telemetry execution, and
logging, passing the view_name and fun as arguments, to maintain uniformity and
reduce code duplication.

In lib/eve_dmv/telemetry/performance_monitor.ex around lines 14 to 33, the
timing and telemetry emission logic is duplicated across multiple functions.
Refactor by extracting this common timing pattern into a private helper function
that accepts the query name and a function to execute, performs the timing,
emits telemetry, logs slow queries, and returns the result. Then update the
existing functions to call this helper to reduce code duplication.

In lib/eve_dmv/telemetry/performance_monitor.ex lines 62 to 83, extract the
throughput calculation logic into a separate helper function to simplify
track_bulk_operation. Add error handling to safely manage division by zero or
any unexpected errors during throughput calculation. Refactor the main function
to call this helper and ensure logging and telemetry execution remain intact.

In test/support/httpoison_mock.ex at lines 1 to 4, improve the file by adding
more detailed documentation explaining the purpose and usage of the
HTTPoisonMock for SSE producer testing. Additionally, implement common mock
response helper functions within the module to facilitate reuse and simplify
test setups.

In .github/workflows/ci.yml around lines 110 to 123, remove any trailing spaces
at the end of lines within the coverage threshold check step to fix formatting
issues. Ensure all lines are trimmed of trailing whitespace to maintain clean
and consistent formatting.

In .github/workflows/coverage-comment.yml from lines 70 to 147, the shell script
has multiple best practice issues such as inefficient command substitutions,
repeated use of echo with redirection, and potential quoting problems. To fix
this, replace multiple echo statements appending to the same file with a single
block using a here-document for better readability and performance, ensure all
variables are properly quoted to prevent word splitting, simplify command
substitutions by avoiding unnecessary pipes or subshells, and use consistent
indentation and spacing to improve clarity and maintainability.

In test/support/mocks.ex around lines 81 to 117, the mock data generators use
hardcoded values for fields like corporation_id, corporation_name, alliance_id,
and alliance_name. To enhance test flexibility, refactor these functions to
accept optional parameters or configuration maps that allow overriding these
hardcoded values. This way, tests can customize the mock data as needed without
changing the function internals.

In .github/workflows/coverage-ratchet.yml around lines 164 to 184, remove any
variables that are declared but not used in the script to clean up the code.
Additionally, improve shell scripting practices by quoting variables properly to
prevent word splitting and globbing, and use consistent indentation and spacing
for readability. Review the script for any other shell best practice violations
such as unnecessary use of external commands or inefficient condition checks and
correct them accordingly.

In lib/eve_dmv/killmails/killmail_pipeline.ex around lines 700 to 717, the
check_surveillance_matches function currently only logs messages instead of
performing real surveillance matching. To fix this, replace the placeholder
logging with actual integration to the surveillance matching engine by calling
the appropriate matching functions using the extracted killmail_id and related
data. If the matching logic is not yet available, create a detailed issue to
track this implementation task for future completion.

In lib/eve_dmv/intelligence/member_activity_formatter.ex lines 29 to 75, the
current recommendation building logic uses repetitive if-else assignments to
accumulate recommendations, which reduces maintainability. Refactor this by
using a more functional approach such as Enum.reduce or Enum.concat to build the
recommendations list in a single pass, avoiding repeated reassignment and
improving code clarity.

In docs/test-coverage-implementation-prompt.md around lines 13 to 15 and 190 to
196, the test coverage targets are inconsistent and below the mandated 70%
minimum. Update the overall coverage target to 70% to align with Sprint 5
objectives and ExCoveralls setup, or clearly label the 25% and 40% figures as
interim milestones leading to the 70% goal. Ensure the document reflects a
unified and clear coverage target.

In lib/eve_dmv/eve/esi_request_client.ex around lines 201 to 204, the function
passed to FallbackStrategy.execute_with_stale_cache always returns an error
tuple, which prevents fallback to cached data. Modify this function to perform
the actual data fetch or operation that may fail, so that the fallback mechanism
can properly use the cached data when the primary fetch fails.

In test/eve_dmv/intelligence/wh_fleet_analyzer_test.exs around lines 88 to 95,
the wormhole type strings like "O477" are hardcoded. Refactor the code to define
these wormhole types as module attributes or constants at the top of the test
module, then replace the hardcoded strings with these attributes to improve
maintainability and reduce the risk of typos.

In lib/eve_dmv/eve/reliability_config.ex around lines 245 to 260, the code uses
Enum.reduce_while to validate timeout values but this can be simplified by using
Enum.find to locate the first invalid timeout. Replace the Enum.reduce_while
block with Enum.find that returns the first timeout entry failing the validation
checks, then handle the error accordingly. This will make the code more
idiomatic and concise for validation purposes.

In test/eve_dmv/intelligence/member_activity_analyzer_test.exs at line 330, the
float value is written as +0.0 which is unconventional. Replace +0.0 with the
standard float syntax 0.0 to adhere to conventional float representation.

In lib/eve_dmv/eve/fallback_strategy.ex around lines 294 to 301, the function
get_stale_cache_data/2 does not use the max_stale_age parameter to verify if the
cached data is still within the acceptable stale period. To fix this, modify the
function to retrieve both the cached data and its timestamp (using a method like
EsiCache.get_with_timestamp/1), then compare the current time with the timestamp
to determine if the data age is less than or equal to max_stale_age. Return
{:ok, data, :stale} only if the data is within this stale period; otherwise,
return :miss.

In lib/eve_dmv/intelligence/asset_analyzer.ex around lines 96 to 100, the
function fetch_corporation_assets only handles the error tuple from
EsiClient.get_corporation_assets but lacks a clause for the success case. Add a
pattern match for the success response, typically {:ok, result}, and return it
appropriately to handle both success and error outcomes.

In lib/eve_dmv/intelligence/asset_analyzer.ex at line 144, replace the call to
EsiClient.get_type/1 with EsiCache.get_type/1 to ensure type resolution uses the
cache module as per the codebase conventions.

In lib/eve_dmv/intelligence/asset_analyzer.ex around lines 29 to 38, the pattern
matching for fetching assets is incomplete: corp_assets only handles the error
tuple and member_assets only handles the ok tuple. Update both case expressions
to handle both {:ok, assets} and {:error, reason} tuples, returning the assets
on success and an empty list or appropriate fallback on error to ensure all
possible outcomes are covered.

In lib/eve_dmv/intelligence/home_defense_analyzer.ex around lines 175 to 182,
the case expression handling the result of EsiClient.get_characters/1 only
covers the success tuple {:ok, character_data} and lacks error handling for
failure cases. Add a clause to handle error tuples such as {:error, reason} to
properly manage and respond to failures when fetching character data, ensuring
the function does not crash or return incomplete data.

In lib/eve_dmv/intelligence/threat_analyzer.ex around lines 118 to 127, the SQL
query indentation is inconsistent, reducing readability. Adjust the indentation
so that all SELECT clause fields align vertically, JOIN conditions are indented
uniformly under the JOIN statement, and WHERE conditions are aligned
consistently, maintaining a clean and readable structure throughout the query.

In lib/eve_dmv/intelligence/member_activity_metrics.ex at line 202, the function
determine_activity_trend has an unused parameter character_id. Remove the
character_id parameter from the function definition since it is not used
anywhere in the function to clean up the code and avoid confusion.

In lib/eve_dmv/intelligence/member_activity_metrics.ex around lines 262 to 264,
replace the use of Enum.with_index with Enum.map since the index parameter is
not used. Change the function call to Enum.map(x_values, fn x -> y_mean + slope

- (x - x_mean) end) to simplify and clarify the code.

Fix test coverage report, as it currently shows bad data
Test coverage Report Shows null for all metrics
Overall Coverage: null% (null/null lines)

📈 Coverage Summary
Metric Value
Lines Covered null
Lines Relevant null
Total Lines null
Coverage % null%
🎯 Coverage Goals
Current: null%
Minimum Threshold: 4.0%
Sprint 5 Target: 70%
Status: ❌ Below minimum
$(cat coverage_details.md)

🔄 How to Improve Coverage
Add unit tests for modules with 0% coverage
Focus on business logic in intelligence and market modules
Test error paths and edge cases
Mock external dependencies (ESI, databases) in
