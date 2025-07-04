# EVE DMV Manual Testing Data Generator
# Enhanced version for comprehensive manual testing support
#
# Usage:
#   1. Start Phoenix with interactive shell: iex -S mix phx.server
#   2. Load this file: Code.compile_file("manual_testing_data_generator.exs")
#   3. Run: ManualTestingDataGenerator.setup_complete_testing_environment()

defmodule ManualTestingDataGenerator do
  require Ash.Query
  alias EveDmv.Api
  alias EveDmv.Intelligence.CharacterMetrics
  alias EveDmv.Killmails.{KillmailRaw, Participant}
  alias EveDmv.Surveillance.NotificationService
  alias EveDmv.Surveillance.Profile
  alias EveDmv.Users.User

  @doc """
  Complete setup for manual testing - creates all necessary test data
  """
  def setup_complete_testing_environment do
    IO.puts("🚀 Setting up EVE DMV Complete Testing Environment...")
    IO.puts("=" |> String.duplicate(60))

    # Check system status
    check_system_status()

    # Generate test data
    generate_test_data()

    # Print all test URLs and instructions
    print_complete_test_guide()

    IO.puts("✅ Complete testing environment ready!")
    IO.puts("📋 Open MANUAL_TESTING_PLAN.md and follow the test suites")
  end

  @doc """
  Check system status and requirements
  """
  def check_system_status do
    IO.puts("\n🔍 System Status Check:")

    # Check database connectivity
    case Ash.read(KillmailRaw, action: :read, domain: Api, query: [limit: 1]) do
      {:ok, _} -> IO.puts("  ✅ Database connection working")
      {:error, _} -> IO.puts("  ❌ Database connection failed")
    end

    # Check recent killmail activity
    recent_count = count_recent_killmails(10)

    if recent_count > 0 do
      IO.puts("  ✅ Pipeline active: #{recent_count} killmails in last 10 minutes")
    else
      IO.puts("  ⚠️  No recent killmails - pipeline may be inactive")
    end

    # Check surveillance engine
    case check_surveillance_engine() do
      {:ok, stats} ->
        IO.puts("  ✅ Surveillance engine running: #{stats.profiles_loaded} profiles loaded")

      {:error, _} ->
        IO.puts("  ⚠️  Surveillance engine not responding")
    end
  end

  @doc """
  Generate comprehensive test data
  """
  def generate_test_data do
    IO.puts("\n📊 Generating Test Data:")

    # Get fresh test IDs from database
    test_data = %{
      character_ids: get_diverse_character_ids(15),
      corporation_ids: get_diverse_corporation_ids(10),
      alliance_ids: get_diverse_alliance_ids(5),
      recent_killmail_ids: get_recent_killmail_ids(20)
    }

    IO.puts("  ✅ Collected #{length(test_data.character_ids)} character IDs")
    IO.puts("  ✅ Collected #{length(test_data.corporation_ids)} corporation IDs")
    IO.puts("  ✅ Collected #{length(test_data.alliance_ids)} alliance IDs")
    IO.puts("  ✅ Collected #{length(test_data.recent_killmail_ids)} recent killmail IDs")

    # Create sample surveillance profiles (for authenticated users)
    create_sample_surveillance_profiles()

    # Store test data for later use
    :ets.new(:manual_testing_data, [:set, :public, :named_table])
    :ets.insert(:manual_testing_data, {:test_data, test_data})

    test_data
  end

  @doc """
  Get diverse character IDs with different activity levels
  """
  def get_diverse_character_ids(limit) do
    query = [
      sort: [killmail_time: :desc],
      # Get more to ensure diversity
      limit: limit * 3
    ]

    case Ash.read(Participant, action: :read, domain: Api, query: query) do
      {:ok, participants} ->
        participants
        |> Enum.map(& &1.character_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.take(limit)

      _ ->
        []
    end
  end

  @doc """
  Get diverse corporation IDs
  """
  def get_diverse_corporation_ids(limit) do
    query = [
      sort: [killmail_time: :desc],
      limit: limit * 5
    ]

    case Ash.read(Participant, action: :read, domain: Api, query: query) do
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
  Get diverse alliance IDs
  """
  def get_diverse_alliance_ids(limit) do
    query = [
      sort: [killmail_time: :desc],
      limit: limit * 10
    ]

    case Ash.read(Participant, action: :read, domain: Api, query: query) do
      {:ok, participants} ->
        participants
        |> Enum.map(& &1.alliance_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.take(limit)

      _ ->
        []
    end
  end

  @doc """
  Get recent killmail IDs for testing
  """
  def get_recent_killmail_ids(limit) do
    query = [
      sort: [killmail_time: :desc],
      limit: limit
    ]

    case Ash.read(KillmailRaw, action: :read, domain: Api, query: query) do
      {:ok, killmails} ->
        Enum.map(killmails, & &1.killmail_id)

      _ ->
        []
    end
  end

  @doc """
  Count recent killmails for activity check
  """
  def count_recent_killmails(minutes) do
    cutoff = DateTime.add(DateTime.utc_now(), -minutes * 60, :second)

    case KillmailRaw
         |> Ash.Query.filter(killmail_time >= ^cutoff)
         |> Ash.Query.limit(1000)
         |> Ash.read(domain: Api) do
      {:ok, killmails} -> length(killmails)
      _ -> 0
    end
  end

  @doc """
  Check surveillance engine status
  """
  def check_surveillance_engine do
    stats = EveDmv.Surveillance.MatchingEngine.get_stats()
    {:ok, stats}
  rescue
    _ -> {:error, :not_running}
  end

  @doc """
  Create sample surveillance profiles for testing
  """
  def create_sample_surveillance_profiles do
    IO.puts("  📋 Creating sample surveillance profiles...")

    # Note: These will only work when a user is authenticated
    # The manual testing plan will include instructions for this

    sample_profiles = [
      %{
        name: "High Value Targets",
        description: "Tracks killmails with total value > 100M ISK",
        filter_tree: %{
          "condition" => "and",
          "rules" => [
            %{
              "field" => "total_value",
              "operator" => "gt",
              "value" => 100_000_000
            }
          ]
        }
      },
      %{
        name: "Jita Activity Monitor",
        description: "Monitors all activity in Jita system",
        filter_tree: %{
          "condition" => "and",
          "rules" => [
            %{
              "field" => "solar_system_id",
              "operator" => "eq",
              "value" => 30_000_142
            }
          ]
        }
      },
      %{
        name: "Capital Ship Kills",
        description: "Tracks capital ship destructions",
        filter_tree: %{
          "condition" => "and",
          "rules" => [
            %{
              "field" => "ship_group_id",
              "operator" => "in",
              # Carrier, Dreadnought, Supercarrier
              "value" => [547, 485, 513]
            }
          ]
        }
      }
    ]

    # Store profile templates for manual creation
    :ets.insert(:manual_testing_data, {:profile_templates, sample_profiles})

    IO.puts("  ✅ Sample surveillance profile templates ready")
  end

  @doc """
  Print complete test guide with URLs and instructions
  """
  def print_complete_test_guide do
    IO.puts(("\n" <> "=") |> String.duplicate(60))
    IO.puts("🎯 COMPLETE MANUAL TESTING GUIDE")
    IO.puts("=" |> String.duplicate(60))

    case :ets.lookup(:manual_testing_data, :test_data) do
      [{:test_data, test_data}] ->
        print_test_urls(test_data)
        print_authentication_instructions()
        print_surveillance_testing_instructions()
        print_data_verification_instructions()

      [] ->
        IO.puts("❌ Test data not generated. Run setup_complete_testing_environment() first.")
    end
  end

  @doc """
  Print all test URLs organized by category
  """
  def print_test_urls(test_data) do
    IO.puts("\n🔗 TEST URLS BY CATEGORY:")
    IO.puts("-" |> String.duplicate(40))

    IO.puts("\n📄 Public Pages (Test Suite 1):")
    IO.puts("  Home Page: http://localhost:4010/")
    IO.puts("  Kill Feed: http://localhost:4010/feed")

    IO.puts("\n🔐 Authentication Pages (Test Suite 2):")
    IO.puts("  Dashboard: http://localhost:4010/dashboard")
    IO.puts("  Profile: http://localhost:4010/profile")

    IO.puts("\n🕵️ Character Intelligence (Test Suite 4):")

    test_data.character_ids
    |> Enum.take(5)
    |> Enum.with_index(1)
    |> Enum.each(fn {char_id, i} ->
      IO.puts("  Character #{i}: http://localhost:4010/intel/#{char_id}")
    end)

    IO.puts("\n👤 Player Profiles (Test Suite 4):")

    test_data.character_ids
    |> Enum.take(3)
    |> Enum.with_index(1)
    |> Enum.each(fn {char_id, i} ->
      IO.puts("  Player #{i}: http://localhost:4010/player/#{char_id}")
    end)

    IO.puts("\n🏢 Corporation Pages (Test Suite 5):")

    test_data.corporation_ids
    |> Enum.take(3)
    |> Enum.with_index(1)
    |> Enum.each(fn {corp_id, i} ->
      IO.puts("  Corporation #{i}: http://localhost:4010/corp/#{corp_id}")
    end)

    IO.puts("\n🌟 Alliance Pages (Test Suite 5):")

    test_data.alliance_ids
    |> Enum.take(3)
    |> Enum.with_index(1)
    |> Enum.each(fn {alliance_id, i} ->
      IO.puts("  Alliance #{i}: http://localhost:4010/alliance/#{alliance_id}")
    end)

    IO.puts("\n👁️ Surveillance System (Test Suite 6):")
    IO.puts("  Surveillance Dashboard: http://localhost:4010/surveillance")

    IO.puts("\n🕳️ Wormhole Features (Test Suite 7):")
    IO.puts("  Chain Intelligence: http://localhost:4010/chain-intelligence")
    IO.puts("  WH Vetting: http://localhost:4010/wh-vetting")
  end

  @doc """
  Print authentication setup instructions
  """
  def print_authentication_instructions do
    IO.puts("\n🔐 AUTHENTICATION SETUP:")
    IO.puts("-" |> String.duplicate(40))
    IO.puts("1. For authenticated tests, you need to:")
    IO.puts("   a) Click 'Sign in with EVE' on the home page")
    IO.puts("   b) Complete EVE SSO authentication")
    IO.puts("   c) Return to EVE DMV with active session")
    IO.puts("")
    IO.puts("2. To create surveillance profiles for testing:")
    IO.puts("   a) Go to http://localhost:4010/surveillance")
    IO.puts("   b) Click 'Create Profile'")
    IO.puts("   c) Use the sample profiles listed below")
  end

  @doc """
  Print surveillance testing instructions
  """
  def print_surveillance_testing_instructions do
    IO.puts("\n👁️ SURVEILLANCE PROFILE TEMPLATES:")
    IO.puts("-" |> String.duplicate(40))

    case :ets.lookup(:manual_testing_data, :profile_templates) do
      [{:profile_templates, profiles}] ->
        Enum.with_index(profiles, 1)
        |> Enum.each(fn {profile, i} ->
          IO.puts("\n#{i}. #{profile.name}:")
          IO.puts("   Description: #{profile.description}")
          IO.puts("   Filter JSON: #{Jason.encode!(profile.filter_tree)}")
        end)

      [] ->
        IO.puts("❌ Profile templates not loaded")
    end
  end

  @doc """
  Print data verification instructions
  """
  def print_data_verification_instructions do
    IO.puts("\n📊 DATA VERIFICATION COMMANDS:")
    IO.puts("-" |> String.duplicate(40))
    IO.puts("Run these in the IEx console to verify data:")
    IO.puts("")
    IO.puts("1. Check recent killmail activity:")
    IO.puts("   ManualTestingDataGenerator.show_recent_activity(10)")
    IO.puts("")
    IO.puts("2. Verify surveillance engine:")
    IO.puts("   ManualTestingDataGenerator.check_surveillance_engine()")
    IO.puts("")
    IO.puts("3. Get fresh test IDs:")
    IO.puts("   ManualTestingDataGenerator.get_fresh_test_ids()")
    IO.puts("")
    IO.puts("4. Reload test data:")
    IO.puts("   ManualTestingDataGenerator.generate_test_data()")
  end

  @doc """
  Show recent killmail activity with details
  """
  def show_recent_activity(minutes \\ 10) do
    cutoff = DateTime.add(DateTime.utc_now(), -minutes * 60, :second)

    case KillmailRaw
         |> Ash.Query.filter(killmail_time >= ^cutoff)
         |> Ash.Query.sort(killmail_time: :desc)
         |> Ash.Query.limit(20)
         |> Ash.read(domain: Api) do
      {:ok, killmails} ->
        IO.puts("🎯 Recent Killmail Activity (last #{minutes} minutes):")
        IO.puts("Total: #{length(killmails)} killmails")

        killmails
        |> Enum.take(10)
        |> Enum.each(fn km ->
          age = DateTime.diff(DateTime.utc_now(), km.killmail_time, :minute)
          system_name = get_system_name(km.solar_system_id)
          value = format_isk(km.total_value || 0)
          IO.puts("  #{km.killmail_id} - #{system_name} - #{value} ISK - #{age}m ago")
        end)

        length(killmails)

      _ ->
        IO.puts("❌ Could not fetch recent activity")
        0
    end
  end

  @doc """
  Get fresh test IDs for immediate use
  """
  def get_fresh_test_ids do
    IO.puts("🔄 Getting fresh test IDs...")

    test_data = %{
      character_ids: get_diverse_character_ids(10),
      corporation_ids: get_diverse_corporation_ids(5),
      alliance_ids: get_diverse_alliance_ids(3)
    }

    IO.puts("📋 Fresh Test IDs:")
    IO.puts("Characters: #{Enum.join(test_data.character_ids, ", ")}")
    IO.puts("Corporations: #{Enum.join(test_data.corporation_ids, ", ")}")
    IO.puts("Alliances: #{Enum.join(test_data.alliance_ids, ", ")}")

    test_data
  end

  @doc """
  Create a test user and surveillance profile (for development)
  """
  def create_test_user_and_profile do
    IO.puts("👤 Creating test user and surveillance profile...")

    # This is for development/testing only
    # In production, users are created through EVE SSO

    user_data = %{
      character_id: 12_345,
      character_name: "Test Character",
      corporation_id: 67_890,
      corporation_name: "Test Corp",
      alliance_id: nil,
      alliance_name: nil,
      access_token: "test_token",
      refresh_token: "test_refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }

    case Ash.create(User, user_data, domain: Api) do
      {:ok, user} ->
        IO.puts("✅ Created test user: #{user.character_name}")

        # Create a test surveillance profile
        profile_data = %{
          name: "Test High Value Profile",
          description: "Tracks killmails over 50M ISK for testing",
          user_id: user.id,
          filter_tree: %{
            "condition" => "and",
            "rules" => [
              %{
                "field" => "total_value",
                "operator" => "gt",
                "value" => 50_000_000
              }
            ]
          },
          is_active: true
        }

        case Ash.create(Profile, profile_data, domain: Api) do
          {:ok, profile} ->
            IO.puts("✅ Created test surveillance profile: #{profile.name}")
            {user, profile}

          {:error, error} ->
            IO.puts("❌ Failed to create test profile: #{inspect(error)}")
            {user, nil}
        end

      {:error, error} ->
        IO.puts("❌ Failed to create test user: #{inspect(error)}")
        {nil, nil}
    end
  end

  # Helper functions
  defp get_system_name(system_id) do
    case EveDmv.StaticData.get_system_name(system_id) do
      {:ok, name} -> name
      _ -> "System #{system_id}"
    end
  end

  defp format_isk(value) when is_integer(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{value}"
    end
  end

  defp format_isk(value), do: "#{value}"
end

# Auto-setup message
IO.puts("🚀 EVE DMV Manual Testing Data Generator loaded!")
IO.puts("📋 Run: ManualTestingDataGenerator.setup_complete_testing_environment()")
IO.puts("   This will create all test data and print comprehensive testing guide")
IO.puts("")
IO.puts("🔧 Other useful commands:")
IO.puts("   ManualTestingDataGenerator.show_recent_activity(10)")
IO.puts("   ManualTestingDataGenerator.get_fresh_test_ids()")
IO.puts("   ManualTestingDataGenerator.check_surveillance_engine()")
