#!/bin/bash
# Script to validate migration consistency

echo "=== Migration Validation Script ==="
echo "Testing migration up/down consistency..."

# Test 1: Full rollback and migrate
echo "Test 1: Full rollback and migrate"
mix ecto.rollback --all
if [ $? -eq 0 ]; then
  echo "✓ Rollback successful"
else
  echo "✗ Rollback failed"
  exit 1
fi

mix ecto.migrate
if [ $? -eq 0 ]; then
  echo "✓ Migrate successful"
else
  echo "✗ Migrate failed"
  exit 1
fi

# Test 2: Partial rollback
echo ""
echo "Test 2: Partial rollback (5 steps)"
mix ecto.rollback --step 5
if [ $? -eq 0 ]; then
  echo "✓ Partial rollback successful"
else
  echo "✗ Partial rollback failed"
  exit 1
fi

mix ecto.migrate
if [ $? -eq 0 ]; then
  echo "✓ Re-migrate successful"
else
  echo "✗ Re-migrate failed"
  exit 1
fi

echo ""
echo "=== All migration tests passed! ==="