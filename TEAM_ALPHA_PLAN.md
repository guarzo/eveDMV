# Team Alpha - Security & Infrastructure Implementation Plan

> **AI Assistant Instructions for Security & Infrastructure Team**
> 
> You are Team Alpha, responsible for critical security fixes and infrastructure improvements. Your work has **highest merge priority** as other teams depend on your security and OTP fixes.

## 🎯 **Your Mission**

Fix critical security vulnerabilities, implement proper OTP supervision, and establish secure infrastructure foundation for the entire application.

## ⚠️ **Critical Instructions**

### **Quality Requirements**
After **EVERY SINGLE TASK**, you must run:
```bash
mix format
mix credo --strict
mix dialyzer
git add -A && git commit -m "descriptive message"
```

### **No Stubs or Placeholders**
- **NEVER** create placeholder implementations
- **NEVER** use TODO comments in production code  
- **NEVER** return hardcoded data - implement real functionality
- If you can't implement something fully, split into smaller tasks

### **Merge Coordination**
- **You merge FIRST every Friday**
- Announce file modifications in team chat
- Check that no other team is modifying your files
- Your changes may break other teams - test thoroughly

## 📋 **Phase 1 Tasks (Weeks 1-4) - CRITICAL SECURITY**

### **Week 1: Remove Hard-coded Secrets** 🔥
**CRITICAL**: Complete these immediately - other teams are blocked

#### Task 1.1: Remove .env from Version Control
```bash
# Execute these commands:
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit -m "Remove .env from version control - security fix"
```

#### Task 1.2: Regenerate All Compromised Secrets
- [ ] Create new EVE SSO application and get new Client ID/Secret
- [ ] Generate new SECRET_KEY_BASE: `mix phx.gen.secret`
- [ ] Regenerate JANICE_API_KEY from dashboard
- [ ] Create `.env.example` template with placeholder values
- [ ] Document secret setup in README.md section

#### Task 1.3: Add Runtime Secret Validation
Edit `config/runtime.exs` to validate required secrets:
```elixir
# Add validation for required secrets
required_secrets = [
  "EVE_SSO_CLIENT_ID",
  "EVE_SSO_CLIENT_SECRET", 
  "SECRET_KEY_BASE"
]

for secret <- required_secrets do
  if is_nil(System.get_env(secret)) do
    raise "Missing required environment variable: #{secret}"
  end
end
```

**MERGE CHECKPOINT**: Commit and push. Other teams need this before proceeding.

### **Week 2: Fix OTP Process Supervision** ⚡

#### Task 2.1: Fix Unsupervised Process Spawning
**File**: `lib/eve_dmv/enrichment/re_enrichment_worker.ex`

Replace unsupervised `spawn/1` calls on lines 138 and 151:
```elixir
# OLD (DANGEROUS):
spawn(fn -> perform_price_update(state.config) end)

# NEW (SUPERVISED):
Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn -> 
  perform_price_update(state.config) 
end)
```

#### Task 2.2: Add Shutdown Timeouts to GenServers
Add `shutdown` configuration to these modules:

**PriceCache** (`lib/eve_dmv/market/price_cache.ex`):
```elixir
def child_spec(opts) do
  %{
    id: __MODULE__,
    start: {__MODULE__, :start_link, [opts]},
    shutdown: 10_000  # 10 seconds for ETS cleanup
  }
end
```

**MatchingEngine** (`lib/eve_dmv/surveillance/matching_engine.ex`):
```elixir
def child_spec(opts) do
  %{
    id: __MODULE__,
    start: {__MODULE__, :start_link, [opts]},
    shutdown: 15_000  # 15 seconds for batch processing
  }
end
```

#### Task 2.3: Improve SSE Connection Management
**File**: `lib/eve_dmv/intelligence/wanderer_sse.ex`

Replace `spawn_link/1` on line 165 with proper supervision:
```elixir
# Consider using DynamicSupervisor for connection processes
# Document the current approach and plan for improvement
```

### **Week 3: Security Headers & HTTPS** 🛡️

#### Task 3.1: Add Security Headers
**File**: `lib/eve_dmv_web/endpoint.ex`

Add comprehensive security headers:
```elixir
plug Plug.Static,
  # ... existing config ...
  headers: %{
    "strict-transport-security" => "max-age=31536000; includeSubDomains",
    "x-frame-options" => "DENY", 
    "x-content-type-options" => "nosniff",
    "x-xss-protection" => "1; mode=block",
    "referrer-policy" => "strict-origin-when-cross-origin"
  }
```

#### Task 3.2: Enable HTTPS Enforcement
**File**: `config/prod.exs`

Add HTTPS enforcement:
```elixir
config :eve_dmv, EveDmvWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  # ... rest of config
```

#### Task 3.3: Add Content Security Policy
Create new file `lib/eve_dmv_web/plugs/security_headers.ex`:
```elixir
defmodule EveDmvWeb.Plugs.SecurityHeaders do
  @behaviour Plug
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("content-security-policy", csp_header())
  end
  
  defp csp_header do
    """
    default-src 'self';
    script-src 'self' 'unsafe-inline';
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    connect-src 'self' wss: https:;
    """
  end
end
```

