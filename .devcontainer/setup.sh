#!/bin/bash

# EVE DMV Development Container Setup Script
# This script runs after the container is created to set up the development environment

set -e

echo "🚀 Starting EVE DMV development environment setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Wait for database to be ready
print_status "Waiting for PostgreSQL to be ready..."
until pg_isready -h db -p 5432 -U postgres; do
    echo "Waiting for postgres..."
    sleep 2
done
print_success "PostgreSQL is ready!"

# Install dependencies
print_status "Installing Elixir dependencies..."
mix deps.get

# Set up database
print_status "Setting up database..."
mix ecto.create --quiet || true

# Run migrations
print_status "Running database migrations..."
if mix ecto.migrate; then
    print_success "Database migrations completed successfully"
else
    print_warning "Some migrations may have failed - this might be expected in development"
fi

# Check if pg_cron is working
print_status "Verifying pg_cron functionality..."
if psql $DATABASE_URL -c "SELECT check_pg_cron_status();" >/dev/null 2>&1; then
    print_success "pg_cron extension is available and working!"
    
    # Show active cron jobs
    print_status "Active pg_cron jobs:"
    psql $DATABASE_URL -c "SELECT jobname, schedule, active FROM cron.job WHERE active = true;" || true
else
    print_warning "pg_cron may not be fully initialized yet - this is normal on first startup"
fi

# Set up assets
print_status "Setting up frontend assets..."
if [ -f "assets/package.json" ]; then
    cd assets && npm install && cd ..
    mix assets.setup || true
else
    print_warning "No assets/package.json found - skipping asset setup"
fi

# Create useful aliases
print_status "Setting up development aliases..."
cat >> ~/.bashrc << 'EOF'

# EVE DMV Development Aliases
alias ll='ls -la'
alias psg='ps aux | grep'
alias serve='mix phx.server'
alias iexserve='iex -S mix phx.server'
alias dbconsole='psql $DATABASE_URL'
alias logs='docker-compose logs -f'
alias restart='docker-compose restart'
alias migrate='mix ecto.migrate'
alias rollback='mix ecto.rollback'
alias seed='mix run priv/repo/seeds.exs'
alias test_db='MIX_ENV=test mix ecto.setup'
alias check_partitions='mix eve.partition_manager status'
alias create_partitions='mix eve.partition_manager create_future'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# Quality checks
alias quality='./scripts/quality_check.sh'
alias format='mix format'
alias credo='mix credo --strict'

echo "🎯 EVE DMV development environment ready!"
echo "💡 Useful commands:"
echo "   serve         - Start Phoenix server"
echo "   iexserve      - Start Phoenix with IEx console"
echo "   dbconsole     - Connect to PostgreSQL"
echo "   quality       - Run quality checks"
echo "   check_partitions - Show partition status"
EOF

# Make the script executable and load aliases
chmod +x ~/.bashrc

# Final setup verification
print_status "Running final verification..."

# Check if we can connect to the database
if psql $DATABASE_URL -c "SELECT version();" >/dev/null 2>&1; then
    print_success "Database connection successful"
else
    print_error "Database connection failed"
fi

# Check if Elixir is working
if mix --version >/dev/null 2>&1; then
    print_success "Elixir environment ready"
else
    print_error "Elixir environment setup failed"
fi

print_success "🎉 EVE DMV development environment setup complete!"
print_status "To get started:"
print_status "  1. Run 'serve' or 'mix phx.server' to start the Phoenix server"
print_status "  2. Visit http://localhost:4010 to see the application"
print_status "  3. Run 'check_partitions' to verify pg_cron partition management"
print_status "  4. Use 'quality' to run code quality checks"

echo ""
echo "Happy coding! 🚀"