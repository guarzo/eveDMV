In lib/eve_dmv_web/live/player_profile_live.html.heex around lines 19 to 26, the
conditional rendering of the "Generate Stats" button is nested inside an if
statement. Refactor this by moving the condition into a helper function in the
LiveView module that returns the button HTML when @player_stats is nil and
returns an empty string otherwise. Then replace the inline if block in the
template with a call to this helper function to simplify and reduce nesting in
the template.

In lib/eve_dmv_web/live/player_profile_live.html.heex from lines 1 to 384, the
template is very large and handles multiple UI states in one file, making it
hard to maintain. Refactor by extracting the main sections into separate
function components: create player_stats_section/1 for lines 43-277,
character_info_section/1 for lines 280-321, and no_data_section/1 for lines
324-380. Then replace the large conditional blocks in the main template with
calls to these components, passing the relevant assigns. This modularization
will simplify the template and improve readability.

In lib/eve_dmv_web/live/player_profile_live.html.heex at line 302, the current
code uses Float.round(@character_info.security_status || 0.0, 2), which may fail
if security_status is not a valid number. To fix this, create a helper function
that safely handles nil and non-number values by returning "0.00" in those cases
and rounding only valid numbers. Then replace the inline Float.round call with
this helper function to ensure nil safety and avoid runtime errors.

In lib/eve_dmv_web/live/player_profile_live.html.heex around lines 207 to 211,
the inline conditional formatting for average gang size should be extracted into
a helper function for clarity and consistency. Create a private helper function
named format_avg_gang_size that returns "1.0" if the input is nil and otherwise
calls format_number with the size. Replace the inline conditional in the
template with a call to this new helper function.

In lib/eve_dmv_web/live/player_profile_live.html.heex around lines 149 to 154,
the inline Decimal calculation for net ISK in the template adds unnecessary
complexity. Move this calculation to the LiveView module by creating helper
functions: one to compute and format net ISK, and another to determine the CSS
class based on its positivity. Replace the inline calculation and class logic in
the template with calls to these helper functions to simplify the template code.

In lib/eve_dmv_web/live/player_profile_live.html.heex at line 310, the current
age calculation risks errors if @character_info.birthday is nil or invalid. To
fix this, create a helper function that checks if birthday is nil and safely
computes the age by dividing days by 365 only when days is non-negative,
returning "Unknown" otherwise. Replace the inline calculation with a call to
this helper to ensure nil safety and avoid division errors.

In lib/eve_dmv/killmails/killmail_pipeline.ex between lines 514 and 605, the
code switches from bulk inserts to individual inserts for better error
visibility and participant error handling, which may reduce performance under
high load. To address this, monitor the insert performance in production and if
performance degrades, refactor the insert functions to use batched inserts that
still capture and log individual errors, balancing error detail with throughput.

In lib/eve*dmv/eve/esi_client.ex lines 722 to 732, the function
parse_market_history uses Date.from_iso8601! which raises an exception on
invalid date strings. Replace Date.from_iso8601! with Date.from_iso8601 to
safely parse the date and handle the {:ok, date} or {:error, *} tuple
accordingly, returning nil or a default value on error. Then, in the caller
function, filter out any nil values resulting from failed parses to avoid
runtime errors.

In lib/eve_dmv/eve/esi_client.ex around lines 354 to 445, the get_type,
get_group, and get_category functions lack caching, causing unnecessary repeated
API calls for rarely changing universe data. To fix this, extend the EsiCache
module to add caching support for universe data with a dedicated cache table and
a TTL of one week. Then modify these functions to first attempt fetching data
from the cache and only call the API if the cache miss occurs, storing the fresh
data back into the cache afterward, similar to how get_character uses caching.

In lib/eve_dmv_web/live/corporation_live.ex lines 105 to 142, the function loads
all participants into memory and filters them there, which is inefficient.
Refactor the function to query the database directly for participants matching
the given corporation_id, aggregating kills, losses, and latest activity within
the query if possible. This will reduce memory usage and improve performance by
only retrieving relevant data.

In lib/eve_dmv_web/live/corporation_live.ex lines 71 to 103, the current
implementation loads all participants from the database and filters them in
memory, which is inefficient. Modify the Ash.read call to include a filter that
directly queries participants with the matching corporation_id, reducing
database load and improving performance. Use Ash query filters to perform this
filtering at the database level instead of in Elixir code.

