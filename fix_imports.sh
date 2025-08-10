#!/bin/bash
echo "Updating import paths from EveDmv.Utils.* to EveDmv.Core.Utils.*"

# Update all Utils references to Core.Utils
find lib/ -name "*.ex" -exec sed -i 's/EveDmv\.Utils\./EveDmv.Core.Utils./g' {} \;

# Also update alias statements
find lib/ -name "*.ex" -exec sed -i 's/alias EveDmv\.Utils\./alias EveDmv.Core.Utils./g' {} \;

# Update import statements
find lib/ -name "*.ex" -exec sed -i 's/import EveDmv\.Utils\./import EveDmv.Core.Utils./g' {} \;

# Update in test files too
find test/ -name "*.exs" -exec sed -i 's/EveDmv\.Utils\./EveDmv.Core.Utils./g' {} \;
find test/ -name "*.exs" -exec sed -i 's/alias EveDmv\.Utils\./alias EveDmv.Core.Utils./g' {} \;
find test/ -name "*.exs" -exec sed -i 's/import EveDmv\.Utils\./import EveDmv.Core.Utils./g' {} \;

echo "Import path updates complete"

# Count remaining references
echo "Checking for any remaining EveDmv.Utils references:"
grep -r "EveDmv\.Utils\." lib/ test/ --include="*.ex" --include="*.exs" | wc -l