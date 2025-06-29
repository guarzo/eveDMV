In lib/eve_dmv/eve/solar_system.ex at line 193, the similarity threshold of 0.3
is hardcoded in the filter expression. To fix this, introduce a configurable
parameter for the similarity threshold, either by passing it as a function
argument with a default value or by reading it from a configuration file or
environment variable. Replace the hardcoded 0.3 with this configurable value and
ensure the code documents or validates the threshold usage.

In lib/eve_dmv/market/mutamarket_client.ex at line 353, the variable `_error` is
used but incorrectly prefixed with an underscore, which suggests it is unused.
Remove the underscore prefix from `_error` to correctly indicate that the
variable is used.

In lib/eve_dmv_web/live/surveillance_live.html.heex at line 92, the conditional
rendering syntax used inside the curly braces is invalid for HEEx templates.
Replace the inline if expression with proper HEEx tags by using <%= if condition
do %> ... <% else %> ... <% end %> or use a ternary operator inside the
interpolation to correctly render "profile" or "profiles" based on the length of
@profiles.

In lib/eve_dmv_web/live/surveillance_live.ex around lines 20 to 21, replace the
dummy UUID fallback for user_id with proper session-based authentication using
the existing EVE SSO integration. Retrieve the authenticated user's ID from the
session or authentication context instead of defaulting to a fixed dummy value,
ensuring secure and accurate user identification before deployment.

In lib/eve_dmv/enrichment/re_enrichment_worker.ex around lines 100 to 101 and
line 107, the code spawns processes directly without supervision, risking silent
failures. Replace the spawn calls with Task.Supervisor.async_nolink or
Task.Supervisor.start_child using an appropriate Task.Supervisor module to
ensure the spawned processes are supervised. This change will allow the system
to monitor and handle failures properly.

In lib/eve_dmv/surveillance/profile_match.ex at line 107, there is a TODO
comment about adding a relationship to killmail once foreign keys are improved.
To address this, either create a proper issue in the project tracker to ensure
this TODO is not forgotten or, if ready, implement the killmail relationship now
by defining the appropriate foreign key and association in the schema. Confirm
which approach to take and proceed accordingly.