In lib/eve_dmv_web/live/corporation_live.ex lines 144 to 166, the function
load_recent_activity loads all participants before filtering by corporation_id,
causing performance issues, and incorrectly uses damage_dealt to detect kills.
Fix this by modifying the Ash.read query to filter participants by
corporation_id directly in the query to avoid loading unnecessary data, and
change the kill detection logic to use a proper indicator such as checking if
the participant is the victim or if the kill flag is set, instead of
damage_dealt.

In priv/repo/migrations/20250629131722_add_surveillance_notifications.exs around
lines 34 to 40, the migration currently includes check constraints for
enumerated values but lacks explicit foreign key constraints. To ensure
referential integrity, identify the relevant columns that should reference other
tables and add foreign key constraints using the create constraint or add
constraint functions. This will enforce valid references and improve data
consistency.

In MANUAL_TESTING_SCRIPT.md lines 34 to 101, there are multiple critical runtime
errors: fix the infinite recursion in topbar.js by reviewing and correcting the
loop and progress function calls to prevent stack overflow; ensure the killmail
data includes the victim_character_id key or add safe access checks to avoid
KeyError; add the missing participants association to the KillmailEnriched
schema to resolve schema errors; and verify all Float.round calls handle integer
inputs correctly by adding type checks or converting integers to floats before
rounding.

In lib/eve_dmv_web/live/dashboard_live.ex around lines 174 to 180, the character
intelligence link uses a hardcoded ID "1234567". Replace this hardcoded ID with
a dynamic variable representing the character ID, or remove the ID if a dynamic
value is not available, to ensure the link works correctly in different contexts
or demos.

In assets/vendor/topbar.js at line 139, replace the variable declaration from
'var' to 'const' for the newProgress variable to improve scoping and adhere to
modern JavaScript best practices.

In lib/eve_dmv_web/controllers/page_html/home.html.heex at line 220, verify that
the grid layout with classes grid-cols-1 md:grid-cols-2 lg:grid-cols-4 maintains
good responsiveness across all screen sizes. Test the layout on mobile, tablet,
and desktop views to ensure the columns adjust smoothly without breaking the
design. If issues are found, adjust the Tailwind CSS grid column classes or add
breakpoints to improve the responsive behavior.

In lib/eve_dmv_web/live/kill_feed_live.ex around lines 373 to 376, the
safe_decimal_new function calls Decimal.new/1 on binary input without handling
invalid decimal strings, which can raise exceptions. Modify the binary clause to
catch errors from Decimal.new/1 by using a try-rescue block or pattern matching
to return a default Decimal value (e.g., Decimal.new(0)) when the input is
invalid, ensuring the function does not raise exceptions on bad binary input.

In lib/eve_dmv/intelligence/character_analyzer.ex between lines 59 and 91,
remove the EveDmv.Repo.transaction wrapper around the Task.async_stream call and
subsequent processing. The analyze_character_with_timeout function already
handles its own database operations, so the transaction wrapper is unnecessary
and may cause contention. Simply execute the async_stream and reduce logic
directly without wrapping it in a transaction.

In lib/eve_dmv/intelligence/character_analyzer.ex around lines 389 to 393, the
gang size calculation currently includes the victim in the participant count,
inflating the gang size by one. To fix this, subtract 1 from the length of
participants for each killmail to exclude the victim and get the actual attacker
count.

In lib/eve_dmv/intelligence/character_analyzer.ex around lines 538 to 540, the
fallback categorization for ships defaults to "small" which incorrectly labels
ships like Orca, Bowhead, or new types. Change the fallback to a more
appropriate category such as "unknown" or a neutral placeholder instead of
"small" to avoid misclassification of unrecognized ship types.

In lib/eve_dmv/eve/esi_client.ex around lines 405 to 408, the current handling
of HTTP 304 Not Modified responses returns an empty map, which causes downstream
parsing functions to fail due to missing expected fields. To fix this, modify
the code to treat 304 responses as an error condition or implement proper ETag
cache support so that cached data can be returned when a 304 is received. This
ensures the function either returns valid cached data or an explicit error
instead of an incomplete empty map.

In lib/eve_dmv/eve/static_data_loader.ex around lines 626 to 646, the current
code creates item types individually, which is inefficient for large datasets.
Refactor this function to use Ash bulk operations or Ecto's insert_all to
perform bulk inserts, improving performance. Apply the same bulk operation
approach to the similar code block in lines 648 to 672.

In lib/eve_dmv_web/live/character_intel_live.ex around lines 17 to 33, the call
to String.to_integer/1 on the character_id parameter can raise an exception if
the input is not a valid integer string. To fix this, replace
String.to_integer/1 with a safe parsing method like Integer.parse/1, then handle
the case where parsing fails by assigning an error state to the socket and
avoiding further processing. This will prevent the LiveView from crashing on
invalid input and allow graceful error handling.

