#!/bin/bash

echo "Removing unused functions from Workstream B files..."

# Remove unused functions from battle_sharing_service.ex
file="/workspace/lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex"
echo "Processing $file..."

# Comment out the unused public function and its private helpers
sed -i '47,61s/^/  # /' "$file"  # generate_battle_report
sed -i '190,220s/^/  # /' "$file"  # generate_markdown_report
sed -i '222,238s/^/  # /' "$file"  # generate_json_report
sed -i '240,258s/^/  # /' "$file"  # generate_html_report
sed -i '279,309s/^/  # /' "$file"  # generate_text_report

# Comment out unused export function
sed -i '66,80s/^/  # /' "$file"  # export_battle_data

# Comment out private helper functions that are only used by the removed functions
sed -i '391,393s/^/  # /' "$file"  # report_title
sed -i '395,398s/^/  # /' "$file"  # format_for_web
sed -i '404,406s/^/  # /' "$file"  # prepare_export_data
sed -i '410,421s/^/  # /' "$file"  # export_to_csv
sed -i '423,436s/^/  # /' "$file"  # format_isk_value (overloaded versions)
sed -i '438,447s/^/  # /' "$file"  # format_for_zkillboard
sed -i '449,463s/^/  # /' "$file"  # analyze_ship_composition
sed -i '464,472s/^/  # /' "$file"  # count_ships_by_class
sed -i '474,568s/^/  # /' "$file"  # Various format helper functions
sed -i '569,703s/^/  # /' "$file"  # Format helper functions

echo "Checking compilation..."
mix compile

echo "Done!"