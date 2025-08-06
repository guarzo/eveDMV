#!/bin/bash
# Fix Api.update! calls to use Api.update instead

echo "Fixing Api.update! calls..."

# Fix all Api.update! calls
find /workspace/lib -name "*.ex" -type f -exec sed -i 's/Api\.update!/Api.update/g' {} \;

# Fix all Ash.update! calls with domain: Api
find /workspace/lib -name "*.ex" -type f -exec sed -i 's/Ash\.update!(\([^,]*\), \([^,]*\), domain: Api)/Api.update(\1, \2)/g' {} \;

# Fix all Ash.create! calls with domain: Api to use Api.create
find /workspace/lib -name "*.ex" -type f -exec sed -i 's/Ash\.create!(\([^,]*\), \([^,]*\), domain: Api)/Api.create(\1, \2)/g' {} \;

# Fix all Ash.read! calls with domain: Api to use Api.read!
find /workspace/lib -name "*.ex" -type f -exec sed -i 's/Ash\.read!(\([^,]*\), domain: Api)/Api.read!(\1)/g' {} \;

echo "Api update! fixes complete!"