# EVE DMV Testing Helper Script
# Run with: iex -S mix phx.server
# Then copy/paste these functions to set up test scenarios

defmodule TestingHelpers do
  alias EveDmv.Api
  alias EveDmv.Surveillance.{Profile, NotificationService}
  alias EveDmv.Users.User
  
  @doc """
  Get recent killmail IDs for testing character intel
  """
  def get_test_killmail_ids(limit \\ 10) do
    case Ash.read(EveDmv.Killmails.KillmailRaw, 
           action: :read, 
           domain: Api,
           query: [sort: [killmail_time: :desc], limit: limit]) do
      {:ok, killmails} -> 
        Enum.map(killmails, & &1.killmail_id)
      _ -> 
        []
    end
  end

  @doc """
  Get character IDs from recent killmails for testing
  """
  def get_test_character_ids(limit \\ 20) do
    case Ash.read(EveDmv.Killmails.Participant, 
           action: :read, 
           domain: Api,
           query: [sort: [killmail_time: :desc], limit: limit]) do
      {:ok, participants} -> 
        participants
        |> Enum.map(& &1.character_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.take(10)
      _ -> 
        []
    end
  end

  @doc """
  Get corporation IDs from recent activity
  """
  def get_test_corporation_ids(limit \\ 10) do
    case Ash.read(EveDmv.Killmails.Participant, 
           action: :read, 
           domain: Api,
           query: [sort: [killmail_time: :desc], limit: 50]) do
      {:ok, participants} -> 
        participants
        |> Enum.map(& &1.corporation_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.take(limit)
      _ -> 
        []
    end
  end

  @doc """
  Create a test surveillance profile for manual testing
  """
  def create_test_surveillance_profile(user_id, name \\ "Test Profile") do
    profile_data = %{
      name: name,
      description: "Test surveillance profile for manual testing",
      user_id: user_id,
      filter_tree: %{
        "condition" => "and",
        "rules" => [
          %{
            "field" => "total_value",
            "operator" => "gt", 
            "value" => 50_000_000  # 50M ISK
          },
          %{
            "field" => "solar_system_id",
            "operator" => "in",
            "value" => [30000142, 30002187]  # Jita, Amarr
          }
        ]
      },
      is_active: true
    }

    case Ash.create(Profile, profile_data, domain: Api) do
      {:ok, profile} -> 
        IO.puts("✅ Created test profile: #{profile.name} (ID: #{profile.id})")
        profile
      {:error, error} -> 
        IO.puts("❌ Failed to create profile: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Get surveillance engine statistics
  """
  def get_surveillance_stats do
    try do
      stats = EveDmv.Surveillance.MatchingEngine.get_stats()
      IO.puts("📊 Surveillance Engine Stats:")
      IO.puts("  Profiles loaded: #{stats.profiles_loaded}")
      IO.puts("  Matches processed: #{stats.matches_processed}")
      IO.puts("  Cache size: #{stats.cache_stats.size}")
      IO.puts("  ETS tables:")
      Enum.each(stats.ets_tables, fn {table, size} ->
        IO.puts("    #{table}: #{size} entries")
      end)
      stats
    rescue
      _ -> 
        IO.puts("❌ Surveillance engine not running")
        nil
    end
  end

  @doc """
  Create test notifications for manual testing
  """
  def create_test_notifications(user_id, count \\ 3) do
    notifications = for i <- 1..count do
      NotificationService.create_system_notification(
        user_id,
        "Test Notification #{i}",
        "This is test notification number #{i} for manual testing",
        %{test_data: "notification_#{i}"},
        case rem(i, 3) do
          0 -> :urgent
          1 -> :high
          _ -> :normal
        end
      )
    end
    
    IO.puts("✅ Created #{count} test notifications")
    notifications
  end

  @doc """
  Show recent killmail processing activity
  """
  def show_recent_activity(minutes \\ 5) do
    cutoff = DateTime.add(DateTime.utc_now(), -minutes * 60, :second)
    
    case Ash.read(EveDmv.Killmails.KillmailRaw, 
           action: :read,
           domain: Api,
           query: [
             filter: [killmail_time: [gte: cutoff]],
             sort: [killmail_time: :desc],
             limit: 20
           ]) do
      {:ok, killmails} ->
        IO.puts("🎯 Recent killmail activity (last #{minutes} minutes):")
        Enum.each(killmails, fn km ->
          age = DateTime.diff(DateTime.utc_now(), km.killmail_time, :minute)
          IO.puts("  #{km.killmail_id} - #{age}m ago")
        end)
        length(killmails)
      _ ->
        IO.puts("❌ Could not fetch recent activity")
        0
    end
  end

  @doc """
  Test URLs for manual testing
  """
  def print_test_urls do
    character_ids = get_test_character_ids() |> Enum.take(3)
    corp_ids = get_test_corporation_ids() |> Enum.take(3)
    
    IO.puts("🔗 Test URLs for Manual Testing:")
    IO.puts("")
    IO.puts("Base URLs:")
    IO.puts("  Home: http://localhost:4010/")
    IO.puts("  Kill Feed: http://localhost:4010/feed")
    IO.puts("  Surveillance: http://localhost:4010/surveillance")
    IO.puts("")
    
    IO.puts("Character Intel URLs:")
    Enum.each(character_ids, fn char_id ->
      IO.puts("  http://localhost:4010/intel/#{char_id}")
    end)
    IO.puts("")
    
    IO.puts("Player Profile URLs:")
    Enum.each(character_ids, fn char_id ->
      IO.puts("  http://localhost:4010/player/#{char_id}")
    end)
    IO.puts("")
    
    IO.puts("Corporation URLs:")
    Enum.each(corp_ids, fn corp_id ->
      IO.puts("  http://localhost:4010/corp/#{corp_id}")
    end)
    IO.puts("")
  end

  @doc """
  Full test setup - run this to prepare for manual testing
  """
  def setup_manual_testing do
    IO.puts("🚀 Setting up EVE DMV for Manual Testing...")
    IO.puts("")
    
    # Show recent activity
    activity_count = show_recent_activity(10)
    IO.puts("")
    
    # Show surveillance stats
    get_surveillance_stats()
    IO.puts("")
    
    # Print test URLs
    print_test_urls()
    
    IO.puts("✅ Manual testing setup complete!")
    IO.puts("")
    IO.puts("📋 Next steps:")
    IO.puts("1. Open MANUAL_TESTING_SCRIPT.md")
    IO.puts("2. Follow the test cases systematically")
    IO.puts("3. Use the URLs printed above for testing")
    if activity_count > 0 do
      IO.puts("4. Recent killmail data available for testing")
    else
      IO.puts("4. ⚠️  No recent killmail data - check pipeline status")
    end
    IO.puts("")
  end
end

# Auto-run setup when script is loaded
IO.puts("Loading EVE DMV Testing Helpers...")
IO.puts("Run: TestingHelpers.setup_manual_testing() to get started")
IO.puts("")