In lib/eve_dmv/market/strategies/mutamarket_strategy.ex around lines 82 to 87,
the abyssal filaments type ID range is hardcoded. Refactor this by defining
these ranges as module attributes or loading them from configuration, then
replace the hardcoded values with references to these attributes or config
values to improve maintainability and flexibility.

In lib/eve_dmv/market/strategies/esi_strategy.ex around lines 30 to 31, the
region ID for The Forge (Jita) is hardcoded as 10_000_002. To add flexibility,
refactor the code to accept the region ID as a configurable parameter, such as
passing it as an argument to the function or reading it from a configuration
file or environment variable, while keeping 10_000_002 as the default value if
no configuration is provided.

In docs/implementation/character-intelligence-hunter-focused.md from lines 1 to
143, fix markdown formatting by adding blank lines before and after all
headings, specifying language identifiers like "text" for fenced code blocks,
ensuring blank lines surround lists and code fences, and adding a final newline
at the end of the file to improve readability and markdown compliance.

In lib/mix/tasks/eve.analyze_performance.ex at line 42, replace the condition
checking if analysis.slow_queries is not an empty list by using
Enum.any?(analysis.slow_queries) instead. This change makes the code more
idiomatic and clearer by directly checking if the list contains any elements.

In lib/eve_dmv_web/live/surveillance_live.html.heex at line 92, the conditional
rendering syntax used inside the curly braces is invalid for HEEx templates.
Replace the inline if expression with proper HEEx tags by using <%= if condition
do %> ... <% else %> ... <% end %> or use a ternary operator inside the
interpolation to correctly render "profile" or "profiles" based on the length of
@profiles.

In priv/repo/migrations/20250629121149_add_analytics_tables.exs at line 44 and
line 110, add check constraints for enumerated string fields such as
preferred_gang_size, popularity_trend, meta_tier, and role_classification.
Define the allowed set of string values for each field and add a database check
constraint to enforce that only these values can be inserted or updated,
ensuring data integrity.

In SPRINT_2_BUG_FIXES_SUMMARY.md around lines 118 to 119, improve readability by
adding missing articles in the listed steps. Change "Implement comprehensive
test suite for all LiveViews" to "Implement a comprehensive test suite for all
LiveViews" and "Add Dialyzer to CI pipeline" to "Add the Dialyzer to the CI
pipeline" to correct grammar and enhance clarity.

In lib/eve_dmv_web/helpers/price_helper.ex around lines 64 to 70, the list of
excluded ship type IDs is hardcoded, reducing maintainability. Refactor the code
to fetch these excluded ship type IDs from the application configuration instead
of hardcoding them. Update the function to read the exclusion list from config
and use that list in the ship_type_id exclusion check.

In lib/eve_dmv_web/helpers/price_helper.ex around lines 72 to 87, replace the
use of Task.start/1 with a supervised task using Task.Supervisor.async_nolink or
Task.Supervisor.start_child under a TaskSupervisor like EveDmv.TaskSupervisor.
This involves adding EveDmv.TaskSupervisor to your application's supervision
tree and then invoking the async task through this supervisor to ensure better
fault tolerance and avoid resource leaks from unsupervised processes.

In lib/eve_dmv/analytics/analytics_engine.ex around lines 238 to 241 and also
lines 291 to 292, replace the hardcoded 50,000,000 ISK multipliers with
calculations that sum the actual ISK values from participant data. Modify both
the current function and the build_ship_metrics function to aggregate ISK values
dynamically from the relevant participant fields to improve analytics accuracy.

In lib/eve_dmv/analytics/analytics_engine.ex around lines 74 to 87, the
participants_ids function currently returns an empty list on error, which can
mask issues. Modify the function to return a tagged tuple {:error, reason}
instead of an empty list when Ash.read fails. Then update all calling functions
to handle this error tuple appropriately, ensuring errors are propagated and
handled rather than silently ignored.

In lib/eve_dmv/analytics/analytics_engine.ex at line 185, add a defensive check
to ensure the list 'ps' is not empty before calling
List.first(ps).character_name. Modify the code to first verify that
List.first(ps) returns a non-nil value, and only then access character_name;
otherwise, default to "Unknown" to prevent potential crashes from an empty list.

