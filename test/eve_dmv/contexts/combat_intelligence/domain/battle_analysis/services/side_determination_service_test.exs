defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Services.SideDeterminationServiceTest do
  use ExUnit.Case
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Services.SideDeterminationService

  describe "classify_participants/2" do
    test "classifies participants from same alliance to same side" do
      participants = [
        %{character_id: 1, corporation_id: 100, alliance_id: 1000},
        %{character_id: 2, corporation_id: 101, alliance_id: 1000},
        %{character_id: 3, corporation_id: 200, alliance_id: 2000},
        %{character_id: 4, corporation_id: 201, alliance_id: 2000}
      ]

      killmails = [
        %{
          victim_character_id: 1,
          victim_corporation_id: 100,
          victim_alliance_id: 1000,
          attackers: [
            %{character_id: 3, corporation_id: 200, alliance_id: 2000},
            %{character_id: 4, corporation_id: 201, alliance_id: 2000}
          ]
        },
        %{
          victim_character_id: 3,
          victim_corporation_id: 200,
          victim_alliance_id: 2000,
          attackers: [
            %{character_id: 1, corporation_id: 100, alliance_id: 1000},
            %{character_id: 2, corporation_id: 101, alliance_id: 1000}
          ]
        }
      ]

      result = SideDeterminationService.classify_participants(participants, killmails)

      # Characters from same alliance should be on same side
      assert length(result.side_a) == 2
      assert length(result.side_b) == 2

      # Alliance 1000 members should be together
      alliance_1000_chars = Enum.filter(result.side_a ++ result.side_b, &(&1.alliance_id == 1000))

      side_of_alliance_1000 =
        if List.first(alliance_1000_chars) in result.side_a, do: :side_a, else: :side_b

      assert Enum.all?(alliance_1000_chars, fn char ->
               if side_of_alliance_1000 == :side_a do
                 char in result.side_a
               else
                 char in result.side_b
               end
             end)
    end

    test "classifies participants from same corporation but no alliance to same side" do
      participants = [
        %{character_id: 1, corporation_id: 100, alliance_id: nil},
        %{character_id: 2, corporation_id: 100, alliance_id: nil},
        %{character_id: 3, corporation_id: 200, alliance_id: nil},
        %{character_id: 4, corporation_id: 200, alliance_id: nil}
      ]

      killmails = [
        %{
          victim_character_id: 1,
          victim_corporation_id: 100,
          victim_alliance_id: nil,
          attackers: [
            %{character_id: 3, corporation_id: 200, alliance_id: nil}
          ]
        },
        %{
          victim_character_id: 4,
          victim_corporation_id: 200,
          victim_alliance_id: nil,
          attackers: [
            %{character_id: 2, corporation_id: 100, alliance_id: nil}
          ]
        }
      ]

      result = SideDeterminationService.classify_participants(participants, killmails)

      # Characters from same corp should be on same side
      corp_100_chars = Enum.filter(participants, &(&1.corporation_id == 100))
      corp_100_on_a = Enum.all?(corp_100_chars, &(&1 in result.side_a))
      corp_100_on_b = Enum.all?(corp_100_chars, &(&1 in result.side_b))

      assert corp_100_on_a or corp_100_on_b
    end

    test "handles participants with no kills or deaths" do
      participants = [
        %{character_id: 1, corporation_id: 100, alliance_id: 1000},
        %{character_id: 2, corporation_id: 100, alliance_id: 1000},
        %{character_id: 3, corporation_id: 200, alliance_id: 2000},
        # No kills/deaths
        %{character_id: 5, corporation_id: 300, alliance_id: nil}
      ]

      killmails = [
        %{
          victim_character_id: 1,
          victim_corporation_id: 100,
          victim_alliance_id: 1000,
          attackers: [
            %{character_id: 3, corporation_id: 200, alliance_id: 2000}
          ]
        }
      ]

      result = SideDeterminationService.classify_participants(participants, killmails)

      # Participant 5 might end up in unknown or assigned based on corp
      total_assigned =
        length(result.side_a) + length(result.side_b) + length(Map.get(result, :unknown, []))

      assert total_assigned == length(participants)
    end
  end

  describe "build_relationship_graph/1" do
    test "correctly tracks kills and deaths" do
      killmails = [
        %{
          victim_character_id: 1,
          victim_corporation_id: 100,
          victim_alliance_id: 1000,
          attackers: [
            %{character_id: 2, corporation_id: 200, alliance_id: 2000},
            %{character_id: 3, corporation_id: 201, alliance_id: 2000}
          ]
        },
        %{
          victim_character_id: 2,
          victim_corporation_id: 200,
          victim_alliance_id: 2000,
          attackers: [
            %{character_id: 1, corporation_id: 100, alliance_id: 1000}
          ]
        }
      ]

      graph = SideDeterminationService.build_relationship_graph(killmails)

      # Character 1 should have 1 death and 1 kill
      assert Enum.count(Map.get(graph.deaths, 1, [])) == 1
      assert Enum.count(Map.get(graph.kills, 1, [])) == 1

      # Character 2 should have 1 death and 1 kill
      assert Enum.count(Map.get(graph.deaths, 2, [])) == 1
      assert Enum.count(Map.get(graph.kills, 2, [])) == 1

      # Character 3 should have 0 deaths and 1 kill
      assert length(Map.get(graph.deaths, 3, [])) == 0
      assert length(Map.get(graph.kills, 3, [])) == 1
    end
  end

  describe "group_by_affiliations/1" do
    test "groups by alliance when available" do
      participants = [
        %{character_id: 1, corporation_id: 100, alliance_id: 1000},
        %{character_id: 2, corporation_id: 101, alliance_id: 1000},
        %{character_id: 3, corporation_id: 200, alliance_id: nil},
        %{character_id: 4, corporation_id: 300, alliance_id: 0}
      ]

      groups = SideDeterminationService.group_by_affiliations(participants)

      # Should have 3 groups: alliance 1000, corp 200, corp 300
      assert length(groups) == 3

      # Alliance 1000 group should have 2 members
      alliance_group = Enum.find(groups, &(&1.affiliation == {:alliance, 1000}))
      assert length(alliance_group.members) == 2
    end
  end

  describe "determine_participant_side/2" do
    test "determines side by alliance" do
      participant = %{character_id: 1, corporation_id: 100, alliance_id: 1000}

      battle_context = %{
        side_a_alliances: [1000, 1001],
        side_b_alliances: [2000, 2001]
      }

      assert SideDeterminationService.determine_participant_side(participant, battle_context) ==
               :side_a
    end

    test "determines side by corporation when no alliance" do
      participant = %{character_id: 1, corporation_id: 100, alliance_id: nil}

      battle_context = %{
        side_a_corporations: [100, 101],
        side_b_corporations: [200, 201]
      }

      assert SideDeterminationService.determine_participant_side(participant, battle_context) ==
               :side_a
    end

    test "returns unknown when not in any known group" do
      participant = %{character_id: 1, corporation_id: 999, alliance_id: 9999}

      battle_context = %{
        side_a_alliances: [1000, 1001],
        side_b_alliances: [2000, 2001],
        side_a_corporations: [100, 101],
        side_b_corporations: [200, 201]
      }

      assert SideDeterminationService.determine_participant_side(participant, battle_context) ==
               :unknown
    end
  end
end