Add to router pipeline in `lib/eve_dmv_web/router.ex`.

### **Week 4: Authentication Security** 🔐

#### Task 4.1: Secure Token Storage
**File**: `lib/eve_dmv/users/user.ex`

Review OAuth token storage (lines 93-103). Add encryption for sensitive tokens:
```elixir
# Consider adding field-level encryption for access/refresh tokens
# Document current security model and any improvements needed
```

#### Task 4.2: Secure API Client Authentication
**File**: `lib/eve_dmv/market/janice_client.ex`

Review API key handling on line 214. Ensure no logging of sensitive data:
```elixir
# Audit all external API clients for credential exposure
# Add redaction for sensitive headers in logs
```

#### Task 4.3: Session Security Review
**File**: `lib/eve_dmv_web/endpoint.ex`

Review session configuration (lines 14-19) and enhance:
```elixir
@session_options [
  store: :cookie,
  key: "_eve_dmv_key",
  signing_salt: "...",
  same_site: "Lax",
  secure: true,  # Enable in production
  http_only: true,
  max_age: 24 * 60 * 60  # 24 hours
]
```

**END OF PHASE 1** - Other teams can now proceed safely

## 📋 **Phase 2 Tasks (Weeks 5-8) - ESI & AUTH IMPROVEMENTS**

### **Week 5: Fix ESI Client Issues** 🔌

#### Task 5.1: Fix Corporation Client
**File**: `lib/eve_dmv/eve/esi_corporation_client.ex`

Fix `get_corporation_members/2` (lines 43-51):
```elixir
def get_corporation_members(corporation_id, auth_token) do
  with {:ok, response} <- EsiRequestClient.authenticated_request(
         "GET",
         "/corporations/#{corporation_id}/members/",
         auth_token
       ) do
    # Process the actual response instead of always returning error
    {:ok, response.body}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

#### Task 5.2: Fix Market Client Issues
**File**: `lib/eve_dmv/eve/esi_market_client.ex`

Fix `get_market_orders/3` type spec and implementation (lines 22-41):
```elixir
@spec get_market_orders(integer(), String.t(), keyword()) :: 
  {:ok, list(map())} | {:error, term()}

def get_market_orders(region_id, order_type, opts \\ []) do
  # Implement actual success handling
  case EsiRequestClient.public_request("GET", "/markets/#{region_id}/orders/", opts) do
    {:ok, response} -> 
      {:ok, response.body}
    {:error, reason} -> 
      {:error, reason}
  end
end
```

#### Task 5.3: Fix Character Client Issues  
**File**: `lib/eve_dmv/eve/esi_character_client.ex`

Fix `get_character_employment_history/1` (lines 144-156):
```elixir
def get_character_employment_history(character_id) do
  case EsiRequestClient.public_request("GET", "/characters/#{character_id}/corporationhistory/") do
    {:ok, response} -> 
      parsed_history = parse_employment_history(response.body)
      {:ok, parsed_history}
    {:error, reason} -> 
      {:error, reason}
  end
end
```

Implement `fetch_all_character_assets/4` (lines 194-196):
```elixir
def fetch_all_character_assets(character_id, auth_token, page \\ 1, acc \\ []) do
  case authenticated_request("GET", "/characters/#{character_id}/assets/?page=#{page}", auth_token) do
    {:ok, %{body: assets, headers: headers}} ->
      new_acc = acc ++ assets
      
      if has_more_pages?(headers) do
        fetch_all_character_assets(character_id, auth_token, page + 1, new_acc)
      else
        {:ok, new_acc}
      end
      
    {:error, reason} ->
      {:error, reason}
  end
end
```

#### Task 5.4: Fix Request Client Security Issues
**File**: `lib/eve_dmv/eve/esi_request_client.ex`

Fix auth token security (lines 186-192):
```elixir
# Remove auth_token from opts before logging
defp log_request_details(method, url, opts) do
  safe_opts = Keyword.delete(opts, :auth_token)
  Logger.debug("ESI Request: #{method} #{url}", opts: safe_opts)
end
```

Fix status code handling (lines 127-134):
```elixir
defp handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}}) 
     when status_code in 200..299 do
  {:ok, %{body: decode_response(body), status_code: status_code}}
end
```

### **Week 6: Circuit Breaker Improvements** ⚡

#### Task 6.1: Fix Race Condition
**File**: `lib/eve_dmv/eve/circuit_breaker.ex`

Move state check inside GenServer (lines 58-85):
```elixir
def call(service, request_fn) do
  GenServer.call(__MODULE__, {:execute_request, service, request_fn})
end

def handle_call({:execute_request, service, request_fn}, _from, state) do
  case get_circuit_state(service, state) do
    :closed -> 
      execute_and_handle_result(service, request_fn, state)
    :open -> 
      {:reply, {:error, :circuit_open}, state}
    :half_open -> 
      execute_recovery_attempt(service, request_fn, state)
  end