In lib/eve_dmv/analytics/analytics_engine.ex around lines 161 to 181, the
current code fetches all Participant records and filters them in memory, which
is inefficient. Modify the Ash.read calls to include query filters that restrict
results by character_id or ship_type_id at the database level, so only relevant
participants are fetched. This will optimize performance by reducing data
transfer and processing.

In SPRINT.md from lines 1 to 146, the markdown formatting lacks necessary blank
lines after headings and around lists, which reduces readability. Add a blank
line after each heading on lines 10, 18, 32, 38, 44, 52, 60, 68-69, 74, 99, 105,
112, 121, and 131. Also, insert blank lines before and after lists on lines 11,
19, 33, 39, 45, 53, 61, 70, 75, 100, 106, 113, 122, 132, and 141. Finally,
ensure there is a trailing newline at the end of the file on line 146.

In lib/eve_dmv_web/live/corporation_live.html.heex at line 62, the href uses
@corp_info.corporation_id with the /intel/ route, which expects a character_id
and will cause an error. To fix this, either remove the link if corporation
intel is not supported, create a new route that accepts corporation_id for
corporation intel, or update the link to point to an existing
corporation-specific page if available.

In lib/eve_dmv/eve/type_resolver.ex around lines 133 to 167, add a comment
before the if-statement that explains the function returns partial success by
providing all successfully fetched item types even if some fetches fail. This
clarifies the intended behavior of handling partial failures gracefully.

In lib/eve_dmv/eve/type_resolver.ex around lines 54 to 61, the code assumes
fetch_and_create_item_types always returns {:ok, new_types}, but it can return
partial results with failures. Update the code to handle both success and error
tuples from fetch_and_create_item_types, merging successful results with
existing_types and properly handling or logging failures instead of assuming
complete success.

In lib/eve_dmv/eve/type_resolver.ex around lines 80 to 89, the current
get_existing_types function performs individual database queries for each
type_id, causing N queries. Refactor this function to perform a single bulk
query that fetches all ItemType records matching the list of type_ids at once,
then return the results. This reduces database calls and improves performance.

In config/runtime.exs around lines 128 to 129, replace the direct call to
String.to_integer with ConfigHelper.safe_string_to_integer/2 to safely parse the
port environment variable. This prevents exceptions from invalid input by
providing a default value and aligns with the safe parsing approach used
elsewhere in the file.

In PROJECT_STATUS.md from lines 1 to 176, fix markdown formatting by adding
blank lines before and after all headings on lines 9, 16, 53, 67, 73, 86, 90,
118, 123, 132, 139, 146, and 151, and also add blank lines before and after all
lists on lines 10, 17, 54, 68, 74, 88, 92, 97, 102, 107, 112, 119, 124, 133,
140, and 147. Convert all bare URLs on lines 147 to 149 into proper markdown
links with descriptive text. Finally, ensure the file ends with exactly one
newline character on line 176.

In lib/eve_dmv/killmails/historical_killmail_fetcher.ex from lines 281 to 369,
the build_raw_changeset, build_enriched_changeset, and build_participants
functions duplicate logic already present in the pipeline, violating DRY
principles. To fix this, extract these functions and any related helpers into a
new shared module, e.g., EveDmv.Killmails.KillmailProcessor, and move the
implementations there. Then update both the historical fetcher and pipeline to
call these shared functions instead of duplicating the code.

In lib/eve_dmv/killmails/historical_killmail_fetcher.ex lines 373 to 405, the
bare rescue blocks in insert_raw_killmail, insert_enriched_killmail, and
insert_participants catch all exceptions, potentially hiding real errors. Update
these rescue clauses to catch only the specific exceptions related to duplicates
(such as unique constraint errors or specific database exceptions) instead of
rescuing all errors. This will ensure that only expected duplicate errors are
ignored while other errors are properly raised and handled.

In lib/eve_dmv/market/rate_limiter.ex around lines 160 to 184, the request
timeout is hardcoded to 5000ms when checking if a queued request has timed out.
To fix this, modify the queue to store each request's specific timeout value
along with from, tokens, and enqueued_at. Update the timeout check to use the
stored timeout per request instead of the fixed 5000ms. Also, adjust the queue
insertion in handle_call({:acquire, tokens}, from, state) to include the
caller's timeout value when enqueuing requests, ensuring the timeout is passed
through the call handler.

In lib/eve_dmv_web/live/character_intel_live.ex between lines 273 and 312, the
function handle_unknown_character uses Task.start to run a background task,
which lacks error handling and supervision. Replace Task.start with
Task.Supervisor.start_child using the appropriate Task.Supervisor module defined
in the application to ensure the task is supervised and errors are properly
logged and handled. Adjust the call to pass the anonymous function as the child
task to start_child, maintaining the existing logic inside the task.

