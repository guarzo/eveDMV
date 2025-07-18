defmodule EveDmv.StaticData.SystemData do
  @moduledoc """
  Centralized system data and classification service.

  Provides consistent system classification and data across the application.
  This module should be enhanced with actual EVE static data when available.
  """

  alias EveDmv.Repo
  import Ecto.Query
  require Logger

  # System ID ranges for different space types (currently unused but kept for future expansion)
  # These are approximations based on EVE's system ID patterns
  # @system_id_ranges %{
  #   # High-sec systems (Empire space)
  #   highsec: [
  #     # The Forge, Domain, etc.
  #     {30_000_000, 30_004_999},
  #     # More Empire regions
  #     {30_005_000, 30_009_999}
  #   ],
  #   # Low-sec systems
  #   lowsec: [
  #     # Low-sec regions
  #     {30_010_000, 30_014_999},
  #     # More low-sec
  #     {30_015_000, 30_019_999}
  #   ],
  #   # Null-sec systems
  #   nullsec: [
  #     # Null-sec regions
  #     {30_020_000, 30_029_999},
  #     # More null-sec
  #     {30_030_000, 30_039_999},
  #     # Even more null-sec
  #     {30_040_000, 30_049_999}
  #   ],
  #   # Wormhole systems (J-space)
  #   wormhole: [
  #     # All wormhole systems
  #     {31_000_000, 31_999_999}
  #   ],
  #   # Abyssal systems
  #   abyssal: [
  #     # Abyssal deadspace
  #     {32_000_000, 32_999_999}
  #   ],
  #   # Pochven systems
  #   pochven: [
  #     # Pochven (overlaps - needs specific IDs)
  #     {30_000_000, 30_999_999}
  #   ]
  # }

  # Major trade hub system IDs
  @trade_hubs %{
    30_000_142 => "Jita",
    30_002_187 => "Amarr",
    30_002_659 => "Dodixie",
    30_002_510 => "Rens",
    30_002_053 => "Hek",
    30_001_594 => "Perimeter",
    30_000_144 => "Sobaseki"
  }

  # Region estimation divisor
  @region_divisor 1000

  @doc """
  Get security status for a system from the database.
  Falls back to estimation if not found.
  """
  def get_security_status(system_id) when is_integer(system_id) do
    # Try to get from database first
    query =
      from(s in "eve_solar_systems",
        where: s.solar_system_id == ^system_id,
        select: s.security_status
      )

    case Repo.one(query) do
      nil -> estimate_security_status(system_id)
      security_status -> security_status
    end
  rescue
    _ -> estimate_security_status(system_id)
  end

  def get_security_status(_), do: 0.5

  @doc """
  Classify a system by its security type.
  """
  def classify_security_type(system_id) when is_integer(system_id) do
    security_status = get_security_status(system_id)

    cond do
      system_id >= 31_000_000 and system_id < 32_000_000 -> :wormhole
      system_id >= 32_000_000 and system_id < 33_000_000 -> :abyssal
      security_status >= 0.5 -> :highsec
      security_status > 0.0 -> :lowsec
      security_status <= 0.0 -> :nullsec
      true -> :unknown
    end
  end

  def classify_security_type(_), do: :unknown

  @doc """
  Estimate which region a system belongs to.
  """
  def estimate_region(system_id) when is_integer(system_id) do
    # Try database first
    query =
      from(s in "eve_solar_systems",
        where: s.solar_system_id == ^system_id,
        select: s.region_id
      )

    case Repo.one(query) do
      nil ->
        # Fallback to estimation
        # This is a very rough approximation
        div(system_id, @region_divisor)

      region_id ->
        region_id
    end
  rescue
    _ -> div(system_id, @region_divisor)
  end

  def estimate_region(_), do: 0

  @doc """
  Check if a system is a trade hub.
  """
  def is_trade_hub?(system_id) do
    Map.has_key?(@trade_hubs, system_id)
  end

  @doc """
  Get the name of a trade hub.
  """
  def get_trade_hub_name(system_id) do
    Map.get(@trade_hubs, system_id)
  end

  @doc """
  Calculate region diversity for a list of systems.
  """
  def calculate_region_diversity(system_ids) when is_list(system_ids) do
    if Enum.empty?(system_ids) do
      0.0
    else
      unique_regions =
        system_ids
        |> Enum.map(&estimate_region/1)
        |> Enum.uniq()
        |> length()

      # Normalize to 0-1 scale (assume max ~50 accessible regions)
      min(1.0, unique_regions / 50.0)
    end
  end

  def calculate_region_diversity(_), do: 0.0

  @doc """
  Calculate security space diversity for a list of systems.
  """
  def calculate_security_diversity(system_ids) when is_list(system_ids) do
    if Enum.empty?(system_ids) do
      0.0
    else
      unique_types =
        system_ids
        |> Enum.map(&classify_security_type/1)
        |> Enum.uniq()
        |> length()

      # Normalize to 0-1 scale (6 security types total)
      unique_types / 6.0
    end
  end

  def calculate_security_diversity(_), do: 0.0

  # Private functions

  defp estimate_security_status(system_id) do
    # Rough estimation based on system ID patterns
    cond do
      # Wormhole
      system_id >= 31_000_000 and system_id < 32_000_000 -> -1.0
      # Abyssal
      system_id >= 32_000_000 and system_id < 33_000_000 -> -1.0
      # High-sec estimate
      system_id >= 30_000_000 and system_id < 30_005_000 -> 0.7
      # High-sec estimate
      system_id >= 30_005_000 and system_id < 30_010_000 -> 0.5
      # Low-sec estimate
      system_id >= 30_010_000 and system_id < 30_020_000 -> 0.3
      # Null-sec estimate
      system_id >= 30_020_000 and system_id < 30_050_000 -> -0.5
      true -> 0.0
    end
  end

  @doc """
  Get system name from database or return placeholder.
  """
  def get_system_name(system_id) when is_integer(system_id) do
    query =
      from(s in "eve_solar_systems",
        where: s.solar_system_id == ^system_id,
        select: s.solar_system_name
      )

    case Repo.one(query) do
      nil -> "System #{system_id}"
      name -> name
    end
  rescue
    _ -> "System #{system_id}"
  end

  def get_system_name(_), do: "Unknown System"
end
