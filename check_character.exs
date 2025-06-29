alias EveDmv.Api
alias EveDmv.Killmails.Participant
require Ash.Query

character_id = 2115778369

# Check if we have any participants for this character
query = Participant |> Ash.Query.new() |> Ash.Query.filter(character_id == ^character_id)
participants = Ash.read!(query, domain: Api)

IO.puts("Found #{length(participants)} participant records for character #{character_id}")

# Try to find any participants at all
all_query = Participant |> Ash.Query.new() |> Ash.Query.limit(10)
all_participants = Ash.read!(all_query, domain: Api)

IO.puts("\nSample participants in database:")
Enum.each(all_participants, fn p ->
  IO.puts("Character: #{p.character_name} (ID: #{p.character_id})")
end)

# Check specific characters from recent killmails
recent_characters = [2117298187, 92338468, 2119113381]
IO.puts("\nChecking recent characters:")
Enum.each(recent_characters, fn char_id ->
  q = Participant |> Ash.Query.new() |> Ash.Query.filter(character_id == ^char_id) |> Ash.Query.limit(1)
  case Ash.read(q, domain: Api) do
    {:ok, [p | _]} -> IO.puts("✓ Found #{p.character_name} (ID: #{char_id})")
    {:ok, []} -> IO.puts("✗ No data for character ID: #{char_id}")
    {:error, _} -> IO.puts("✗ Error checking character ID: #{char_id}")
  end
end)