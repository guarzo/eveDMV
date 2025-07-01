# Team Delta - Testing & Quality Implementation Plan

> **AI Assistant Instructions for Testing & Quality Team**
> 
> You are Team Delta, responsible for test infrastructure, CI/CD improvements, and ensuring code quality across all teams. You **support all other teams** and **merge last** every Friday.

## 🎯 **Your Mission**

Build comprehensive test coverage, fix CI/CD issues, implement quality gates, and ensure all code meets high standards. You are the quality guardian for the entire project.

## ⚠️ **Critical Instructions**

### **Quality Requirements**
After **EVERY SINGLE TASK**, you must run:
```bash
mix format
mix credo --strict
mix dialyzer
mix test --warnings-as-errors
git add -A && git commit -m "descriptive message"
```

### **No Stubs or Placeholders**
- **NEVER** create placeholder test implementations
- **NEVER** use TODO comments in test code
- **NEVER** skip tests without proper setup - fix the underlying issue
- Write **REAL TESTS** that validate actual functionality

### **Testing Standards**
- **100% test coverage** for critical business logic
- **Real test data** - no mocked responses unless absolutely necessary
- **Property-based testing** for complex algorithms
- **Integration tests** for cross-module functionality

### **Merge Coordination**
- **YOU MERGE LAST** every Friday (after all other teams)
- **SUPPORT OTHER TEAMS** with testing as they implement
- **BLOCK MERGES** if quality gates fail
- **COORDINATE** test data needs with Team Beta

## 📋 **Phase 1 Tasks (Weeks 1-4) - TEST INFRASTRUCTURE**

### **Week 1: Fix Test Configuration** 🔧

#### Task 1.1: Configure Unique Development Ports
**IMPORTANT**: Configure unique ports for Team Delta devcontainer to avoid conflicts with other teams.

**File**: `.devcontainer/devcontainer.json` (Delta worktree)
```json
{
  "name": "EVE DMV Delta Team Dev Container",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "shutdownAction": "stopCompose",
  "forwardPorts": [4014, 5437, 6384],
  "portsAttributes": {
    "4014": {
      "label": "Phoenix Server (Delta)",
      "onAutoForward": "notify"
    },
    "5437": {
      "label": "PostgreSQL (Delta)"
    },
    "6384": {
      "label": "Redis (Delta)"
    }
  }
}
```

**File**: `docker-compose.yml` (Delta worktree)
```yaml
services:
  db:
    image: postgres:17-alpine
    container_name: eve_tracker_db_delta
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: eve_tracker_delta
      POSTGRES_HOST_AUTH_METHOD: trust
    volumes:
      - postgres_data_delta:/var/lib/postgresql/data
    ports:
      - "5437:5432"

  redis:
    image: redis:7-alpine
    container_name: eve_tracker_redis_delta
    volumes:
      - redis_data_delta:/data
    ports:
      - "6384:6379"

  app:
    container_name: eve_tracker_app_delta
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db/eve_tracker_delta
      - REDIS_URL=redis://redis:6379
      - PHX_HOST=localhost
      - PHX_PORT=4014
    ports:
      - "4014:4014"

volumes:
  postgres_data_delta:
  redis_data_delta:
  mix_deps_delta:
  mix_build_delta:
```

**File**: `config/dev.exs` (Delta worktree)
```elixir
config :eve_dmv, EveDmvWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4014],
  # ... rest of config
```

#### Task 1.2: Fix Database Sandbox Configuration
**File**: `config/test.exs`

Fix the sandbox configuration that's currently broken:
```elixir
# Fix the pool configuration for tests
config :eve_dmv, EveDmv.Repo,
  username: "postgres",
  password: "postgres", 
  hostname: "localhost",
  database: "eve_dmv_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
```

**File**: `test/test_helper.exs`

Fix the sandbox mode configuration:
```elixir
ExUnit.start()

# Set up the sandbox mode properly
Ecto.Adapters.SQL.Sandbox.mode(EveDmv.Repo, :manual)

# Create a setup that works for async tests
defmodule TestHelper do
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(EveDmv.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

#### Task 1.2: Add ExCoveralls Dependency
**File**: `mix.exs`

Add proper coverage reporting:
```elixir
defp deps do
  [
    # ... existing deps ...
    {:excoveralls, "~> 0.18", only: :test}
  ]
end

def project do
  [
    # ... existing config ...
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test
    ]
  ]
