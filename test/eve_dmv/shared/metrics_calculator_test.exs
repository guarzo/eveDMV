defmodule EveDmv.Shared.MetricsCalculatorTest do
  use ExUnit.Case, async: true

  alias EveDmv.Shared.MetricsCalculator

  describe "calculate_current_metrics/1" do
    test "calculates metrics correctly with data" do
      state = %{
        metrics: %{average_analysis_time_ms: 0},
        recent_analysis_times: [100, 200, 150]
      }

      result = MetricsCalculator.calculate_current_metrics(state)

      assert result.average_analysis_time_ms == 150.0
    end

    test "handles empty recent analysis times" do
      state = %{
        metrics: %{average_analysis_time_ms: 50},
        recent_analysis_times: []
      }

      result = MetricsCalculator.calculate_current_metrics(state)

      assert result.average_analysis_time_ms == 0.0
    end

    test "preserves other metrics fields" do
      state = %{
        metrics: %{
          average_analysis_time_ms: 0,
          total_analyses: 100,
          cache_hits: 80
        },
        recent_analysis_times: [100, 200]
      }

      result = MetricsCalculator.calculate_current_metrics(state)

      assert result.average_analysis_time_ms == 150.0
      assert result.total_analyses == 100
      assert result.cache_hits == 80
    end
  end

  describe "calculate_average/1" do
    test "calculates average correctly" do
      assert MetricsCalculator.calculate_average([10, 20, 30]) == 20.0
    end

    test "handles empty list" do
      assert MetricsCalculator.calculate_average([]) == 0.0
    end

    test "handles single value" do
      assert MetricsCalculator.calculate_average([42]) == 42.0
    end

    test "rounds to 2 decimal places" do
      assert MetricsCalculator.calculate_average([1, 2, 3]) == 2.0
      assert MetricsCalculator.calculate_average([1, 2]) == 1.5
    end

    test "handles floating point precision" do
      # Test with values that would cause floating point precision issues
      result = MetricsCalculator.calculate_average([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
      assert result == 5.5
    end
  end

  describe "update_metrics_with_average/3" do
    test "updates metrics with calculated average" do
      metrics = %{existing_field: "value"}
      recent_times = [100, 200, 300]

      result = MetricsCalculator.update_metrics_with_average(metrics, recent_times)

      assert result.average_analysis_time_ms == 200.0
      assert result.existing_field == "value"
    end

    test "updates custom field name" do
      metrics = %{}
      recent_times = [10, 20, 30]

      result = MetricsCalculator.update_metrics_with_average(metrics, recent_times, :custom_field)

      assert result.custom_field == 20.0
    end

    test "handles empty times list" do
      metrics = %{other_field: 123}
      recent_times = []

      result = MetricsCalculator.update_metrics_with_average(metrics, recent_times)

      assert result.average_analysis_time_ms == 0.0
      assert result.other_field == 123
    end
  end

  describe "calculate_analyzer_metrics/1" do
    test "calculates metrics with data" do
      state = %{
        metrics: %{
          total_analyses: 100,
          cache_hits: 80,
          cache_misses: 20,
          average_analysis_time_ms: 150.5
        }
      }

      result = MetricsCalculator.calculate_analyzer_metrics(state)

      assert result.total == 100
      assert result.cache_hit_rate == 80.0
      assert result.cache_miss_rate == 20.0
      assert result.average_time_ms == 150.5
      assert %DateTime{} = result.last_updated
    end

    test "returns default metrics when total is zero" do
      state = %{
        metrics: %{
          total_analyses: 0,
          cache_hits: 0,
          cache_misses: 0
        }
      }

      result = MetricsCalculator.calculate_analyzer_metrics(state)
      default_metrics = MetricsCalculator.default_analyzer_metrics()

      # Check structure and values, excluding timestamp which will be different
      assert result.total == default_metrics.total
      assert result.cache_hit_rate == default_metrics.cache_hit_rate
      assert result.cache_miss_rate == default_metrics.cache_miss_rate
      assert result.average_time_ms == default_metrics.average_time_ms
      assert %DateTime{} = result.last_updated
    end

    test "handles missing fields gracefully" do
      state = %{
        metrics: %{
          total_analyses: 50
        }
      }

      result = MetricsCalculator.calculate_analyzer_metrics(state)

      assert result.total == 50
      assert result.cache_hit_rate == 0.0
      assert result.cache_miss_rate == 0.0
      assert result.average_time_ms == 0
    end

    test "handles invalid state" do
      result = MetricsCalculator.calculate_analyzer_metrics(%{})
      expected = MetricsCalculator.default_analyzer_metrics()

      # Compare all fields except timestamp which can have microsecond differences
      assert result.total == expected.total
      assert result.cache_hit_rate == expected.cache_hit_rate
      assert result.cache_miss_rate == expected.cache_miss_rate
      assert result.average_time_ms == expected.average_time_ms

      # Check timestamp is within reasonable range (1 second)
      assert DateTime.diff(result.last_updated, expected.last_updated, :second) <= 1
    end
  end

  describe "calculate_rate/2" do
    test "calculates percentage rate correctly" do
      assert MetricsCalculator.calculate_rate(80, 100) == 80.0
      assert MetricsCalculator.calculate_rate(1, 3) == 33.33
    end

    test "handles zero denominator" do
      assert MetricsCalculator.calculate_rate(10, 0) == 0.0
    end

    test "handles zero numerator" do
      assert MetricsCalculator.calculate_rate(0, 100) == 0.0
    end

    test "handles non-numeric inputs" do
      assert MetricsCalculator.calculate_rate("invalid", 100) == 0.0
      assert MetricsCalculator.calculate_rate(50, "invalid") == 0.0
    end
  end

  describe "default_analyzer_metrics/0" do
    test "returns correct default structure" do
      result = MetricsCalculator.default_analyzer_metrics()

      assert result.total == 0
      assert result.cache_hit_rate == 0.0
      assert result.cache_miss_rate == 0.0
      assert result.average_time_ms == 0
      assert %DateTime{} = result.last_updated
    end
  end
end
