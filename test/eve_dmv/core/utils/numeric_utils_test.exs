defmodule EveDmv.Core.Utils.NumericUtilsTest do
  use ExUnit.Case, async: true

  alias EveDmv.Core.Utils.NumericUtils

  describe "decimal_to_rounded_float/2" do
    test "converts Decimal to float with default precision" do
      decimal = Decimal.new("3.14159")
      assert NumericUtils.decimal_to_rounded_float(decimal) == 3.14
    end

    test "converts Decimal to float with custom precision" do
      decimal = Decimal.new("3.14159")
      assert NumericUtils.decimal_to_rounded_float(decimal, 3) == 3.142
    end

    test "converts integer to float" do
      assert NumericUtils.decimal_to_rounded_float(42) == 42.0
    end

    test "converts float with rounding" do
      assert NumericUtils.decimal_to_rounded_float(3.14159) == 3.14
      assert NumericUtils.decimal_to_rounded_float(3.14159, 3) == 3.142
    end

    test "returns 0.0 for nil" do
      assert NumericUtils.decimal_to_rounded_float(nil) == 0.0
    end

    test "returns 0.0 for unrecognized types" do
      assert NumericUtils.decimal_to_rounded_float("string") == 0.0
      assert NumericUtils.decimal_to_rounded_float(:atom) == 0.0
    end
  end

  describe "to_float/1" do
    test "converts Decimal to float" do
      decimal = Decimal.new("3.14159")
      assert NumericUtils.to_float(decimal) == 3.14159
    end

    test "converts integer to float" do
      assert NumericUtils.to_float(42) == 42.0
    end

    test "passes through float" do
      assert NumericUtils.to_float(3.14) == 3.14
    end

    test "returns nil for nil" do
      assert NumericUtils.to_float(nil) == nil
    end

    test "returns nil for unrecognized types" do
      assert NumericUtils.to_float("string") == nil
    end
  end

  describe "calculate_kd_ratio/2" do
    test "calculates ratio with positive deaths" do
      assert NumericUtils.calculate_kd_ratio(10, 5) == 2.0
      assert NumericUtils.calculate_kd_ratio(10, 3) == 3.33
      assert NumericUtils.calculate_kd_ratio(7, 2) == 3.5
    end

    test "returns kills as float when deaths is zero and kills > 0" do
      assert NumericUtils.calculate_kd_ratio(10, 0) == 10.0
      assert NumericUtils.calculate_kd_ratio(5, 0) == 5.0
    end

    test "returns 0.0 when both are zero" do
      assert NumericUtils.calculate_kd_ratio(0, 0) == 0.0
    end

    test "handles Decimal inputs" do
      kills = Decimal.new("15")
      deaths = Decimal.new("3")
      assert NumericUtils.calculate_kd_ratio(kills, deaths) == 5.0
    end

    test "handles nil inputs" do
      assert NumericUtils.calculate_kd_ratio(nil, 5) == 0.0
      assert NumericUtils.calculate_kd_ratio(10, nil) == 10.0
      assert NumericUtils.calculate_kd_ratio(nil, nil) == 0.0
    end

    test "always returns float type" do
      result1 = NumericUtils.calculate_kd_ratio(10, 0)
      assert is_float(result1)

      result2 = NumericUtils.calculate_kd_ratio(10, 5)
      assert is_float(result2)

      result3 = NumericUtils.calculate_kd_ratio(0, 0)
      assert is_float(result3)
    end
  end
end
