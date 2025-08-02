defmodule EveDmv.StaticData.ShipRoles do
  @moduledoc """
  Ship role classification based on EVE Online ship types.

  Provides functions to identify logistics, command, and electronic warfare ships
  using actual EVE ship type IDs from the static data export.
  """
  """

  # T2 Logistics Cruisers
  @t2_logistics_cruisers [
    # Basilisk (Caldari)
    11_985,
    # Guardian (Amarr)
    11_987,
    # Oneiros (Gallente)
    11_989,
    # Scimitar (Minmatar)
    11_978
  ]

  # T1 Logistics Cruisers
  @t1_logistics_cruisers [
    # Osprey (Caldari)
    2161,
    # Augoror (Amarr)
    16_509,
    # Exequror (Gallente)
    634,
    # Scythe (Minmatar)
    3766
  ]

  # T1 Logistics Frigates
  @t1_logistics_frigates [
    # Bantam (Caldari)
    37_457,
    # Inquisitor (Amarr)
    37_454,
    # Navitas (Gallente)
    37_456,
    # Burst (Minmatar)
    37_453
  ]

  # Command Ships (Battlecruiser)
  @command_battlecruisers [
    # Eos (Gallente)
    22_442,
    # Astarte (Gallente)
    22_444,
    # Claymore (Minmatar)
    22_446,
    # Sleipnir (Minmatar)
    22_448,
    # Vulture (Caldari)
    22_466,
    # Nighthawk (Caldari)
    22_468,
    # Absolution (Amarr)
    22_470,
    # Damnation (Amarr)
    22_474
  ]

  # Command Destroyers
  @command_destroyers [
    # Bifrost (Minmatar)
    37_480,
    # Pontifex (Amarr)
    37_481,
    # Stork (Caldari)
    37_482,
    # Magus (Gallente)
    37_483
  ]

  # Command Frigates (Monitor)
  @command_frigates [
    # Monitor (ORE)
    45_534
  ]

  # T2 Force Recons
  @force_recons [
    # Rook (Caldari - ECM)
    11_959,
    # Falcon (Caldari - ECM)
    11_957,
    # Arazu (Gallente - Damps/Tackle)
    11_969,
    # Lachesis (Gallente - Damps/Tackle)
    11_971,
    # Huginn (Minmatar - Webs/Paint)
    11_961,
    # Rapier (Minmatar - Webs/Paint)
    11_963,
    # Pilgrim (Amarr - Neuts/TD)
    11_965,
    # Curse (Amarr - Neuts/TD)
    20_125
  ]

  # Electronic Attack Frigates
  @electronic_attack_frigates [
    # Keres (Gallente - Damps)
    11_174,
    # Sentinel (Amarr - Neuts/TD)
    11_190,
    # Kitsune (Caldari - ECM)
    11_194,
    # Hyena (Minmatar - Webs/Paint)
    11_387
  ]

  # T1 EWAR Cruisers
  @t1_ewar_cruisers [
    # Blackbird (Caldari - ECM)
    584,
    # Celestis (Gallente - Damps)
    20_128,
    # Bellicose (Minmatar - Paint)
    631,
    # Arbitrator (Amarr - TD)
    2006
  ]

  # T1 EWAR Frigates
  @t1_ewar_frigates [
    # Griffin (Caldari - ECM)
    583,
    # Maulus (Gallente - Damps)
    599,
    # Vigil (Minmatar - Paint)
    585,
    # Crucifier (Amarr - TD)
    2161
  ]

  # Combat Recons (also EWAR but more combat-focused)
  @combat_recons [
    # Huginn
    11_961,
    # Rook
    11_959,
    # Arazu
    11_969,
    # Curse
    20_125
  ]

  # All logistics ships
  @all_logistics MapSet.new(
                   @t2_logistics_cruisers ++ @t1_logistics_cruisers ++ @t1_logistics_frigates
                 )

  # All command ships
  @all_command MapSet.new(@command_battlecruisers ++ @command_destroyers ++ @command_frigates)

  # All EWAR ships
  @all_ewar MapSet.new(
              @force_recons ++
                @electronic_attack_frigates ++
                @t1_ewar_cruisers ++
                @t1_ewar_frigates ++ @combat_recons
            )

  @doc """
  Check if a ship type ID is a logistics ship.

  ## Examples

      iex> ShipRoles.logistics_ship?(11985)
      true  # Basilisk

      iex> ShipRoles.logistics_ship?(587)
      false # Rifter
  """
  @spec logistics_ship?(integer()) :: boolean()
  def logistics_ship?(ship_type_id) when is_integer(ship_type_id) do
    MapSet.member?(@all_logistics, ship_type_id)
  end

  def logistics_ship?(_), do: false

  @doc """
  Check if a ship type ID is a command ship.

  ## Examples

      iex> ShipRoles.command_ship?(22442)
      true  # Eos

      iex> ShipRoles.command_ship?(587)
      false # Rifter
  """
  @spec command_ship?(integer()) :: boolean()
  def command_ship?(ship_type_id) when is_integer(ship_type_id) do
    MapSet.member?(@all_command, ship_type_id)
  end

  def command_ship?(_), do: false

  @doc """
  Check if a ship type ID is an electronic warfare ship.

  ## Examples

      iex> ShipRoles.ewar_ship?(11_959)
      true  # Rook

      iex> ShipRoles.ewar_ship?(587)
      false # Rifter
  """
  @spec ewar_ship?(integer()) :: boolean()
  def ewar_ship?(ship_type_id) when is_integer(ship_type_id) do
    MapSet.member?(@all_ewar, ship_type_id)
  end

  def ewar_ship?(_), do: false

  @doc """
  Get the primary role of a ship based on its type ID.

  Returns one of: :logistics, :command, :ewar, :tackle, :dps, :unknown

  ## Examples

      iex> ShipRoles.get_ship_role(11985)
      :logistics  # Basilisk

      iex> ShipRoles.get_ship_role(22442)
      :command    # Eos
  """
  @spec get_ship_role(integer()) :: atom()
  def get_ship_role(ship_type_id) when is_integer(ship_type_id) do
    cond do
      logistics_ship?(ship_type_id) -> :logistics
      command_ship?(ship_type_id) -> :command
      ewar_ship?(ship_type_id) -> :ewar
      tackle_ship?(ship_type_id) -> :tackle
      # Default to DPS role
      true -> :dps
    end
  end

  def get_ship_role(_), do: :unknown

  @doc """
  Check if a ship is a tackle ship (interceptors, interdictors).
  """
  @spec tackle_ship?(integer()) :: boolean()
  def tackle_ship?(ship_type_id) when is_integer(ship_type_id) do
    # Interceptors
    interceptor_ids = [
      # T2 Interceptors (Crow, Raptor, Ares, Malediction)
      11_176,
      11_178,
      11_184,
      11_186,
      # T2 Interceptors (Stiletto, Claw, Taranis, Crusader)
      11_196,
      11_198,
      11_200,
      11_202
    ]

    # Interdictors
    interdictor_ids = [
      # Sabre, Flycatcher, Eris, Heretic
      22_452,
      22_456,
      22_460,
      22_464
    ]

    # Heavy Interdictors
    heavy_interdictor_ids = [
      # Onyx, Broadsword, Phobos, Devoter
      11_995,
      12_013,
      12_017,
      12_021
    ]

    ship_type_id in (interceptor_ids ++ interdictor_ids ++ heavy_interdictor_ids)
  end

  def tackle_ship?(_), do: false

  @doc """
  Detect role from fitted modules in a killmail.

  Analyzes the modules fitted to determine the actual role the ship was performing,
  which may differ from its hull classification.
  """
  @spec detect_role_from_modules(map()) :: atom()
  def detect_role_from_modules(killmail) do
    modules = get_fitted_modules(killmail)

    cond do
      has_remote_repair_modules?(modules) -> :logistics
      has_command_burst_modules?(modules) -> :command
      has_ewar_modules?(modules) -> :ewar
      has_tackle_modules?(modules) -> :tackle
      true -> :dps
    end
  end

  # Module detection helpers
  defp get_fitted_modules(killmail) do
    case killmail do
      %{victim: %{items: items}} when is_list(items) ->
        items
        # High/mid/low slots
        |> Enum.filter(&(&1.flag >= 11 and &1.flag <= 34))
        |> Enum.map(& &1.item_type_id)

      _ ->
        []
    end
  end

  defp has_remote_repair_modules?(module_ids) do
    # Remote armor/shield repairers
    remote_rep_ids = [
      # Small/Medium/Large Remote Armor Repairers
      4391,
      4393,
      4395,
      4397,
      # Small/Medium/Large Remote Shield Boosters
      8641,
      8643,
      8645,
      8647,
      # Capital Remote Reps
      41_460,
      41_461,
      41_462,
      41_463
    ]

    Enum.any?(module_ids, &(&1 in remote_rep_ids))
  end

  defp has_command_burst_modules?(module_ids) do
    # Command Burst modules (all variants)
    # IDs 43907-43918 are command bursts
    Enum.any?(module_ids, &(&1 >= 43_907 and &1 <= 43_918))
  end

  defp has_ewar_modules?(module_ids) do
    # ECM, damps, tracking disruptors, etc.
    ewar_module_ranges = [
      # ECM modules
      {1956, 1960},
      # Sensor dampeners
      {3643, 3650},
      # Tracking disruptors
      {2605, 2610},
      # Target painters
      {4025, 4030}
    ]

    Enum.any?(module_ids, fn id ->
      Enum.any?(ewar_module_ranges, fn {min, max} ->
        id >= min and id <= max
      end)
    end)
  end

  defp has_tackle_modules?(module_ids) do
    # Warp disruptors, scramblers, webs
    tackle_module_ids = [
      # Warp Disruptors
      447,
      448,
      449,
      3244,
      # Warp Scramblers
      2281,
      2283,
      2285,
      5399,
      # Stasis Webifiers
      4027,
      4029,
      4031,
      14_680
    ]

    Enum.any?(module_ids, &(&1 in tackle_module_ids))
  end

  @doc """
  Get all ship type IDs for a given role.

  Useful for queries and analysis.
  """
  @spec get_ship_ids_for_role(atom()) :: [integer()]
  def get_ship_ids_for_role(:logistics), do: MapSet.to_list(@all_logistics)
  def get_ship_ids_for_role(:command), do: MapSet.to_list(@all_command)
  def get_ship_ids_for_role(:ewar), do: MapSet.to_list(@all_ewar)
  def get_ship_ids_for_role(_), do: []
end
