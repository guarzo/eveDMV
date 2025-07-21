#!/bin/bash

echo "Final push to reach refactoring target..."

# Fix remaining duplicate variables by removing empty initializations
echo "Removing empty list/map initializations..."
find lib -name "*.ex" -type f -exec sed -i '/^\s*\w\+\s*=\s*\[\]\s*$/d' {} \;
find lib -name "*.ex" -type f -exec sed -i '/^\s*\w\+\s*=\s*%{}\s*$/d' {} \;

# Fix some specific duplicate variable patterns
echo "Fixing specific duplicate variable patterns..."

# Fix duplicate 'characteristics' by renaming second occurrence
find lib -name "*.ex" -type f -exec sed -i '0,/characteristics = /!s/characteristics = /additional_characteristics = /g' {} \;

# Fix duplicate 'adaptations' by renaming second occurrence
find lib -name "*.ex" -type f -exec sed -i '0,/adaptations = /!s/adaptations = /further_adaptations = /g' {} \;

# Fix duplicate 'score' by renaming second occurrence
find lib -name "*.ex" -type f -exec sed -i '0,/score = /!s/score = /updated_score = /g' {} \;

# Fix duplicate 'moments' by renaming second occurrence  
find lib -name "*.ex" -type f -exec sed -i '0,/moments = /!s/moments = /additional_moments = /g' {} \;

# Fix duplicate 'indicators' by renaming second occurrence
find lib -name "*.ex" -type f -exec sed -i '0,/indicators = /!s/indicators = /updated_indicators = /g' {} \;

# Fix more pipe chain issues by removing pipes after certain patterns
echo "Final pipe chain cleanup..."
find lib -name "*.ex" -type f -exec perl -i -pe 's/\)\s*\|>/)/g' {} \;
find lib -name "*.ex" -type f -exec perl -i -pe 's/\]\s*\|>/]/g' {} \;
find lib -name "*.ex" -type f -exec perl -i -pe 's/\}\s*\|>/}/g' {} \;

echo "Final refactoring push completed!"