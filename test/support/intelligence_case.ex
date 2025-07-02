defmodule EveDmv.IntelligenceCase do
  @moduledoc """
  Base case for intelligence module testing
  """

  use ExUnit.CaseTemplate

  import EveDmv.Factories

  using do
    quote do
      use EveDmv.DataCase, async: true

      import EveDmv.Factories
      import EveDmv.IntelligenceCase

      alias EveDmv.Intelligence.{
        CharacterAnalyzer,
        HomeDefenseAnalyzer,
        MemberActivityAnalyzer,
        WHFleetAnalyzer,
        WHVettingAnalyzer
      }
    end
  end

  def create_realistic_killmail_set(character_id, opts \\ []) do
    count = Keyword.get(opts, :count, 10)
    days_back = Keyword.get(opts, :days_back, 30)

    for _i <- 1..count do
      create(:killmail_raw, %{
        killmail_data: %{
          "victim" => %{"character_id" => character_id},
          "killmail_time" => random_datetime_in_past(days_back)
        }
      })
    end
  end

  def create_wormhole_activity(character_id, wh_class, opts \\ []) do
    # Create realistic wormhole activity patterns
    count = Keyword.get(opts, :count, 5)
    days_back = Keyword.get(opts, :days_back, 30)

    # J-space system IDs for different wormhole classes
    wh_system_id =
      case wh_class do
        "C1" -> Enum.random(31_000_000..31_001_000)
        "C2" -> Enum.random(31_001_000..31_002_000)
        "C3" -> Enum.random(31_002_000..31_003_000)
        "C4" -> Enum.random(31_003_000..31_004_000)
        "C5" -> Enum.random(31_004_000..31_005_000)
        "C6" -> Enum.random(31_005_000..31_006_000)
        _ -> Enum.random(31_000_000..31_006_000)
      end

    for _i <- 1..count do
      create(:killmail_raw, %{
        solar_system_id: wh_system_id,
        killmail_data: %{
          "victim" => %{"character_id" => character_id},
          "killmail_time" => random_datetime_in_past(days_back),
          "solar_system_id" => wh_system_id
        }
      })
    end
  end

  def create_pvp_pattern(character_id, pattern_type, opts \\ []) do
    case pattern_type do
      :hunter ->
        # Creates killmails where character is frequently the attacker
        create_hunter_pattern(character_id, opts)

      :victim ->
        # Creates killmails where character is frequently the victim
        create_victim_pattern(character_id, opts)

      :mixed ->
        # Creates a balanced mix of kills and losses
        create_mixed_pattern(character_id, opts)
    end
  end

  defp create_hunter_pattern(character_id, opts) do
    count = Keyword.get(opts, :count, 10)

    for _i <- 1..count do
      victim_id = Enum.random(90_000_000..100_000_000)

      create(:killmail_raw, %{
        killmail_data: %{
          "victim" => %{"character_id" => victim_id},
          "attackers" => [
            %{
              "character_id" => character_id,
              "final_blow" => true,
              # T3 cruisers
              "ship_type_id" => Enum.random([17_738, 29_984])
            }
          ],
          "killmail_time" => random_datetime_in_past(30)
        }
      })
    end
  end

  defp create_victim_pattern(character_id, opts) do
    count = Keyword.get(opts, :count, 10)

    for _i <- 1..count do
      attacker_id = Enum.random(90_000_000..100_000_000)

      create(:killmail_raw, %{
        killmail_data: %{
          "victim" => %{
            "character_id" => character_id,
            # Cheap ships
            "ship_type_id" => Enum.random([587, 588, 589])
          },
          "attackers" => [
            %{
              "character_id" => attacker_id,
              "final_blow" => true
            }
          ],
          "killmail_time" => random_datetime_in_past(30)
        }
      })
    end
  end

  defp create_mixed_pattern(character_id, opts) do
    kill_count = Keyword.get(opts, :kill_count, 5)
    loss_count = Keyword.get(opts, :loss_count, 5)

    create_hunter_pattern(character_id, count: kill_count)
    create_victim_pattern(character_id, count: loss_count)
  end

  def create_corporate_activity(corporation_id, opts \\ []) do
    member_count = Keyword.get(opts, :member_count, 10)
    killmails_per_member = Keyword.get(opts, :killmails_per_member, 5)

    members =
      for _i <- 1..member_count do
        %{
          character_id: Enum.random(90_000_000..100_000_000),
          corporation_id: corporation_id
        }
      end

    for member <- members do
      for _j <- 1..killmails_per_member do
        create(:killmail_raw, %{
          killmail_data: %{
            "victim" => %{
              "character_id" => member.character_id,
              "corporation_id" => corporation_id
            },
            "killmail_time" => random_datetime_in_past(30)
          }
        })
      end
    end

    members
  end

  def create_alliance_activity(alliance_id, opts \\ []) do
    corporation_count = Keyword.get(opts, :corporation_count, 3)
    members_per_corp = Keyword.get(opts, :members_per_corp, 5)

    corporations =
      for _i <- 1..corporation_count do
        Enum.random(1_000_000..2_000_000)
      end

    all_members =
      for corp_id <- corporations do
        members =
          create_corporate_activity(corp_id,
            member_count: members_per_corp,
            killmails_per_member: 3
          )

        # Update members to include alliance_id
        for member <- members do
          Map.put(member, :alliance_id, alliance_id)
        end
      end

    List.flatten(all_members)
  end
end
