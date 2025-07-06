defmodule EveDmv.Eve.NameResolver do
  @moduledoc """
  Helper module for resolving EVE Online IDs to friendly names.

  This module provides efficient caching and lookup functions for converting
  type IDs and system IDs to human-readable names in the UI.

  The module has been refactored into specialized sub-modules:
  - CacheManager: Cache operations and TTL management
  - StaticDataResolver: Ship, item, and solar system resolution
  - EsiEntityResolver: Character, corporation, and alliance resolution
  - BatchProcessor: Efficient batch processing and parallel operations
  - PerformanceOptimizer: Cache warming and performance optimization
  """

  # Extracted modules
  alias EveDmv.Eve.NameResolver.{
    CacheManager,
    StaticDataResolver,
    EsiEntityResolver,
    BatchProcessor,
    PerformanceOptimizer
  }

  # ============================================================================
  # Public API - Cache Management
  # ============================================================================

  @doc """
  Starts the name resolver cache.
  Called during application startup.
  """
  defdelegate start_cache(), to: CacheManager

  @doc """
  Clears all cached names. Useful for development/testing.
  """
  defdelegate clear_cache(), to: CacheManager

  # ============================================================================
  # Public API - Static Data Resolution
  # ============================================================================

  @doc """
  Resolves a ship type ID to a ship name.

  ## Examples

      iex> NameResolver.ship_name(587)
      "Rifter"

      iex> NameResolver.ship_name(999999)
      "Unknown Ship (999999)"
  """
  defdelegate ship_name(type_id), to: StaticDataResolver

  @doc """
  Resolves an item type ID to an item name.
  Works for ships, modules, charges, etc.

  ## Examples

      iex> NameResolver.item_name(12058)
      "Medium Shield Extender II"

      iex> NameResolver.item_name(999999)
      "Unknown Item (999999)"
  """
  defdelegate item_name(type_id), to: StaticDataResolver

  @doc """
  Resolves a solar system ID to a system name.

  ## Examples

      iex> NameResolver.system_name(30000142)
      "Jita"

      iex> NameResolver.system_name(999999)
      "Unknown System (999999)"
  """
  defdelegate system_name(system_id), to: StaticDataResolver

  @doc """
  Resolves multiple ship type IDs to names efficiently.

  ## Examples

      iex> NameResolver.ship_names([587, 588, 589])
      %{587 => "Rifter", 588 => "Punisher", 589 => "Tormentor"}
  """
  defdelegate ship_names(type_ids), to: StaticDataResolver

  @doc """
  Resolves multiple item type IDs to names efficiently.
  """
  defdelegate item_names(type_ids), to: StaticDataResolver

  @doc """
  Resolves multiple solar system IDs to names efficiently.
  """
  defdelegate system_names(system_ids), to: StaticDataResolver

  @doc """
  Gets the security class and color for a solar system.

  ## Examples

      iex> NameResolver.system_security(30000142)
      %{class: "highsec", color: "text-green-400", status: 0.946}
  """
  defdelegate system_security(system_id), to: StaticDataResolver

  # ============================================================================
  # Public API - ESI Entity Resolution
  # ============================================================================

  @doc """
  Resolves a character ID to a character name using ESI.

  ## Examples

      iex> NameResolver.character_name(95465499)
      "CCP Falcon"

      iex> NameResolver.character_name(999999999)
      "Unknown Character (999999999)"
  """
  defdelegate character_name(character_id), to: EsiEntityResolver

  @doc """
  Resolves a corporation ID to a corporation name using ESI.

  ## Examples

      iex> NameResolver.corporation_name(98388312)
      "CCP Games"

      iex> NameResolver.corporation_name(999999999)
      "Unknown Corporation (999999999)"
  """
  defdelegate corporation_name(corporation_id), to: EsiEntityResolver

  @doc """
  Resolves an alliance ID to an alliance name using ESI.

  ## Examples

      iex> NameResolver.alliance_name(99005338)
      "Pandemic Horde"

      iex> NameResolver.alliance_name(999999999)
      "Unknown Alliance (999999999)"
  """
  defdelegate alliance_name(alliance_id), to: EsiEntityResolver

  @doc """
  Resolves multiple character IDs to names efficiently.
  Uses ESI bulk lookup when possible.
  """
  defdelegate character_names(character_ids), to: EsiEntityResolver

  @doc """
  Resolves multiple corporation IDs to names efficiently.
  Uses ESI bulk lookup when possible.
  """
  defdelegate corporation_names(corporation_ids), to: EsiEntityResolver

  @doc """
  Resolves multiple alliance IDs to names efficiently.
  """
  defdelegate alliance_names(alliance_ids), to: EsiEntityResolver

  # ============================================================================
  # Public API - Performance Optimization
  # ============================================================================

  @doc """
  Preloads names for killmail participants to improve UI performance.

  Takes a list of killmails and preloads all character, corporation,
  and alliance names found in the participants.
  """
  defdelegate preload_killmail_names(killmails), to: PerformanceOptimizer

  @doc """
  Warms the cache with commonly used items.
  Should be called after static data is loaded.
  """
  defdelegate warm_cache(), to: PerformanceOptimizer

  @doc """
  Preloads fleet participant names for improved fleet UI performance.
  """
  defdelegate preload_fleet_names(fleet_members), to: PerformanceOptimizer

  @doc """
  Preloads ship and item names commonly used in loadouts.
  """
  defdelegate preload_fitting_names(fittings), to: PerformanceOptimizer

  @doc """
  Preloads names for market data display.
  """
  defdelegate preload_market_names(market_orders), to: PerformanceOptimizer

  @doc """
  Performs intelligent cache warming based on usage patterns.
  """
  defdelegate intelligent_cache_warming(usage_stats \\ %{}), to: PerformanceOptimizer

  @doc """
  Optimizes cache warming for specific game activities.
  """
  defdelegate warm_cache_for_activity(activity_type), to: PerformanceOptimizer

  @doc """
  Monitors cache performance and suggests optimizations.
  """
  defdelegate analyze_cache_performance(), to: PerformanceOptimizer

  # ============================================================================
  # Public API - Batch Processing
  # ============================================================================

  @doc """
  Efficiently resolves multiple IDs of the same type.
  """
  defdelegate batch_resolve(type, ids, fallback_fn), to: BatchProcessor

  @doc """
  Batch resolves ESI entities with bulk lookup optimization.
  """
  defdelegate batch_resolve_with_esi(type, ids, fallback_fn), to: BatchProcessor

  @doc """
  Validates batch request parameters and limits.
  """
  defdelegate validate_batch_request(ids), to: BatchProcessor

  # ============================================================================
  # Backward Compatibility - Direct Cache Access
  # ============================================================================

  @doc """
  Gets a value from cache or fetches it using the provided fetch function.
  Direct access to cache management functionality.
  """
  defdelegate get_cached_or_fetch(type, id, fetch_fn), to: CacheManager

  @doc """
  Gets a value from cache without fetching if missing.
  Direct access to cache functionality.
  """
  defdelegate get_from_cache(type, id), to: CacheManager

  @doc """
  Caches batch results with appropriate TTL.
  Direct access to cache management.
  """
  defdelegate cache_batch_results(type, results), to: CacheManager

  @doc """
  Gets the appropriate TTL for a given data type.
  """
  defdelegate get_ttl_for_type(type), to: CacheManager
end