end
```

#### Task 1.3: Fix Partition Tests
**File**: `test/eve_dmv/killmails/killmail_raw_test.exs`

Fix skipped partition tests (lines 67, 146, 161, 175):
```elixir
defmodule EveDmv.Killmails.KillmailRawTest do
  use EveDmv.DataCase, async: true
  
  setup do
    # Create necessary partitions for test data
    create_test_partitions()
    :ok
  end
  
  defp create_test_partitions do
    # Create monthly partitions for the current and next month
    current_date = Date.utc_today()
    next_month = Date.add(current_date, 30)
    
    for date <- [current_date, next_month] do
      partition_name = "killmails_raw_#{Date.to_string(date, :basic)}"
      create_partition_if_not_exists("killmails_raw", partition_name, date)
    end
  end
  
  defp create_partition_if_not_exists(table_name, partition_name, date) do
    start_date = Date.beginning_of_month(date)
    end_date = Date.end_of_month(date)
    
    query = """
    CREATE TABLE IF NOT EXISTS #{partition_name} PARTITION OF #{table_name}
    FOR VALUES FROM ('#{start_date}') TO ('#{end_date}')
    """
    
    Ecto.Adapters.SQL.query!(EveDmv.Repo, query)
  rescue
    # Partition might already exist, ignore error
    Postgrex.Error -> :ok
  end
  
  # Remove @tag :skip from all tests and make them work
  test "creates killmail with proper partition" do
    # Implementation that actually works
  end
end
```

### **Week 2: Fix CI/CD Issues** 🔄

#### Task 2.1: Fix Shellcheck Warning
**File**: `scripts/check_coverage.sh`

Fix line 22 shellcheck warning:
```bash
#!/bin/bash
set -e

# Fix the inline environment variable assignment
export MIX_ENV=test
mix test --cover

# Check if coverage meets threshold
COVERAGE=$(mix coveralls.json | jq -r '.coverage')
THRESHOLD=70

if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
  echo "Coverage $COVERAGE% is below threshold $THRESHOLD%"
  exit 1
fi

echo "Coverage $COVERAGE% meets threshold $THRESHOLD%"
```

#### Task 2.2: Update GitHub Actions
**Files**: `.github/workflows/coverage-comment.yml` and `.github/workflows/coverage-ratchet.yml`

Update outdated actions and fix formatting:
```yaml
# Update to latest versions
- uses: actions/cache@v4
  with:
    path: |
      deps
      _build
    key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}

# Fix multi-line echo statements
- name: Format coverage output
  run: |
    cat << 'EOF' > coverage_summary.md
    ## Coverage Report
    
    Current coverage: ${{ env.COVERAGE }}%
    Threshold: 70%
    Status: ${{ env.STATUS }}
    EOF
```

#### Task 2.3: Fix YAML Formatting
Fix indentation and formatting issues in all workflow files.

### **Week 3: Create Test Infrastructure** 🏗️

#### Task 3.1: Create Test Data Factories
**File**: `test/support/factories.ex`

Create comprehensive test data factories:
```elixir
defmodule EveDmv.Factories do
  @moduledoc """
  Test data factories for EVE DMV testing
  """
  
  alias EveDmv.{Api, Killmails.KillmailRaw, Users.User}
  
  def character_factory do
    %{
      character_id: Enum.random(90_000_000..100_000_000),
      character_name: "Test Character #{System.unique_integer([:positive])}",
      corporation_id: Enum.random(1_000_000..2_000_000),
      alliance_id: Enum.random(99_000_000..100_000_000)
    }
  end
  
  def killmail_raw_factory do
    killmail_time = DateTime.utc_now() |> DateTime.add(-Enum.random(1..3600), :second)
    
    %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: killmail_time,
      solar_system_id: Enum.random(30_000_000..31_000_000),
      killmail_data: build_realistic_killmail_data()
    }
  end
  
  def user_factory do
    character = build(:character)
    
    %{
      character_id: character.character_id,
      character_name: character.character_name,
      corporation_id: character.corporation_id,
      alliance_id: character.alliance_id,
      access_token: "test_access_token_#{System.unique_integer([:positive])}",
      refresh_token: "test_refresh_token_#{System.unique_integer([:positive])}",
      token_expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
    }
  end
  
  def build(factory_name, attrs \\ %{}) do
    factory_name
    |> build_factory()
    |> Map.merge(attrs)
  end
  
  def create(factory_name, attrs \\ %{}) do
    factory_name
    |> build(attrs)
    |> insert_into_database()
  end
  
  defp build_realistic_killmail_data do
    # Create realistic killmail JSON structure
    %{
      "killmail_id" => System.unique_integer([:positive]),
      "victim" => %{
        "character_id" => Enum.random(90_000_000..100_000_000),
        "corporation_id" => Enum.random(1_000_000..2_000_000),
        "ship_type_id" => Enum.random([587, 588, 589])  # Rifter, Rupture, Stabber
      },
      "attackers" => [
        %{
          "character_id" => Enum.random(90_000_000..100_000_000),
          "corporation_id" => Enum.random(1_000_000..2_000_000),
          "ship_type_id" => Enum.random([587, 588, 589]),
          "final_blow" => true
        }
      ]
    }
  end
