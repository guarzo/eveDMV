defmodule EveDmv.StaticData.ShipRoles do
  @moduledoc """
  Ship role classification based on EVE Online ship types.
  
  Provides functions to identify logistics, command, and electronic warfare ships
  using actual EVE ship type IDs from the static data export.
  """

  # T2 Logistics Cruisers
  @t2_logistics_cruisers [
    11985,  # Basilisk (Caldari)
    11987,  # Guardian (Amarr)
    11989,  # Oneiros (Gallente)
    11978   # Scimitar (Minmatar)
  ]

  # T1 Logistics Cruisers
  @t1_logistics_cruisers [
    2161,   # Osprey (Caldari)
    16509,  # Augoror (Amarr)
    634,    # Exequror (Gallente)
    3766    # Scythe (Minmatar)
  ]

  # T1 Logistics Frigates
  @t1_logistics_frigates [
    37457,  # Bantam (Caldari)
    37454,  # Inquisitor (Amarr)  
    37456,  # Navitas (Gallente)
    37453   # Burst (Minmatar)
  ]

  # Command Ships (Battlecruiser)
  @command_battlecruisers [
    22442,  # Eos (Gallente)
    22444,  # Astarte (Gallente)
    22446,  # Claymore (Minmatar)
    22448,  # Sleipnir (Minmatar)
    22466,  # Vulture (Caldari)
    22468,  # Nighthawk (Caldari)
    22470,  # Absolution (Amarr)
    22474   # Damnation (Amarr)
  ]

  # Command Destroyers
  @command_destroyers [
    37480,  # Bifrost (Minmatar)
    37481,  # Pontifex (Amarr)
    37482,  # Stork (Caldari)
    37483   # Magus (Gallente)
  ]

  # Command Frigates (Monitor)
  @command_frigates [
    45534   # Monitor (ORE)
  ]

  # T2 Force Recons
  @force_recons [
    11959,  # Rook (Caldari - ECM)
    11957,  # Falcon (Caldari - ECM)
    11969,  # Arazu (Gallente - Damps/Tackle)
    11971,  # Lachesis (Gallente - Damps/Tackle)
    11961,  # Huginn (Minmatar - Webs/Paint)
    11963,  # Rapier (Minmatar - Webs/Paint)
    11965,  # Pilgrim (Amarr - Neuts/TD)
    20125   # Curse (Amarr - Neuts/TD)
  ]

  # Electronic Attack Frigates
  @electronic_attack_frigates [
    11174,  # Keres (Gallente - Damps)
    11190,  # Sentinel (Amarr - Neuts/TD)
    11194,  # Kitsune (Caldari - ECM)
    11387   # Hyena (Minmatar - Webs/Paint)
  ]

  # T1 EWAR Cruisers
  @t1_ewar_cruisers [
    584,    # Blackbird (Caldari - ECM)
    20128,  # Celestis (Gallente - Damps)
    631,    # Bellicose (Minmatar - Paint)
    2006    # Arbitrator (Amarr - TD)
  ]

  # T1 EWAR Frigates
  @t1_ewar_frigates [
    583,    # Griffin (Caldari - ECM)
    599,    # Maulus (Gallente - Damps)
    585,    # Vigil (Minmatar - Paint)
    2161    # Crucifier (Amarr - TD)
  ]

  # Combat Recons (also EWAR but more combat-focused)
  @combat_recons [
    11961,  # Huginn
    11959,  # Rook
    11969,  # Arazu  
    20125   # Curse
  ]

  # All logistics ships
  @all_logistics MapSet.new(@t2_logistics_cruisers ++ @t1_logistics_cruisers ++ @t1_logistics_frigates)

  # All command ships
  @all_command MapSet.new(@command_battlecruisers ++ @command_destroyers ++ @command_frigates)

  # All EWAR ships
  @all_ewar MapSet.new(@force_recons ++ @electronic_attack_frigates ++ @t1_ewar_cruisers ++ 
                       @t1_ewar_frigates ++ @combat_recons)

  @doc """
  Check if a ship type ID is a logistics ship.
  
  ## Examples
  
      iex> ShipRoles.is_logistics_ship?(11985)
      true  # Basilisk
      
      iex> ShipRoles.is_logistics_ship?(587)
      false # Rifter
  """
  @spec is_logistics_ship?(integer()) :: boolean()
  def is_logistics_ship?(ship_type_id) when is_integer(ship_type_id) do
    MapSet.member?(@all_logistics, ship_type_id)
  end
  def is_logistics_ship?(_), do: false

  @doc """
  Check if a ship type ID is a command ship.
  
  ## Examples
  
      iex> ShipRoles.is_command_ship?(22442)
      true  # Eos
      
      iex> ShipRoles.is_command_ship?(587)
      false # Rifter
  """
  @spec is_command_ship?(integer()) :: boolean()
  def is_command_ship?(ship_type_id) when is_integer(ship_type_id) do
    MapSet.member?(@all_command, ship_type_id)
  end
  def is_command_ship?(_), do: false

  @doc """
  Check if a ship type ID is an electronic warfare ship.
  
  ## Examples
  
      iex> ShipRoles.is_ewar_ship?(11959)
      true  # Rook
      
      iex> ShipRoles.is_ewar_ship?(587)
      false # Rifter
  """
  @spec is_ewar_ship?(integer()) :: boolean()
  def is_ewar_ship?(ship_type_id) when is_integer(ship_type_id) do
    MapSet.member?(@all_ewar, ship_type_id)
  end
  def is_ewar_ship?(_), do: false

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
      is_logistics_ship?(ship_type_id) -> :logistics
      is_command_ship?(ship_type_id) -> :command
      is_ewar_ship?(ship_type_id) -> :ewar
      is_tackle_ship?(ship_type_id) -> :tackle
      true -> :dps  # Default to DPS role
    end
  end
  def get_ship_role(_), do: :unknown

  @doc """
  Check if a ship is a tackle ship (interceptors, interdictors).
  """
  @spec is_tackle_ship?(integer()) :: boolean()
  def is_tackle_ship?(ship_type_id) when is_integer(ship_type_id) do
    # Interceptors
    interceptor_ids = [
      11176, 11178, 11184, 11186,  # T2 Interceptors (Crow, Raptor, Ares, Malediction)
      11196, 11198, 11200, 11202   # T2 Interceptors (Stiletto, Claw, Taranis, Crusader)
    ]
    
    # Interdictors
    interdictor_ids = [
      22452, 22456, 22460, 22464  # Sabre, Flycatcher, Eris, Heretic
    ]
    
    # Heavy Interdictors
    heavy_interdictor_ids = [
      11995, 12013, 12017, 12021  # Onyx, Broadsword, Phobos, Devoter
    ]
    
    ship_type_id in (interceptor_ids ++ interdictor_ids ++ heavy_interdictor_ids)
  end
  def is_tackle_ship?(_), do: false

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
        |> Enum.filter(&(&1.flag >= 11 and &1.flag <= 34))  # High/mid/low slots
        |> Enum.map(& &1.item_type_id)
      _ -> 
        []
    end
  end

  defp has_remote_repair_modules?(module_ids) do
    # Remote armor/shield repairers
    remote_rep_ids = [
      4391, 4393, 4395, 4397,      # Small/Medium/Large Remote Armor Repairers
      8641, 8643, 8645, 8647,      # Small/Medium/Large Remote Shield Boosters
      41460, 41461, 41462, 41463   # Capital Remote Reps
    ]
    
    Enum.any?(module_ids, &(&1 in remote_rep_ids))
  end

  defp has_command_burst_modules?(module_ids) do
    # Command Burst modules (all variants)
    # IDs 43907-43918 are command bursts
    Enum.any?(module_ids, &(&1 >= 43907 and &1 <= 43918))
  end

  defp has_ewar_modules?(module_ids) do
    # ECM, damps, tracking disruptors, etc.
    ewar_module_ranges = [
      {1956, 1960},   # ECM modules
      {3643, 3650},   # Sensor dampeners
      {2605, 2610},   # Tracking disruptors
      {4025, 4030}    # Target painters
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
      447, 448, 449, 3244,         # Warp Disruptors
      2281, 2283, 2285, 5399,      # Warp Scramblers  
      4027, 4029, 4031, 14680      # Stasis Webifiers
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