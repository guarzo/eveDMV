# Runtime logger configuration
# This file allows overriding logger configuration at runtime

import Config

# Allow disabling structured logging via environment variable
if System.get_env("DISABLE_STRUCTURED_LOGGING") == "true" do
  config :logger, :console,
    format: "$time $metadata[$level] $message\n",
    metadata: [:request_id, :user_id, :character_id]
end