end
```

#### Task 3.2: Fix Property Test Character ID Range
**File**: `test/eve_dmv_web/controllers/auth_controller_test.exs`

Fix character ID generation (lines 343-380):
```elixir
defp character_id_generator do
  # EVE character IDs start from 90,000,000
  StreamData.integer(90_000_000..2_147_483_647)
end

property "handles various character ID formats" do
  check all character_id <- character_id_generator(),
            max_runs: 100 do
    # Test with realistic character ID ranges
    assert character_id >= 90_000_000
  end
end
```

#### Task 3.3: Fix Rate Limiting Test
**File**: `test/eve_dmv_web/controllers/auth_controller_test.exs`

Fix misleading test name and implementation (lines 382-424):
```elixir
test "maintains stability under rapid authentication attempts" do
  # Rename to reflect actual behavior
  # This test validates stability, not rate limiting
  
  tasks = for _i <- 1..10 do
    Task.async(fn ->
      # Concurrent authentication attempts
      conn = build_conn()
      |> get(~p"/auth/eve")
      
      assert conn.status in [200, 302]
    end)
  end
  
  # Wait for all tasks and ensure none crashed
  results = Task.await_many(tasks, 5000)
  assert length(results) == 10
end

# Add actual rate limiting test if rate limiting exists
test "implements rate limiting for authentication" do
  # Only add this if actual rate limiting is implemented
  skip("Rate limiting not yet implemented")
end
```

### **Week 4: Intelligence Module Testing Setup** 🧠

#### Task 4.1: Create Intelligence Test Base
**File**: `test/support/intelligence_case.ex`

Create base case for intelligence testing:
```elixir
defmodule EveDmv.IntelligenceCase do
  @moduledoc """
  Base case for intelligence module testing
  """
  
  use ExUnit.CaseTemplate
  
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
  end
end
```

**END OF PHASE 1** - Test infrastructure complete

## 📋 **Phase 2 Tasks (Weeks 5-8) - CRITICAL BUSINESS LOGIC TESTING**

### **Week 5: Test Character Analyzer** 👤

#### Task 5.1: Comprehensive Character Analysis Tests
**File**: `test/eve_dmv/intelligence/character_analyzer_test.exs`

Create comprehensive test suite:
```elixir
defmodule EveDmv.Intelligence.CharacterAnalyzerTest do
  use EveDmv.IntelligenceCase, async: true
  
  describe "analyze_character/1" do
    test "analyzes character with killmail history" do
      character_id = 95_465_499
      
      # Create realistic test data
      killmails = create_realistic_killmail_set(character_id, count: 50)
      
      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)
      
      assert character_stats.character_id == character_id
      assert character_stats.dangerous_rating >= 0
      assert character_stats.dangerous_rating <= 5
      assert is_list(character_stats.frequent_systems)
      assert is_map(character_stats.ship_usage)
    end
    
    test "handles character with no killmail history" do
      character_id = 95_465_500
      
      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)
      
      assert character_stats.dangerous_rating == 0
      assert character_stats.frequent_systems == []
      assert character_stats.ship_usage == %{}
    end
    
    test "calculates dangerous rating accurately" do
      character_id = 95_465_501
      
      # Create high-threat killmail pattern
      create_high_threat_killmails(character_id)
      
      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)
      assert character_stats.dangerous_rating >= 4
    end
    
    test "identifies frequent systems correctly" do
      character_id = 95_465_502
      system_id = 30_000_142  # Jita
      
      # Create multiple killmails in same system
      for _i <- 1..10 do
        create(:killmail_raw, %{
          solar_system_id: system_id,
          killmail_data: %{"victim" => %{"character_id" => character_id}}
        })
      end
      
      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)
      assert system_id in Enum.map(character_stats.frequent_systems, & &1.system_id)
    end
  end
  
  describe "dangerous_rating calculation" do
    property "dangerous rating is always between 0 and 5" do
      check all killmail_count <- StreamData.integer(0..100),
                victim_ratio <- StreamData.float(min: 0.0, max: 1.0) do
        
        character_id = System.unique_integer([:positive])
        create_killmails_with_ratio(character_id, killmail_count, victim_ratio)
        
        {:ok, stats} = CharacterAnalyzer.analyze_character(character_id)
        assert stats.dangerous_rating >= 0
        assert stats.dangerous_rating <= 5
      end
    end
  end
  
  defp create_high_threat_killmails(character_id) do
    # Create pattern indicating dangerous player
    for _i <- 1..20 do
      create(:killmail_raw, %{
        killmail_data: %{
          "attackers" => [%{
            "character_id" => character_id,
            "final_blow" => true,
            "ship_type_id" => 17_738  # Loki (T3 cruiser)
          }],
          "victim" => %{
            "character_id" => Enum.random(90_000_000..95_000_000),
            "ship_type_id" => Enum.random([587, 588, 589])  # Cheap ships
          }
        }
      })
    end
  end
