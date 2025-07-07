defmodule EveDmv.Intelligence.Analyzers.FleetSkillAnalyzer do
  require Logger
  @moduledoc """
  Fleet skill analysis engine for EVE Online wormhole operations.

  Provides skill gap analysis, training priorities, and pilot readiness assessment
  for fleet doctrines. Uses killmail data and ship usage patterns to determine
  fleet readiness since direct skill API access is limited.

  See individual function documentation for usage examples.
  """


  @doc """
  Analyze skill requirements for a fleet doctrine against available pilots.

  Takes a doctrine template and available pilots, returns comprehensive skill analysis
  including critical gaps, role shortfalls, and training priorities.

  ## Parameters

  - `doctrine_template` - Map containing role definitions with skill requirements
  - `available_pilots` - List of pilot data with ship usage and stats

  ## Returns

  `{:ok, skill_analysis}` containing:
  - `critical_gaps` - List of critical skill shortages
  - `role_shortfalls` - Map of role-specific pilot shortages
  - `training_priorities` - Ranked list of skills to train

  ## Example

      iex> doctrine = %{
      ...>   "dps" => %{"required" => 4, "skills_required" => ["HAC IV"]},
      ...>   "logistics" => %{"required" => 2, "skills_required" => ["Logistics V"]}
      ...> }
      iex> FleetSkillAnalyzer.analyze_skill_requirements(doctrine, pilots)
      {:ok, %{
        "critical_gaps" => [...],
        "role_shortfalls" => %{...},
        "training_priorities" => [...]
      }}
  """
  def analyze_skill_requirements(doctrine_template, available_pilots) do
    skill_analysis = %{
      "critical_gaps" => find_critical_skill_gaps(doctrine_template, available_pilots),
      "role_shortfalls" => calculate_role_shortfalls(doctrine_template, available_pilots),
      "training_priorities" => generate_training_priorities(doctrine_template, available_pilots)
    }

    {:ok, skill_analysis}
  end

  @doc """
  Find critical skill gaps that prevent doctrine deployment.

  Analyzes each role in the doctrine template and identifies where qualified
  pilot counts fall short of requirements. Focuses on high-priority roles
  that are mission-critical for fleet operations.

  ## Parameters

  - `doctrine_template` - Map of role definitions with skill requirements
  - `available_pilots` - List of available pilot data

  ## Returns

  List of gap information maps containing:
  - `role` - Role name with shortage
  - `required_pilots` - Number of pilots needed
  - `qualified_pilots` - Number of qualified pilots available
  - `shortage` - Pilot shortage count
  - `missing_skills` - List of required skills
  - `impact` - Impact level ("critical" or "high")

  ## Example

      iex> FleetSkillAnalyzer.find_critical_skill_gaps(doctrine, pilots)
      [
        %{
          "role" => "logistics",
          "required_pilots" => 2,
          "qualified_pilots" => 1,
          "shortage" => 1,
          "missing_skills" => ["Logistics V"],
          "impact" => "critical"
        }
      ]
  """
  def find_critical_skill_gaps(doctrine_template, available_pilots) do
    # Identify critical skill gaps that prevent doctrine deployment
    gaps = []

    # Check each role for skill requirements
    gaps =
      Enum.reduce(doctrine_template, gaps, fn {role, role_data}, acc ->
        required_skills = role_data["skills_required"] || []
        qualified_pilots = count_qualified_pilots_for_role(available_pilots, required_skills)
        required_count = role_data["required"] || 1

        if qualified_pilots < required_count do
          shortage = required_count - qualified_pilots

          gap_info = %{
            "role" => role,
            "required_pilots" => required_count,
            "qualified_pilots" => qualified_pilots,
            "shortage" => shortage,
            "missing_skills" => required_skills,
            "impact" => if(role_data["priority"] <= 2, do: "critical", else: "high")
          }

          [gap_info | acc]
        else
          acc
        end
      end)

    gaps
  end

  @doc """
  Calculate role shortfalls for each role in the doctrine.

  Provides a comprehensive view of pilot availability across all roles,
  showing both shortages and qualified pilot counts.

  ## Parameters

  - `doctrine_template` - Map of role definitions
  - `available_pilots` - List of available pilot data

  ## Returns

  Map with role names as keys and shortfall information as values:
  - `shortage` - Number of additional pilots needed
  - `qualified_pilots` - Number of qualified pilots available

  ## Example

      iex> FleetSkillAnalyzer.calculate_role_shortfalls(doctrine, pilots)
      %{
        "dps" => %{"shortage" => 1, "qualified_pilots" => 3},
        "logistics" => %{"shortage" => 2, "qualified_pilots" => 0}
      }
  """
  def calculate_role_shortfalls(doctrine_template, available_pilots) do
    Enum.map(doctrine_template, fn {role, role_data} ->
      required_skills = role_data["skills_required"] || []
      qualified_pilots = count_qualified_pilots_for_role(available_pilots, required_skills)
      required_count = role_data["required"] || 1
      shortage = max(0, required_count - qualified_pilots)

      {role,
       %{
         "shortage" => shortage,
         "qualified_pilots" => qualified_pilots
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Generate training priorities based on skill impact and gaps.

  Analyzes all skills required by the doctrine and calculates which skills
  would have the most impact if trained. Considers both the number of pilots
  that need the skill and the criticality of the skill.

  ## Parameters

  - `doctrine_template` - Map of role definitions with skill requirements
  - `available_pilots` - List of available pilot data

  ## Returns

  List of training priority maps (sorted by impact and gap size):
  - `skill` - Skill name
  - `pilots_training` - Number of pilots who could benefit from training
  - `impact` - Impact level ("critical", "high", "medium", or "low")

  ## Example

      iex> FleetSkillAnalyzer.generate_training_priorities(doctrine, pilots)
      [
        %{
          "skill" => "Logistics V",
          "pilots_training" => 3,
          "impact" => "critical"
        },
        %{
          "skill" => "HAC IV",
          "pilots_training" => 2,
          "impact" => "high"
        }
      ]
  """
  def generate_training_priorities(doctrine_template, available_pilots) do
    # Analyze which skills would have the most impact if trained

    # Count current skill coverage
    skill_coverage =
      Enum.flat_map(doctrine_template, fn {_role, role_data} ->
        role_data["skills_required"] || []
      end)
      |> Enum.uniq()
      |> Enum.map(fn skill ->
        qualified_count =
          Enum.count(available_pilots, fn pilot ->
            check_skill_via_ship_usage(pilot, skill)
          end)

        needed_count =
          Enum.filter(doctrine_template, fn {_role, role_data} ->
            skill in (role_data["skills_required"] || [])
          end)
          |> Enum.map(fn {_role, role_data} -> role_data["required"] || 1 end)
          |> Enum.sum()

        gap = max(0, needed_count - qualified_count)

        %{
          skill: skill,
          qualified_pilots: qualified_count,
          needed_pilots: needed_count,
          gap: gap,
          impact: determine_skill_impact(skill, gap)
        }
      end)
      |> Enum.filter(fn coverage -> coverage.gap > 0 end)
      |> Enum.sort_by(fn coverage -> {coverage.impact, coverage.gap} end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn coverage ->
        %{
          "skill" => coverage.skill,
          "pilots_training" => find_pilots_close_to_skill(available_pilots, coverage.skill),
          "impact" => Atom.to_string(coverage.impact)
        }
      end)

    skill_coverage
  end

  @doc """
  Check if a pilot has a specific skill based on ship usage patterns.

  Since direct skill API access is limited, this function uses ship usage
  patterns from killmail data as a proxy for skill levels. Different ship
  types require different skill combinations.

  ## Parameters

  - `pilot` - Pilot data map with ship usage statistics
  - `skill` - Skill name to check for

  ## Returns

  Boolean indicating whether the pilot likely has the skill based on usage patterns.

  ## Example

      iex> FleetSkillAnalyzer.check_skill_via_ship_usage(pilot, "Logistics V")
      true

      iex> FleetSkillAnalyzer.check_skill_via_ship_usage(pilot, "HAC IV")
      false
  """
  def check_skill_via_ship_usage(pilot, skill) do
    ship_groups = Map.get(pilot, :ship_groups_flown, %{})

    skill_requirements()
    |> Map.get(skill_prefix(skill), :generic)
    |> check_skill_requirement(pilot, ship_groups)
  end

  @doc """
  Get skill requirements mapping for different skill types.

  Defines the ship usage patterns that indicate a pilot likely has
  specific skills. Uses either direct ship type usage or proxy patterns.

  ## Returns

  Map of skill prefixes to requirement definitions:
  - `:logistics` - Logistics or cruiser experience
  - `:hac` - Heavy Assault Cruiser or extensive cruiser experience
  - `:interceptors` - Interceptor or extensive frigate experience
  - `:command_ships` - Command ship or battlecruiser experience
  - `:recon_ships` - Complex recon ship requirements
  - `:interdictors` - Interdictor or destroyer experience
  - `:generic` - General combat experience

  ## Example

      iex> FleetSkillAnalyzer.skill_requirements()
      %{
        logistics: {:either, [{"Logistics", 0}, {"Cruisers", 5}]},
        hac: {:either, [{"Heavy Assault Cruisers", 0}, {"Cruisers", 10}]},
        ...
      }
  """
  def skill_requirements do
    %{
      logistics: {:either, [{"Logistics", 0}, {"Cruisers", 5}]},
      hac: {:either, [{"Heavy Assault Cruisers", 0}, {"Cruisers", 10}]},
      interceptors: {:either, [{"Interceptors", 0}, {"Frigates", 15}]},
      command_ships: {:either, [{"Command Ships", 0}, {"Battlecruisers", 5}]},
      recon_ships: {:complex_recon},
      interdictors: {:either, [{"Interdictors", 0}, {"Destroyers", 5}]},
      generic: {:generic}
    }
  end

  @doc """
  Calculate individual pilot skill readiness for specific role requirements.

  Evaluates how ready a pilot is for a specific role based on their
  ship usage patterns and experience. Returns a score from 0.0 to 1.0.

  ## Parameters

  - `pilot` - Pilot data map with ship usage and stats
  - `required_skills` - List of skills required for the role

  ## Returns

  Float between 0.0 and 1.0 representing skill readiness percentage.

  ## Example

      iex> FleetSkillAnalyzer.calculate_pilot_skill_readiness(pilot, ["HAC IV", "Logistics V"])
      0.85
  """
  def calculate_pilot_skill_readiness(pilot, required_skills) do
    # Calculate how ready the pilot is skill-wise (0.0-1.0)
    # Based on ship usage patterns as proxy for skill levels
    if length(required_skills) > 0 do
      pilot_ship_usage = Map.get(pilot, :ship_usage, %{})
      ship_usage_values = Map.values(pilot_ship_usage)
      total_experience = Enum.sum(ship_usage_values)

      # Calculate skill readiness based on ship usage patterns
      skill_readiness =
        Enum.map(
          required_skills,
          &assess_skill_readiness(&1, pilot, pilot_ship_usage, total_experience)
        )

      avg_readiness = Enum.sum(skill_readiness) / length(skill_readiness)
      Float.round(avg_readiness, 2)
    else
      1.0
    end
  end

  @doc """
  Assess skill readiness for a specific skill.

  Evaluates how ready a pilot is for a specific skill based on their
  ship usage patterns and total experience.

  ## Parameters

  - `skill` - Skill to assess (can be string or tuple format)
  - `pilot` - Pilot data map
  - `pilot_ship_usage` - Map of pilot's ship usage patterns
  - `total_experience` - Total experience points across all ships

  ## Returns

  Float between 0.0 and 1.0 representing readiness for this specific skill.
  """
  def assess_skill_readiness(skill, pilot, pilot_ship_usage, total_experience) do
    case skill do
      {:ship_class, class} ->
        class_experience = Map.get(pilot_ship_usage, class, 0)
        min(1.0, class_experience / max(1.0, total_experience * 0.1))

      {:role, role} ->
        pilot_roles = Map.get(pilot, :detected_roles, [])
        if role in pilot_roles, do: 0.9, else: 0.4

      _ ->
        0.6
    end
  end

  @doc """
  Determine the impact level of a skill gap.

  Evaluates how critical a skill gap is based on the skill type and
  the number of pilots missing the skill.

  ## Parameters

  - `skill` - Skill name to evaluate
  - `gap` - Number of pilots missing this skill

  ## Returns

  Atom representing impact level: `:critical`, `:high`, `:medium`, or `:low`.

  ## Example

      iex> FleetSkillAnalyzer.determine_skill_impact("Logistics V", 2)
      :critical

      iex> FleetSkillAnalyzer.determine_skill_impact("Gunnery V", 1)
      :medium
  """
  def determine_skill_impact(skill, gap) when gap > 0 do
    if critical_skill?(skill), do: :critical, else: classify_skill_gap(gap)
  end

  def determine_skill_impact(_skill, gap), do: classify_skill_gap(gap)

  @doc """
  Check if a skill is considered critical for fleet operations.

  Identifies skills that are essential for fleet functionality and
  whose absence would significantly impact fleet effectiveness.

  ## Parameters

  - `skill` - Skill name to check

  ## Returns

  Boolean indicating whether the skill is critical.

  ## Example

      iex> FleetSkillAnalyzer.critical_skill?("Logistics V")
      true

      iex> FleetSkillAnalyzer.critical_skill?("Gunnery V")
      false
  """
  def critical_skill?(skill) do
    String.contains?(skill, ["Logistics", "Command"])
  end

  @doc """
  Classify skill gap severity based on the number of missing pilots.

  Categorizes the severity of a skill gap based on how many pilots
  are missing the skill relative to fleet requirements.

  ## Parameters

  - `gap` - Number of pilots missing the skill

  ## Returns

  Atom representing gap severity: `:high`, `:medium`, or `:low`.

  ## Example

      iex> FleetSkillAnalyzer.classify_skill_gap(3)
      :high

      iex> FleetSkillAnalyzer.classify_skill_gap(1)
      :medium
  """
  def classify_skill_gap(gap) when gap >= 3, do: :high
  def classify_skill_gap(gap) when gap >= 1, do: :medium
  def classify_skill_gap(_gap), do: :low

  @doc """
  Find pilots who are close to qualifying for a specific skill.

  Identifies pilots who don't currently have a skill but are close
  to meeting the requirements based on their ship usage patterns.

  ## Parameters

  - `pilots` - List of pilot data maps
  - `skill` - Skill name to check for

  ## Returns

  Integer count of pilots who are close to qualifying for the skill.

  ## Example

      iex> FleetSkillAnalyzer.find_pilots_close_to_skill(pilots, "HAC IV")
      2
  """
  def find_pilots_close_to_skill(pilots, skill) do
    # Find pilots who are close to qualifying for this skill
    pilots
    |> Enum.filter(fn pilot ->
      not check_skill_via_ship_usage(pilot, skill) and
        pilot_close_to_skill?(pilot, skill)
    end)
    |> length()
  end

  # Private helper functions

  defp skill_prefix(skill) do
    cond do
      String.starts_with?(skill, "Logistics") -> :logistics
      String.starts_with?(skill, "HAC") -> :hac
      String.starts_with?(skill, "Interceptors") -> :interceptors
      String.starts_with?(skill, "Command Ships") -> :command_ships
      String.starts_with?(skill, "Recon Ships") -> :recon_ships
      String.starts_with?(skill, "Interdictors") -> :interdictors
      true -> :generic
    end
  end

  defp check_skill_requirement(requirement, pilot, ship_groups) do
    case requirement do
      {:either, options} ->
        Enum.any?(options, fn {ship_type, min_count} ->
          Map.get(ship_groups, ship_type, 0) > min_count
        end)

      :complex_recon ->
        Map.get(ship_groups, "Recon Ships", 0) > 0 or
          (Map.get(ship_groups, "Cruisers", 0) > 10 and pilot.kd_ratio > 1.0)

      :generic ->
        pilot.kill_count + pilot.loss_count >= 20
    end
  end

  defp pilot_close_to_skill?(pilot, skill) do
    # Check if pilot is close to meeting skill requirements
    ship_groups = Map.get(pilot, :ship_groups_flown, %{})

    case skill do
      "Logistics" <> _ ->
        Map.get(ship_groups, "Cruisers", 0) > 3

      "HAC" <> _ ->
        Map.get(ship_groups, "Cruisers", 0) > 5

      "Interceptors" <> _ ->
        Map.get(ship_groups, "Frigates", 0) > 8

      _ ->
        false
    end
  end

  defp count_qualified_pilots_for_role(available_pilots, required_skills) do
    available_pilots
    |> Enum.count(fn pilot -> pilot_meets_skill_requirements?(pilot, required_skills) end)
  end

  defp pilot_meets_skill_requirements?(pilot, required_skills) do
    # Check if pilot meets the skill requirements based on ship usage history
    # Use killmail data as proxy for skills since we can't access skill API

    # If no specific skill requirements, check general competence
    if Enum.empty?(required_skills) do
      pilot.kill_count + pilot.loss_count >= 10
    else
      # Check all required skills
      Enum.all?(required_skills, fn skill ->
        check_skill_via_ship_usage(pilot, skill)
      end)
    end
  end
end
