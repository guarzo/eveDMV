defmodule EveDmv.Contexts.SystemAnalysis.SecurityConfigTest do
  use ExUnit.Case, async: true

  alias EveDmv.Contexts.SystemAnalysis.SecurityConfig

  describe "security_danger_modifier/1" do
    test "returns 0.5 for highsec" do
      assert SecurityConfig.security_danger_modifier("highsec") == 0.5
    end

    test "returns 1.0 for lowsec" do
      assert SecurityConfig.security_danger_modifier("lowsec") == 1.0
    end

    test "returns 1.5 for nullsec" do
      assert SecurityConfig.security_danger_modifier("nullsec") == 1.5
    end

    test "returns 1.8 for wormhole" do
      assert SecurityConfig.security_danger_modifier("wormhole") == 1.8
    end

    test "returns nil for nil input" do
      assert SecurityConfig.security_danger_modifier(nil) == nil
    end

    test "returns nil for unknown security class" do
      assert SecurityConfig.security_danger_modifier("unknown") == nil
      assert SecurityConfig.security_danger_modifier("pochven") == nil
    end
  end

  describe "fallback_security_modifier/1" do
    test "returns 0.5 for highsec security status (>= 0.5)" do
      assert SecurityConfig.fallback_security_modifier(1.0) == 0.5
      assert SecurityConfig.fallback_security_modifier(0.8) == 0.5
      assert SecurityConfig.fallback_security_modifier(0.5) == 0.5
    end

    test "returns 1.0 for lowsec security status (0.0 to 0.4)" do
      assert SecurityConfig.fallback_security_modifier(0.4) == 1.0
      assert SecurityConfig.fallback_security_modifier(0.1) == 1.0
      assert SecurityConfig.fallback_security_modifier(0.0) == 1.0
    end

    test "returns 1.5 for nullsec security status (< 0.0)" do
      assert SecurityConfig.fallback_security_modifier(-0.1) == 1.5
      assert SecurityConfig.fallback_security_modifier(-0.5) == 1.5
      assert SecurityConfig.fallback_security_modifier(-1.0) == 1.5
    end

    test "returns 1.0 for nil input (default modifier)" do
      assert SecurityConfig.fallback_security_modifier(nil) == 1.0
    end
  end

  describe "danger_modifier/2" do
    test "uses security_class when available" do
      assert SecurityConfig.danger_modifier("highsec", 0.9) == 0.5
      assert SecurityConfig.danger_modifier("lowsec", 0.3) == 1.0
      assert SecurityConfig.danger_modifier("nullsec", -0.5) == 1.5
      assert SecurityConfig.danger_modifier("wormhole", 0.0) == 1.8
    end

    test "falls back to security_status when security_class is nil" do
      assert SecurityConfig.danger_modifier(nil, 0.9) == 0.5
      assert SecurityConfig.danger_modifier(nil, 0.3) == 1.0
      assert SecurityConfig.danger_modifier(nil, -0.5) == 1.5
    end

    test "falls back to security_status when security_class is unknown" do
      assert SecurityConfig.danger_modifier("unknown", 0.9) == 0.5
      assert SecurityConfig.danger_modifier("pochven", 0.3) == 1.0
    end

    test "returns default modifier when both inputs are nil" do
      assert SecurityConfig.danger_modifier(nil, nil) == 1.0
    end
  end

  describe "raw modifier accessors" do
    test "highsec_modifier returns 0.5" do
      assert SecurityConfig.highsec_modifier() == 0.5
    end

    test "lowsec_modifier returns 1.0" do
      assert SecurityConfig.lowsec_modifier() == 1.0
    end

    test "nullsec_modifier returns 1.5" do
      assert SecurityConfig.nullsec_modifier() == 1.5
    end

    test "wormhole_modifier returns 1.8" do
      assert SecurityConfig.wormhole_modifier() == 1.8
    end

    test "unknown_modifier returns 1.0" do
      assert SecurityConfig.unknown_modifier() == 1.0
    end
  end

  describe "security class ordering" do
    test "wormhole is more dangerous than nullsec" do
      assert SecurityConfig.security_danger_modifier("wormhole") >
               SecurityConfig.security_danger_modifier("nullsec")
    end

    test "nullsec is more dangerous than lowsec" do
      assert SecurityConfig.security_danger_modifier("nullsec") >
               SecurityConfig.security_danger_modifier("lowsec")
    end

    test "lowsec is more dangerous than highsec" do
      assert SecurityConfig.security_danger_modifier("lowsec") >
               SecurityConfig.security_danger_modifier("highsec")
    end
  end
end