end
```

#### Task 5.2: Test Character Metrics Module
Create tests for the new `CharacterMetrics` module after Team Gamma splits it.

### **Week 6: Test Price Service** 💰

#### Task 6.1: Market Price Service Tests
**File**: `test/eve_dmv/market/price_service_test.exs`

Test the critical pricing functionality:
```elixir
defmodule EveDmv.Market.PriceServiceTest do
  use EveDmv.DataCase, async: true
  
  alias EveDmv.Market.PriceService
  
  describe "get_item_price/1" do
    test "retrieves price from Janice API" do
      type_id = 587  # Rifter
      
      # Test with real API if available, mock if necessary
      assert {:ok, price_data} = PriceService.get_item_price(type_id)
      
      assert is_number(price_data.average_price)
      assert price_data.average_price > 0
    end
    
    test "handles API failures gracefully" do
      # Test with invalid type_id
      type_id = -1
      
      assert {:error, _reason} = PriceService.get_item_price(type_id)
    end
    
    test "falls back to alternative pricing sources" do
      type_id = 587
      
      # Test fallback strategy when primary API fails
      result = PriceService.get_item_price_with_fallback(type_id)
      
      assert {:ok, _price_data} = result
    end
  end
  
  describe "price caching" do
    test "caches price results" do
      type_id = 587
      
      # First call
      {:ok, price1} = PriceService.get_item_price(type_id)
      
      # Second call should use cache
      {:ok, price2} = PriceService.get_item_price(type_id)
      
      assert price1 == price2
    end
    
    test "respects cache TTL" do
      # Test cache expiration behavior
    end
  end
end
```

### **Week 7: Test Circuit Breaker System** ⚡

#### Task 7.1: Circuit Breaker Tests
**File**: `test/eve_dmv/eve/circuit_breaker_test.exs`

Test the critical reliability infrastructure:
```elixir
defmodule EveDmv.Eve.CircuitBreakerTest do
  use EveDmv.DataCase, async: true
  
  alias EveDmv.Eve.CircuitBreaker
  
  describe "circuit breaker functionality" do
    test "opens circuit after failure threshold" do
      service = :test_service
      
      # Simulate failures to trigger circuit breaker
      for _i <- 1..5 do
        assert {:error, _} = CircuitBreaker.call(service, fn -> 
          {:error, :simulated_failure} 
        end)
      end
      
      # Circuit should now be open
      assert {:error, :circuit_open} = CircuitBreaker.call(service, fn -> 
        {:ok, :success} 
      end)
    end
    
    test "closes circuit after successful recovery" do
      service = :test_service_2
      
      # Open the circuit
      for _i <- 1..5 do
        CircuitBreaker.call(service, fn -> {:error, :failure} end)
      end
      
      # Wait for half-open state and succeed
      :timer.sleep(30_100)  # Wait for recovery timeout
      
      # Should allow recovery attempt
      assert {:ok, :success} = CircuitBreaker.call(service, fn -> 
        {:ok, :success} 
      end)
    end
    
    test "tracks metrics correctly" do
      service = :test_service_3
      
      # Execute some successful and failed requests
      CircuitBreaker.call(service, fn -> {:ok, :success} end)
      CircuitBreaker.call(service, fn -> {:error, :failure} end)
      
      metrics = CircuitBreaker.get_metrics(service)
      
      assert metrics.success_count >= 1
      assert metrics.failure_count >= 1
    end
  end
