#!/bin/bash

echo "Fixing common dialyzer issues in batch..."

# Fix invalid contract types in character_intelligence domain
echo "Fixing invalid contracts in combat_intelligence/domain/character_analyzer.ex..."
sed -i 's/@spec analyze(integer()) :: {:ok, map()} | {:error, atom()}/@spec analyze(integer()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/character_analyzer.ex

sed -i 's/@spec get_intelligence(integer()) :: {:ok, map()} | {:error, atom()}/@spec get_intelligence(integer()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/character_analyzer.ex

sed -i 's/@spec refresh_analysis(integer()) :: {:ok, map()} | {:error, atom()}/@spec refresh_analysis(integer()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/character_analyzer.ex

# Fix external_group_analyzer invalid contract  
echo "Fixing invalid contract in external_group_analyzer.ex..."
sed -i 's/@spec analyze(map()) :: {:ok, map()} | {:error, atom()}/@spec analyze(map()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/external_group_analyzer.ex

# Fix player_repository invalid contracts
echo "Fixing invalid contracts in player_repository.ex..."
sed -i 's/@spec get_weapon_preferences(integer()) :: {:ok, map()} | {:error, atom()}/@spec get_weapon_preferences(integer()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/player_profile/infrastructure/player_repository.ex

sed -i 's/@spec get_external_groups(integer()) :: {:ok, \[map()\]} | {:error, atom()}/@spec get_external_groups(integer()) :: {:ok, list()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/player_profile/infrastructure/player_repository.ex

sed -i 's/@spec get_gang_size_patterns(integer()) :: {:ok, map()} | {:error, atom()}/@spec get_gang_size_patterns(integer()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/player_profile/infrastructure/player_repository.ex

sed -i 's/@spec get_intelligence_summary(integer()) :: {:ok, map()} | {:error, atom()}/@spec get_intelligence_summary(integer()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/player_profile/infrastructure/player_repository.ex

# Fix corporation_analyzer invalid contracts
echo "Fixing invalid contracts in corporation_analyzer.ex..."
sed -i 's/@spec analyze_member_correlations(integer(), map()) :: {:ok, map()} | {:error, atom()}/@spec analyze_member_correlations(integer(), map()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/corporation_intelligence/domain/analyzers/corporation_analyzer.ex

sed -i 's/@spec analyze_coordination(integer(), map()) :: {:ok, map()} | {:error, atom()}/@spec analyze_coordination(integer(), map()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/corporation_intelligence/domain/analyzers/corporation_analyzer.ex

# Fix notification_service invalid contract
echo "Fixing invalid contract in notification_service.ex..."
sed -i 's/@spec store_notification_in_database(map()) :: :ok | {:error, atom()}/@spec store_notification_in_database(map()) :: {:ok, map()} | {:error, any()}/g' \
  /workspace/lib/eve_dmv/contexts/threat_surveillance/domain/notification_service.ex

echo "Batch fixes applied. Running compilation check..."
MIX_ENV=test mix compile 2>&1 | tail -5