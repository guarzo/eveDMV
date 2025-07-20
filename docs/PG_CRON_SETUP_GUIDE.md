# pg_cron Setup Guide for EVE DMV

This guide covers setting up pg_cron for automated partition management in different environments.

## Overview

EVE DMV uses PostgreSQL table partitioning for performance and pg_cron for automated partition management. The system works in three modes:

1. **Full Automation** (with pg_cron) - Recommended for production
2. **Manual Management** (without pg_cron) - Works for CI/testing
3. **Development Environment** (Docker with pg_cron) - Automatically configured

## 🐳 Development Environment (Docker/DevContainer)

### Quick Start with DevContainer
```bash
# Open in VS Code with DevContainer extension
# or use GitHub Codespaces

# The devcontainer automatically:
# ✅ Installs PostgreSQL with pg_cron
# ✅ Runs migrations with partition setup
# ✅ Configures automated jobs

# Verify it's working:
mix eve.partition_manager status
```

### Manual Docker Setup
```bash
# Start the development environment
docker-compose up -d

# Run migrations to set up partitioning
mix ecto.migrate

# Verify pg_cron is working
mix eve.partition_manager status
```

The Docker setup includes:
- Custom PostgreSQL image with pg_cron extension
- Automated partition creation (monthly)
- Automated cleanup (quarterly, 12-month retention)
- Development tools and aliases

## 🚀 Production Environment

### Prerequisites
- PostgreSQL 12+ (recommended: 15+)
- Superuser access to install extensions
- pg_cron extension available

### Installation Steps

#### 1. Install pg_cron Extension
```sql
-- Connect as PostgreSQL superuser
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Verify installation
SELECT * FROM pg_extension WHERE extname = 'pg_cron';
```

#### 2. Configure PostgreSQL
Add to `postgresql.conf`:
```ini
# Required for pg_cron
shared_preload_libraries = 'pg_cron'

# Set the database where pg_cron metadata is stored
cron.database_name = 'your_production_db_name'

# Optional: customize timezone
cron.timezone = 'UTC'
```

Restart PostgreSQL after configuration changes.

#### 3. Deploy Application
```bash
# Run migrations (includes partition setup)
mix ecto.migrate

# Verify automated jobs are scheduled
psql $DATABASE_URL -c "SELECT jobname, schedule, active FROM cron.job;"

# Check partition status
mix eve.partition_manager status
```

### Production Monitoring
```bash
# Monitor cron job execution
psql $DATABASE_URL -c "SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;"

# Check partition health
mix eve.partition_manager stats

# Manual operations if needed
mix eve.partition_manager create_future    # Create next 3 months
mix eve.partition_manager cleanup          # Clean old partitions
```

## 🧪 CI/Testing Environment (without pg_cron)

The application gracefully handles environments without pg_cron:

### What Happens
- Migration runs successfully (pg_cron creation is optional)
- Partition functions are created but no cron jobs scheduled
- Manual partition management remains available
- All core application functionality works normally

### Setup
```bash
# Standard database setup
mix ecto.create
mix ecto.migrate

# Manual partition management
mix eve.partition_manager create_future

# In CI scripts, you might want to create partitions for test data
mix eve.partition_manager create $(date +%Y-%m)
```

## 🛠️ Manual Partition Management

Available in all environments via Mix tasks:

### Common Commands
```bash
# Show current status
mix eve.partition_manager status

# Create partitions for next 3 months
mix eve.partition_manager create_future

# Create partition for specific month
mix eve.partition_manager create 2024-12

# Clean up old partitions (default: 12 months retention)
mix eve.partition_manager cleanup

# Custom retention period
mix eve.partition_manager cleanup --months=6

# Show detailed statistics
mix eve.partition_manager stats
```

### Programmatic Access
```elixir
# In your application code
alias EveDmv.Database.PartitionAutomation

# Create partitions
{:ok, messages} = PartitionAutomation.ensure_future_partitions(3)

# Clean up old partitions
{:ok, {count, dropped}} = PartitionAutomation.cleanup_old_partitions(12)

# Get statistics
{:ok, stats} = PartitionAutomation.get_partition_stats()
```

## 🔧 Troubleshooting

### Common Issues

#### 1. pg_cron Extension Not Available
```
ERROR: extension "pg_cron" is not available
```
**Solution**: 
- In development: Use the provided Docker setup
- In production: Install pg_cron extension package
- In CI: Migrations will skip pg_cron setup automatically

#### 2. Permission Denied for pg_cron
```
ERROR: permission denied to create extension "pg_cron"
```
**Solution**: Run as PostgreSQL superuser or have DBA install the extension

#### 3. Cron Jobs Not Running
```sql
-- Check if jobs are scheduled
SELECT * FROM cron.job WHERE active = true;

-- Check job execution history
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- Verify database setting
SHOW cron.database_name;
```

#### 4. Partitions Not Created
**Debug Steps**:
```bash
# Check if partitions exist
mix eve.partition_manager status

# Manually create partitions
mix eve.partition_manager create_future

# Check logs for errors
docker-compose logs db
```

### Getting Help

1. **Check logs**: Application and PostgreSQL logs often contain helpful details
2. **Verify setup**: Use `mix eve.partition_manager status` to check configuration
3. **Manual fallback**: All operations can be performed manually via Mix tasks
4. **Test environment**: pg_cron is not required - automation is optional

## 📋 Environment-Specific Notes

### Development (Docker)
- ✅ Fully automated setup
- ✅ pg_cron extension included
- ✅ Jobs scheduled automatically
- 🔧 Use setup script for easy development

### Staging/Production
- 📋 Requires pg_cron installation
- 📋 Database configuration changes needed
- 📋 Superuser privileges required for setup
- 📊 Monitor job execution and partition health

### CI/Testing
- ⚠️ pg_cron not required
- ✅ Core functionality unaffected
- 🔧 Manual partition creation in test scripts
- 🧪 All tests pass without pg_cron

## 🎯 Best Practices

1. **Monitor Partition Health**: Regularly check partition status and job execution
2. **Backup Strategy**: Ensure backup system handles partitioned tables correctly
3. **Retention Policy**: Adjust cleanup schedule based on data retention requirements
4. **Performance Testing**: Test query performance across partition boundaries
5. **Disaster Recovery**: Document partition restoration procedures

## 📚 Additional Resources

- [PostgreSQL Partitioning Documentation](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [pg_cron GitHub Repository](https://github.com/citusdata/pg_cron)
- [EVE DMV Architecture Documentation](/workspace/ARCHITECTURE.md)
- [Mix Task Documentation](/workspace/lib/mix/tasks/eve.partition_manager.ex)