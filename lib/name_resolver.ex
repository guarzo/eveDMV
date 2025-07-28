defmodule NameResolver do
  @moduledoc "Temporary stub for name resolution - TODO: implement"

  alias EveDmv.Eve.NameResolver.StaticDataResolver
  alias EveDmv.Eve.NameResolver.EsiEntityResolver

  def system_name(system_id) do
    StaticDataResolver.system_name(system_id)
  end

  def character_name(character_id) do
    EsiEntityResolver.character_name(character_id)
  end
end