In lib/eve_dmv/analytics/player_stats.ex around lines 146 to 188 and also 220 to
259, the calculation logic for kill_death_ratio, isk_efficiency_percent, and
solo_performance_ratio is duplicated in both create and update actions. Extract
this repeated calculation logic into a private function named
calculate_performance_metrics that takes a changeset, performs all the metric
calculations, updates the changeset attributes accordingly, and returns the
updated changeset. Then replace the inline calculation code in both actions with
a call to change(&calculate_performance_metrics/2) to reuse the logic and avoid
duplication.

In lib/eve_dmv/analytics/player_stats.ex around lines 175 to 180 and similarly
at lines 247 to 252, the solo performance ratio calculation uses max(1,
solo_losses), which inaccurately inflates the ratio when solo_losses is zero. To
fix this, explicitly check if solo_losses is zero; if so and solo_kills is
greater than zero, return a representation of a perfect record (such as
Decimal.new(:infinity) or a defined max value). Otherwise, perform the division
normally. This adjustment will provide a more meaningful and accurate solo
performance ratio.

In lib/eve_dmv/analytics/ship_stats.ex between lines 178 and 317, the
performance metric calculations are duplicated in both the create and update
actions. Extract all the shared calculation logic into a private function, for
example calculate_performance_metrics/1, which takes the changeset, performs all
metric calculations, and returns the updated changeset with the calculated
attributes set. Then replace the duplicated change blocks in both actions with a
call to this new function inside the change callback.

In lib/eve_dmv/analytics/ship_stats.ex around lines 300 to 307, the code uses
the :solo_kills attribute in the update action to calculate
solo_kill_percentage, but this attribute is not defined in the schema. To fix
this, add the :solo_kills attribute to the schema definition with the
appropriate type, ensuring it is included in the changeset so it can be accessed
during updates.

In lib/eve_dmv/market/price_service.ex around lines 35 to 49, simplify the
nested case statements by combining the price extraction and nil check into a
single case or conditional expression. Also, enhance the error message to
include the type_id value for better debugging context when no price is
available.

In lib/eve_dmv/eve/solar_system.ex around lines 260 to 265, the policy currently
allows any authenticated user to create, update, or destroy solar system data by
using authorize_if(actor_present()). To restrict these destructive actions to
admin users only, replace authorize_if(actor_present()) with
authorize_if(actor_attribute_equals(:role, "admin")). For better clarity,
optionally define a private helper function actor_is_admin that returns
actor_attribute_equals(:role, "admin") and then use
authorize_if(actor_is_admin()) in the policy.

In ESI_INTEGRATION_SUMMARY.md from lines 1 to 183, fix markdown formatting by
adding blank lines before and after all lists and headings to improve
readability, add appropriate language identifiers (e.g., bash, elixir) to all
code blocks for syntax highlighting, and ensure the file ends with a final
newline character. This will make the document easier to read and properly
formatted in markdown viewers.

In lib/eve_dmv_web/live/player_profile_live.ex around lines 209 to 252, the
asynchronous task fetching ESI data lacks explicit timeout handling, which can
cause indefinite waits. Refactor the code to use Task.async to start the task
and Task.await with a specified timeout to wait for its result. Then implement
handle_info callbacks to handle the task's completion or failure by matching on
the task reference, demonitoring it, and updating the socket state accordingly
to handle success, normal completion, or failure scenarios.

In lib/eve_dmv/intelligence/character_analyzer.ex around lines 269 to 279, the
calculation of gang_sizes includes the victim in the participant count, which
inflates the average gang size. Adjust the length calculation by subtracting one
from the count of participants to exclude the victim before computing the
average. Ensure that the subtraction does not produce negative values by
filtering or handling cases where participant count is zero or one.

In lib/eve_dmv_web/live/surveillance_live.ex around lines 310 to 317, the
current code updates notifications in bulk without handling errors for each
update, which can cause the UI to incorrectly show all as read even if some
updates fail. Modify the Enum.each to capture the result of each Ash.update
call, check for success or failure, and handle errors appropriately, such as
logging failures or collecting failed notifications to inform the UI.

In lib/eve_dmv_web/live/corporation_live.ex around lines 116 to 119, the current
logic uses damage_dealt to distinguish kills and losses, which is incorrect
because participants with zero damage can still be attackers. Update the kill
count to be the number of participants where is_victim is false, and the loss
count to be the number where is_victim is true, using the is_victim flag to
correctly identify victims and attackers.
