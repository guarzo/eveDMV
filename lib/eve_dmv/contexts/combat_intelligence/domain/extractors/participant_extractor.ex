defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor do
  @moduledoc """
  Extractor for identifying and analyzing battle participants from killmail data.

  This module has been refactored into specialized sub-modules for better maintainability:
  - Core: Basic participant extraction and enrichment
  - AffiliationAnalyzer: Corporation, alliance, and coalition analysis
  - RoleClassifier: Ship role and doctrine analysis
  - ExperienceAnalyzer: Player experience and skill assessment
  - ActivityTracker: Combat activity and engagement patterns

  All functionality is preserved through delegation to the appropriate sub-modules.
  """
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.ActivityTracker

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.AffiliationAnalyzer

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.Core

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.ExperienceAnalyzer

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.RoleClassifier

  require Logger

  @doc """
  Extract battle participants from killmail data.
  """
  def extract_battle_participants(killmails) do
    Logger.debug("Extracting battle participants from #{length(killmails)} killmails")

    # Extract detailed participant data from killmail information
    participants =
      killmails
      |> Enum.flat_map(&Core.extract_participants_from_killmail/1)
      |> Enum.uniq_by(& &1.character_id)
      |> Enum.map(fn participant ->
        participant
        |> Core.enrich_participant_data()
        |> Core.calculate_participant_metrics()
      end)

    %{
      participants: participants,
      total_count: length(participants),
      sides: Core.classify_participants_by_side(participants),
      affiliations: AffiliationAnalyzer.group_participants_by_affiliation(participants),
      roles: RoleClassifier.analyze_participant_roles(participants)
    }
  end

  @doc """
  Analyze participant affiliations and relationships.
  """
  def analyze_participant_affiliations(participants) do
    Logger.debug("Analyzing participant affiliations for #{length(participants)} participants")

    # Delegate to specialized affiliation analyzer
    corporations = AffiliationAnalyzer.group_by_corporation(participants)
    alliances = AffiliationAnalyzer.group_by_alliance(participants)
    coalitions = AffiliationAnalyzer.identify_coalitions(participants)
    neutral_parties = AffiliationAnalyzer.identify_neutral_parties(participants)
    relationship_map = AffiliationAnalyzer.build_relationship_map(participants)

    # Calculate affiliation strength and coherence metrics
    affiliation_metrics =
      AffiliationAnalyzer.calculate_affiliation_metrics(corporations, alliances, coalitions)

    %{
      corporations: corporations,
      alliances: alliances,
      coalitions: coalitions,
      neutral_parties: neutral_parties,
      relationship_map: relationship_map,
      metrics: affiliation_metrics,
      summary: %{
        dominant_corporation: AffiliationAnalyzer.find_dominant_affiliation(corporations),
        dominant_alliance: AffiliationAnalyzer.find_dominant_affiliation(alliances),
        coalition_count: length(coalitions),
        affiliation_diversity:
          AffiliationAnalyzer.calculate_affiliation_diversity(corporations, alliances)
      }
    }
  end

  @doc """
  Analyze participant combat roles and effectiveness.
  """
  def analyze_participant_roles(participants) do
    # Delegate to specialized role classifier
    RoleClassifier.analyze_participant_roles(participants)
  end

  @doc """
  Analyze participant experience levels and progression.
  """
  def analyze_participant_experience(participants) do
    # Delegate to specialized experience analyzer
    ExperienceAnalyzer.analyze_participant_experience(participants)
  end

  @doc """
  Track participant activity and engagement patterns.
  """
  def track_participant_activity(participants, killmails) do
    # Delegate to specialized activity tracker
    ActivityTracker.track_participant_activity(participants, killmails)
  end

  # Backward compatibility functions - delegate to sub-modules

  @doc """
  Group participants by corporation (backward compatibility).
  """
  defdelegate group_by_corporation(participants), to: AffiliationAnalyzer

  @doc """
  Group participants by alliance (backward compatibility).
  """
  defdelegate group_by_alliance(participants), to: AffiliationAnalyzer

  @doc """
  Identify coalitions (backward compatibility).
  """
  defdelegate identify_coalitions(participants), to: AffiliationAnalyzer

  @doc """
  Identify neutral parties (backward compatibility).
  """
  defdelegate identify_neutral_parties(participants), to: AffiliationAnalyzer

  @doc """
  Build relationship map (backward compatibility).
  """
  defdelegate build_relationship_map(participants), to: AffiliationAnalyzer

  @doc """
  Calculate affiliation metrics (backward compatibility).
  """
  defdelegate calculate_affiliation_metrics(corporations, alliances, coalitions),
    to: AffiliationAnalyzer

  @doc """
  Find dominant affiliation (backward compatibility).
  """
  defdelegate find_dominant_affiliation(affiliation_groups), to: AffiliationAnalyzer

  @doc """
  Calculate affiliation diversity (backward compatibility).
  """
  defdelegate calculate_affiliation_diversity(corporations, alliances), to: AffiliationAnalyzer

  @doc """
  Classify participant role (backward compatibility).
  """
  defdelegate classify_participant_role(participant), to: RoleClassifier

  @doc """
  Calculate role effectiveness (backward compatibility).
  """
  defdelegate calculate_role_effectiveness(role_participants), to: RoleClassifier

  @doc """
  Identify key players (backward compatibility).
  """
  defdelegate identify_key_players(role_participants), to: RoleClassifier

  @doc """
  Analyze role balance (backward compatibility).
  """
  defdelegate analyze_role_balance(role_distribution), to: RoleClassifier

  @doc """
  Identify missing roles (backward compatibility).
  """
  defdelegate identify_missing_roles(role_distribution), to: RoleClassifier

  @doc """
  Analyze role synergies (backward compatibility).
  """
  defdelegate analyze_role_synergies(role_distribution), to: RoleClassifier

  @doc """
  Calculate experience distribution (backward compatibility).
  """
  defdelegate calculate_experience_distribution(participants), to: ExperienceAnalyzer

  @doc """
  Analyze skill levels (backward compatibility).
  """
  defdelegate analyze_skill_levels(participants), to: ExperienceAnalyzer

  @doc """
  Identify skill advantages (backward compatibility).
  """
  defdelegate identify_skill_advantages(participants), to: ExperienceAnalyzer

  @doc """
  Identify veteran players (backward compatibility).
  """
  defdelegate identify_veteran_players(participants), to: ExperienceAnalyzer

  @doc """
  Identify rookie players (backward compatibility).
  """
  defdelegate identify_rookie_players(participants), to: ExperienceAnalyzer

  @doc """
  Calculate experience advantage (backward compatibility).
  """
  defdelegate calculate_experience_advantage(participants), to: ExperienceAnalyzer

  @doc """
  Count participant kills (backward compatibility).
  """
  defdelegate count_participant_kills(participant, killmails), to: ActivityTracker

  @doc """
  Count participant deaths (backward compatibility).
  """
  defdelegate count_participant_deaths(participant, killmails), to: ActivityTracker

  @doc """
  Calculate damage dealt (backward compatibility).
  """
  defdelegate calculate_damage_dealt(participant, killmails), to: ActivityTracker

  @doc """
  Calculate damage received (backward compatibility).
  """
  defdelegate calculate_damage_received(participant, killmails), to: ActivityTracker

  @doc """
  Build activity timeline (backward compatibility).
  """
  defdelegate build_activity_timeline(participant, killmails), to: ActivityTracker

  @doc """
  Calculate contribution score (backward compatibility).
  """
  defdelegate calculate_contribution_score(participant, killmails), to: ActivityTracker

  @doc """
  Extract participants from killmail (backward compatibility).
  """
  defdelegate extract_participants_from_killmail(killmail), to: Core

  @doc """
  Enrich participant data (backward compatibility).
  """
  defdelegate enrich_participant_data(participant), to: Core

  @doc """
  Calculate participant metrics (backward compatibility).
  """
  defdelegate calculate_participant_metrics(participant), to: Core

  @doc """
  Classify participants by side (backward compatibility).
  """
  defdelegate classify_participants_by_side(participants), to: Core
end
