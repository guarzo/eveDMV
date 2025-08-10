defmodule EveDmv.Cache do
  @moduledoc """
  Compatibility module that delegates to the reorganized cache module.
  This module exists to maintain backward compatibility after Phase 5 reorganization.
  """

  # Delegate to the actual cache module
  alias EveDmv.Platform.Cache.Cache, as: PlatformCache
  defdelegate get(namespace, key), to: PlatformCache
  defdelegate put(namespace, key, value), to: PlatformCache
  defdelegate put(namespace, key, value, opts), to: PlatformCache
  defdelegate delete(namespace, key), to: PlatformCache
  defdelegate clear(namespace), to: PlatformCache
  defdelegate invalidate_pattern(namespace, pattern), to: PlatformCache
  defdelegate stats(namespace), to: PlatformCache
  defdelegate get_or_compute(namespace, key, ttl, compute_fn), to: PlatformCache
  defdelegate put_character(character_id, data), to: PlatformCache

  # Additional delegated functions for compatibility
  defdelegate get_many(namespace, keys), to: PlatformCache
  defdelegate put_many(namespace, entries), to: PlatformCache
  defdelegate put_many(namespace, entries, opts), to: PlatformCache
  defdelegate get_or_compute(namespace, key, compute_fn), to: EveDmv.Platform.Cache.Cache

  # ESI-specific cache functions
  defdelegate get_esi_response(type, id), to: EveDmv.Platform.Cache.Cache
  defdelegate put_esi_response(type, id, data), to: EveDmv.Platform.Cache.Cache

  # Price data cache functions
  defdelegate get_price_data(type_id), to: EveDmv.Platform.Cache.Cache
  defdelegate put_price_data(type_id, data), to: EveDmv.Platform.Cache.Cache
end