end
```

### **Week 8: Integration Testing** 🔗

#### Task 8.1: Killmail Pipeline Integration Tests
**File**: `test/integration/killmail_pipeline_test.exs`

Test end-to-end killmail processing:
```elixir
defmodule EveDmv.Integration.KillmailPipelineTest do
  use EveDmv.DataCase, async: false  # Pipeline tests need isolation
  
  alias EveDmv.Killmails.KillmailPipeline
  
  @tag :integration
  describe "end-to-end killmail processing" do
    test "processes killmail from ingestion to intelligence" do
      # Create realistic killmail data
      raw_killmail = build_realistic_killmail()
      
      # Process through pipeline
      assert :ok = KillmailPipeline.process_killmail(raw_killmail)
      
      # Verify enrichment
      enriched = get_enriched_killmail(raw_killmail.killmail_id)
      assert enriched.victim_character_name != nil
      
      # Verify intelligence update
      character_id = raw_killmail.killmail_data["victim"]["character_id"]
      {:ok, stats} = CharacterAnalyzer.analyze_character(character_id)
      assert stats.total_losses >= 1
    end
    
    test "handles malformed killmail data gracefully" do
      malformed_killmail = %{
        killmail_id: 123,
        killmail_data: %{"invalid" => "structure"}
      }
      
      # Should not crash the pipeline
      result = KillmailPipeline.process_killmail(malformed_killmail)
      assert {:error, _reason} = result
    end
  end
end
```

**END OF PHASE 2** - Critical business logic testing complete

## 📋 **Phase 3 Tasks (Weeks 9-12) - COMPREHENSIVE TESTING**

### **Week 9: Intelligence Integration Tests** 🧠

#### Task 9.1: Cross-Module Intelligence Tests
Test intelligence modules working together.

#### Task 9.2: LiveView Integration Tests
Test intelligence LiveView components.

### **Week 10: Performance Testing** 📈

#### Task 10.1: Database Performance Tests
Test database query performance under load.

#### Task 10.2: Intelligence Algorithm Performance
Test intelligence calculation performance.

### **Week 11: UI Testing** 💻

#### Task 11.1: LiveView Testing
Comprehensive LiveView testing with Phoenix.LiveViewTest.

#### Task 11.2: User Experience Testing
End-to-end user workflow testing.

### **Week 12: Quality Gates** 🚪

#### Task 12.1: Coverage Requirements
Ensure 70% test coverage on all critical paths.

#### Task 12.2: Quality Metrics
Implement comprehensive quality metrics.

## 📋 **Phase 4 Tasks (Weeks 13-16) - FINAL QUALITY**

### **Week 13-16: Final Quality Assurance**
- Achieve 70% test coverage
- Complete performance test suite
- Final quality gate implementation
- Documentation of testing procedures

## 🚨 **Emergency Procedures**

### **If Tests Are Failing**
1. **IMMEDIATELY** investigate and fix
2. **BLOCK** other team merges if critical tests fail
3. **COORDINATE** with team whose code caused the failure
4. **ESCALATE** if fix requires breaking changes

### **If Coverage Drops Below Threshold**
1. **IDENTIFY** which code lacks tests
2. **PRIORITIZE** critical business logic
3. **COORDINATE** with relevant team to add tests
4. **TRACK** progress toward coverage goals

### **If CI/CD Pipeline Breaks**
1. **FIX IMMEDIATELY** - all teams are blocked
2. **COMMUNICATE** status to all teams
3. **TEST** fix thoroughly before deploying
4. **DOCUMENT** the issue to prevent recurrence

## ✅ **Success Criteria**

By the end of 16 weeks, you must achieve:
- [ ] **70% test coverage** on all critical business logic
- [ ] **Zero skipped tests** due to infrastructure issues
- [ ] **All CI/CD pipelines** working reliably
- [ ] **Comprehensive test suites** for all intelligence modules
- [ ] **Performance benchmarks** for all critical operations
- [ ] **Quality gates** preventing regression
- [ ] **Documentation** of testing procedures and standards

Remember: **You are the quality guardian for the entire project. Nothing should merge without proper tests and quality validation.**