end
```

#### Task 6.2: Improve Error Handling
**File**: `lib/eve_dmv/eve/esi_parsers.ex`

Fix unsafe date parsing (lines 249-258):
```elixir
defp parse_date(date_string) when is_binary(date_string) do
  case Date.from_iso8601(date_string) do
    {:ok, date} -> date
    {:error, _reason} -> 
      Logger.warning("Failed to parse date: #{date_string}")
      nil
  end
end
```

### **Week 7: Performance Optimization** 📈

#### Task 7.1: Optimize Power Calculation
**File**: `lib/eve_dmv/eve/reliability_config.ex`

Replace `math.pow` with integer exponentiation (lines 114-116):
```elixir
defp integer_pow(base, 0), do: 1
defp integer_pow(base, exponent) when exponent > 0 do
  base * integer_pow(base, exponent - 1)
end

# Replace :math.pow(base, exponent) with integer_pow(base, exponent)
```

#### Task 7.2: Add Request Monitoring
Create `lib/eve_dmv/telemetry/request_monitor.ex`:
```elixir
defmodule EveDmv.Telemetry.RequestMonitor do
  @moduledoc """
  Monitors ESI request performance and reliability
  """
  
  def track_request(service, duration, status) do
    :telemetry.execute(
      [:eve_dmv, :esi, :request], 
      %{duration: duration}, 
      %{service: service, status: status}
    )
  end
end
```

### **Week 8: Authentication Edge Cases** 🔐

#### Task 8.1: Implement Session Timeout
**File**: `lib/eve_dmv_web/auth_live.ex`

Add session timeout handling:
```elixir
def handle_info(:session_timeout, socket) do
  socket
  |> put_flash(:error, "Session expired. Please sign in again.")
  |> redirect(to: "/")
  |> noreply()
end
```

#### Task 8.2: Add Rate Limiting to Auth Endpoints
Create `lib/eve_dmv_web/plugs/rate_limiter.ex`:
```elixir
defmodule EveDmvWeb.Plugs.RateLimiter do
  @behaviour Plug
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    # Implement rate limiting for authentication endpoints
    # Use existing RateLimiter module from market
  end
end
```

**END OF PHASE 2** - Security foundation complete

## 📋 **Phase 3 Tasks (Weeks 9-12) - ADVANCED SECURITY**

### **Week 9: Security Monitoring** 📊

#### Task 9.1: Add Security Event Logging
Create `lib/eve_dmv/security/audit_logger.ex`:
```elixir
defmodule EveDmv.Security.AuditLogger do
  @moduledoc """
  Logs security-relevant events for monitoring
  """
  
  def log_auth_attempt(character_id, ip_address, success) do
    :telemetry.execute(
      [:eve_dmv, :security, :auth_attempt],
      %{count: 1},
      %{character_id: character_id, ip: ip_address, success: success}
    )
  end
end
```

#### Task 9.2: Implement Security Headers Validation
Add security header testing and validation.

### **Week 10: Advanced Authentication** 🔒

#### Task 10.1: Multi-factor Authentication Foundation
Plan and implement MFA foundation (if required).

#### Task 10.2: API Authentication
Implement API key authentication for internal endpoints.

### **Week 11: Infrastructure Hardening** 🛡️

#### Task 11.1: Database Security Review
Review database security configuration and access controls.

#### Task 11.2: Container Security
Review Docker configuration for security best practices.

### **Week 12: Security Testing** 🧪

#### Task 12.1: Security Test Suite
Create comprehensive security test suite.

#### Task 12.2: Penetration Testing
Conduct internal security audit.

## 📋 **Phase 4 Tasks (Weeks 13-16) - SECURITY AUDIT**

### **Week 13-16: Final Security Audit**
- Complete security vulnerability assessment
- Fix any remaining security issues
- Document security architecture
- Create security runbook

## 🚨 **Emergency Procedures**

### **If You Discover a Security Vulnerability**
1. **DO NOT** commit the vulnerable code
2. **IMMEDIATELY** notify the tech lead
3. **DOCUMENT** the vulnerability privately
4. **FIX** the issue with highest priority
5. **TEST** the fix thoroughly before committing

### **If Another Team Needs Your Files**
1. **COORDINATE** in team chat immediately
2. **FINISH** your current task quickly
3. **COMMIT** and push your changes
4. **COMMUNICATE** when the file is available

### **If You're Blocked**
1. **DOCUMENT** the blocker clearly
2. **NOTIFY** the team lead immediately
3. **WORK** on the next available task
4. **ESCALATE** if the blocker affects critical path

## ✅ **Success Criteria**

By the end of 16 weeks, you must achieve:
- [ ] **Zero hard-coded secrets** in the codebase
- [ ] **All OTP processes** properly supervised
- [ ] **Security headers** implemented and tested
- [ ] **HTTPS enforcement** in production
- [ ] **ESI clients** fully functional without stubs
- [ ] **Authentication system** hardened against common attacks
- [ ] **Security monitoring** and logging in place

Remember: **You are the security foundation for the entire project. Other teams depend on your work being solid and secure.**