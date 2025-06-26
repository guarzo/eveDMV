# Authentication Edge Cases

## 1. Corporation Transfer Mid-Session

### Challenge
A character's corporation (and alliance) membership underpins ACL rules. If they transfer corps, a stale session could grant or deny access incorrectly.

### Design

**Short-lived Corp Cache:** Don't hard-embed `corp_id` in session indefinitely. Instead, cache the character's corp/alliance in ETS (or Cachex) with a TTL (e.g. 10 minutes).

**Per-Request Refresh:** On each page request (via a Plug), check the TTL. If expired, call ESI `/v4/characters/{id}/` to get the latest `corporation_id` and `alliance_id`, update the cache and session context.

**Corp History:** For historical ACL (20 → 50 kills thresholds), also call `/v4/characters/{id}/corporationhistory` once per session to know prior corps.

### Failure & UX

If the ESI call fails, fall back to the cached corp/alliance.

If you detect a change:
1. Invalidate any corp-scoped caches (e.g. participant indexes)
2. In LiveViews, push a banner:
   > **Info:** Your corporation has changed to NewCorpName. Refreshing context…
3. Refresh the page context automatically

## 2. API Key Revocation & Expiration

### Challenge
EVE SSO tokens expire (and users can revoke them), so we must detect and recover from 401/403 errors.

### Design

**OAuth2 Refresh:** Store both `access_token` and `refresh_token`. Use a background task (or per-request hook) to refresh when `access_token.expires_at` is within 5 minutes.

**Error Interceptor:** Wrap all ESI/Janice/Mutamarket HTTP calls in a middleware that catches 401/403:

1. Attempt an immediate token refresh
2. If refresh succeeds, retry the original request once
3. If it still fails (or refresh fails), clear session and redirect to `/auth/eve` with a flash:
   > **Session expired or access revoked. Please log in again to continue.**

### UX

If an action (e.g. saving a filter) is in-flight when the token expires, persist the intended action in the session, redirect to login, then reapply it on return.

Show a persistent banner at top of pages once the token is within "refresh window":
> **Notice:** Your session will expire in X minutes—please save work or re-login.

## 3. Characters with Multiple Roles

### A. Multiple Linked Characters per User

**Design:**

**Join Table:** `users_characters` lets any user link many EVE `character_ids`.

**UI:** In the top-bar, display a dropdown listing each linked character (portrait + name + corp).

**Context Switch:** Selecting a character updates `:current_character` in the session, reloading LiveViews under that character's ACL and data.

**Persistence:** Save last-used `character_id` in `users.preferences` so returning users resume where they left off.

### B. Single Character with Multiple Corporate Roles

**Design:**

**Role Fetch:** On login and every 30 minutes (TTL cache), call ESI (with scope `esi-corporations.read_corporation_roles.v1`) to get a list of the character's roles in their current corp.

**Role Mapping:** Map CCP roles to app roles, e.g.:
- `CEO` → Full admin
- `Director` → Same as CEO  
- `Recruiter` → Cannot create "Fleet Optimizer" profiles
- `Tactician` → Full filter management

**ACL Resolution:** Always grant the union of all permissions; if any role allows an action, the character may perform it.

### UX

In Profile → Roles, list each corp role with an icon.

When roles change on the next refresh (or at login), push a LiveView banner:
> **Your corporate roles have been updated. Check your new permissions in Profile → Roles.**

---

With these approaches, we ensure that corp transfers, token lifecycle events, and multi-role scenarios are handled seamlessly—both behind the scenes and in the user interface.