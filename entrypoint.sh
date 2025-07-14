#!/bin/sh
set -e

echo "🗄️ Running database migrations..."

# Run database migrations
bin/eve_dmv eval "EveDmv.Release.migrate()"

echo "✅ Migrations completed successfully"

# Start the application
echo "🚀 Starting EVE DMV application..."
exec bin/eve_dmv start