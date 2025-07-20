In lib/eve_dmv/analytics/battle_detector.ex around lines 22-23 and also at lines
99-100, 178-179, 266-267, 335-336, 430-431, and 471-472, the expression
DateTime.add(DateTime.utc_now(), -30, :day) is repeated multiple times. To DRY
this up, create a private function or module attribute that returns this value,
such as a private function thirty_days_ago/0 that returns
DateTime.add(DateTime.utc_now(), -30, :day), and replace all occurrences with
calls to this helper. This centralizes the logic and removes duplication.

In lib/eve_dmv/api/analytics_api.ex around lines 12 to 16, currently only
ShipStats and PlayerStats resources are registered. Review if there are
additional analytics resources like FleetStats that should be included here. If
so, add resource declarations for each missing analytics resource to this list
to prevent NoSuchResource errors when they are called.

In lib/eve_dmv/ash/preparations/query_safety.ex lines 1 to 18, the moduledoc
mentions a :timeout option with a max of 120,000ms, but the prepare/3 function
does not implement any timeout handling. To fix this, either add logic in
prepare/3 to apply the timeout option to the query or remove the :timeout option
from the documentation to keep it accurate and consistent.

In lib/eve_dmv/ash/preparations/query_safety.ex around lines 29 to 36, the
current function applies a limit with a maximum cap but does not implement the
timeout functionality referenced in the documentation. To fix this, add logic to
extract a timeout value from opts, apply a default if missing, and integrate
this timeout setting into the query or query execution process as appropriate to
enforce query execution time limits alongside the record limit.

In lib/eve_dmv/static_data.ex around the relevant lines, the functions
get_ship_class/1 and get_ship_category/1 are missing, causing runtime failures
when called from module_classifier.ex. Add these two functions to
EveDmv.StaticData, either by defining them directly or delegating to existing
logic that returns the ship class and category based on the ship_type_id
argument, ensuring they match the expected signatures and behavior used in
module_classifier.ex.

In lib/eve_dmv/api.ex around lines 40 to 50, the function
default_read_preparations/0 is defined but not integrated into the use
Ash.Domain call, so the default query limits are not applied. To fix this,
update the use Ash.Domain invocation to include the option
default_read_preparations: &default_read_preparations/0, ensuring the query
safety limits are enforced by default.

In lib/eve_dmv/ash/query_safety_config.ex around lines 14 to 39, replace the
current string-based matching on the last segment of the module name with direct
pattern matching on the module itself. Define function clauses for
safety_config_for/1 that match on the specific resource modules instead of
extracting and comparing strings. This change improves robustness by leveraging
compile-time checks and avoids silent failures if modules are renamed or
reorganized.

In lib/eve_dmv/ash/query_safety_config.ex around lines 53 to 65, the
apply_safety function assumes query.resource and query.action.name always exist,
risking runtime errors if they are missing. Add checks to verify that query has
a resource and an action with a name before accessing them. If these are
missing, return the query unchanged to avoid errors and ensure safe handling of
unexpected input structures.

In lib/eve_dmv/auth.ex at line 75, the EVE SSO URL is hard-coded as a string. To
make this configurable, move the URL to the application configuration files
(e.g., config.exs) and update the code to read the URL from the configuration
using Application.get_env or a similar method. This allows different
environments to specify their own URL without changing the code.

In lib/eve_dmv/auth.ex around lines 55 to 57, the token refresh buffer time is
hardcoded to 5 minutes. To fix this, replace the hardcoded 5-minute value with a
configurable parameter, such as reading the buffer duration from application
configuration or environment variables. Update the code to use this configurable
value when calculating the buffer_time for token expiration checks.

In lib/eve_dmv/auth.ex between lines 16 and 44, simplify the token refresh logic
by removing the fallback to the old refresh token since EVE SSO should always
provide a new one. Add a validation step before updating the user to ensure
token_data.refresh_token is not nil, and handle the case where it might be
missing by returning an appropriate error instead of proceeding with the update.

In lib/eve_dmv/auth.ex around lines 64 to 69, the get_current_user function
accepts any binary as user_id without validating its format. Add input
validation to ensure user_id is a properly formatted UUID or valid identifier
before calling Ash.get. If the validation fails, return an appropriate error
tuple like {:error, :invalid_user_id} to prevent invalid queries.

In lib/eve_dmv/ash/preparations/apply_query_safety.ex lines 9 to 24, the current
approach overrides the read macro entirely, which risks conflicts with other
code or libraries using the same macro. Instead of overriding, refactor to apply
query safety explicitly where needed by calling the preparation function
directly in the relevant code blocks. Remove the macro override and update usage
sites to include the query safety preparation explicitly to avoid unintended
side effects.

In lib/eve_dmv/ash/preparations/apply_query_safety.ex around lines 59 to 69, the
for_actions/2 function returns an anonymous function instead of a tuple like
other functions, causing inconsistency, and lacks validation for the
action_names input. To fix this, refactor for_actions/2 to return a tuple
consistent with other functions, add validation to ensure action_names is a list
of valid action names, and update the QuerySafety.prepare call to use the
:only_actions option for filtering actions instead of the current inline check.

In lib/eve_dmv/api/domain_extensions.ex around lines 15 to 19, the function
apply_query_safety_to_domain is currently a no-op placeholder returning :ok,
which violates clean codebase guidelines. You should either implement the
intended compile-time hook functionality for query safety or, if this feature is
not immediately required, remove the function entirely to avoid having unused
placeholder code.

In lib/eve_dmv/api/domain_extensions.ex around lines 39 to 45, the **using**
macro currently ignores the \_opts parameter and does not accept any
configuration options. Modify the macro to accept and handle options passed in
\_opts, allowing resources to customize behavior such as passing a limit option.
Update the macro to extract and use these options within the quote block,
enabling flexible configuration when the macro is used.
