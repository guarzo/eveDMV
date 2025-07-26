# Multi-Character Support Implementation

## Overview
Multi-character support has been successfully implemented, allowing users to manage multiple EVE Online characters under a single account.

## What Was Implemented

### 1. Database Schema
- **accounts table**: New table to group multiple characters
  - `id` - UUID primary key
  - `primary_character_id` - UUID reference to the primary character
  - `account_name` - Optional name for the account
  - `last_login_at` - Track last login time
  - `last_character_switch_at` - Track character switching
  - `is_admin` - Account-level admin privileges
  - Timestamps (created_at, updated_at)

- **users table updates**: Added `account_id` foreign key to link users to accounts

### 2. Resources & Models
- **Account Resource** (`lib/eve_dmv/users/account.ex`)
  - Full Ash resource implementation with actions, relationships, and policies
  - Actions: create, update, destroy, add_character, switch_primary_character
  - Relationships: has_many characters, belongs_to primary_character
  - Calculations: character_count, has_multiple_characters
  
- **User Resource Updates** (`lib/eve_dmv/users/user.ex`)
  - Added account_id attribute and belongs_to account relationship

### 3. Service Layer
- **AccountManager** (`lib/eve_dmv/users/account_manager.ex`)
  - `ensure_user_account/1` - Creates account for new users
  - `create_account_for_user/1` - Creates account with user as primary
  - `link_character_to_account/2` - Links additional characters
  - `switch_character/3` - Switches active character
  - `get_account_characters/1` - Lists all characters in account
  - `merge_accounts/2` - Merges multiple accounts
  - `update_account_activity/1` - Updates last login timestamp

### 4. Authentication Integration
- **AuthController** (`lib/eve_dmv_web/controllers/auth_controller.ex`)
  - Automatically creates/finds account on successful authentication
  - Stores both user_id and account_id in session
  - Updates account activity on login

- **AuthLive** (`lib/eve_dmv_web/live/auth_live.ex`)
  - Enhanced session loading to include account information
  - Loads both current_user and current_account from session

### 5. UI Components
- **CharacterSwitcher Component** (`lib/eve_dmv_web/components/character_switcher.ex`)
  - Dropdown component showing all account characters
  - Visual indicators for active and primary characters
  - Links to add new characters and account settings
  - Shows character count and maximum limit

- **CharacterSwitcherLive** (`lib/eve_dmv_web/live/character_switcher_live.ex`)
  - Full LiveView implementation for character switching
  - Modal for linking new characters
  - Real-time character switching without page reload
  - Account statistics display

- **Application Layout** (`lib/eve_dmv_web/components/layouts/app.html.heex`)
  - Integrated character switcher in header
  - Fallback to simple dropdown if no account info
  - Responsive design for mobile

### 6. Controllers & Routes
- **CharacterSwitchController** (`lib/eve_dmv_web/controllers/character_switch_controller.ex`)
  - `/auth/switch/:character_id` - Switch to different character
  - `/auth/set_primary/:character_id` - Set primary character
  - Audit logging for character switches
  - Session updates on character change

- **Router Updates** (`lib/eve_dmv_web/router.ex`)
  - Added character switching routes under /auth scope
  - Protected with authentication requirements

### 7. Security & Audit
- **Audit Logging**
  - Character switch events logged with timestamp and IP
  - Integration with existing audit logger
  - Telemetry events for monitoring

## Usage

### For Users
1. **First Login**: Account is automatically created with first character as primary
2. **Add Characters**: Click "Add Another Character" in character switcher dropdown
3. **Switch Characters**: Click on any character in the dropdown to switch
4. **Set Primary**: Available in account settings (redirects to profile page)

### For Developers
```elixir
# Ensure user has account
{:ok, account} = AccountManager.ensure_user_account(user)

# Get all characters
characters = AccountManager.get_account_characters(account.id)

# Switch character
{:ok, account, character} = AccountManager.switch_character(account.id, character_id)

# Link new character
{:ok, account, linked_user} = AccountManager.link_character_to_account(new_user, account.id)
```

## Configuration
- Maximum characters per account: Configurable via `:max_characters_per_account` (default: 10)
- Session stores both `current_user_id` and `current_account_id`

## Migration
```bash
mix ecto.migrate  # Run the accounts table migration
```

## Testing
Basic functionality can be tested with the provided test scripts:
- `test_multi_character.exs` - Comprehensive multi-character tests
- `test_accounts_basic.exs` - Basic account creation test

## Future Enhancements
- Account-level preferences and settings
- Character comparison tools
- Cross-character analytics
- Account activity history
- Character roles/permissions within account