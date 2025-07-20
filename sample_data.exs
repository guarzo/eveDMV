alias EveDmv.Repo

IO.puts("\n=== SAMPLE EVE ITEM TYPES ===")
{:ok, items} = Ecto.Adapters.SQL.query(
  Repo, 
  "SELECT type_id, type_name, group_name, category_name FROM eve_item_types WHERE type_name LIKE $1 LIMIT 5", 
  ["%Raven%"]
)
Enum.each(items.rows, fn [id, name, group, cat] -> 
  IO.puts("  #{id}: #{name} (#{group}/#{cat})") 
end)

IO.puts("\n=== SAMPLE SOLAR SYSTEMS ===")
{:ok, systems} = Ecto.Adapters.SQL.query(
  Repo, 
  "SELECT system_id, system_name, region_name, security_status FROM eve_solar_systems WHERE system_name LIKE $1 LIMIT 5", 
  ["%Jita%"]
)
Enum.each(systems.rows, fn [id, name, region, sec] -> 
  IO.puts("  #{id}: #{name} in #{region} (sec: #{sec})") 
end)

IO.puts("\n=== WORMHOLE SYSTEMS ===")
{:ok, wh_systems} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT system_id, system_name, wormhole_class_id, wormhole_effect_type FROM eve_solar_systems WHERE wormhole_class_id IS NOT NULL LIMIT 5",
  []
)
Enum.each(wh_systems.rows, fn [id, name, class, effect] ->
  IO.puts("  #{id}: #{name} - Class #{class || "?"}, Effect: #{effect || "None"}")
end)