defmodule Surveillance do
  @moduledoc "Temporary stub for surveillance operations - TODO: implement"

  alias EveDmv.Contexts.Surveillance.Api

  defdelegate delete_profile(id), to: Api
  defdelegate update_profile(id, updates), to: Api
  defdelegate create_profile(profile_data), to: Api
  defdelegate list_profiles(opts), to: Api
end
