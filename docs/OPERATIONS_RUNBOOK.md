# EVE DMV Operations Runbook

*Simple operational guide for a small user base*

## Quick Reference

- **Health Check**: `curl https://yourdomain.com/health`
- **Logs**: `tail -f /var/log/eve_dmv.log` (or wherever logs are stored)
- **Restart App**: `systemctl restart eve_dmv` (or equivalent)
- **Check Memory**: Look for "High memory usage" in logs

## Common Issues & Solutions

### 1. Application Won't Start

**Symptoms**: Service fails to start, users can't access the site

**Check**:
1. Environment variables are set: `env | grep -E "(SECRET_KEY_BASE|DATABASE_URL|EVE_SSO)"`
2. Database is accessible: `pg_isready -h database_host`
3. Check logs for startup errors

**Fix**:
1. Set missing environment variables
2. Fix database connectivity
3. Check file permissions on release
4. Restart: `systemctl restart eve_dmv`

### 2. High Memory Usage

**Symptoms**: "High memory usage" warnings in logs

**Check**:
- Current memory: `free -h`
- App memory: Look for "Memory usage:" in logs

**Fix**:
1. Restart app if memory is very high (>2GB): `systemctl restart eve_dmv`
2. If persistent, investigate slow/large queries
3. Consider adding more RAM if needed

### 3. Slow Performance

**Symptoms**: "Slow request" or "Slow query" warnings in logs

**Check**:
- Recent slow queries: `grep "Slow query" /var/log/eve_dmv.log | tail -10`
- Recent slow requests: `grep "Slow request" /var/log/eve_dmv.log | tail -10`

**Fix**:
1. Check if it's a temporary issue (wait 10 minutes)
2. Restart app if performance doesn't improve
3. Check database query performance
4. Consider adding database indexes if specific queries are consistently slow

### 4. User Reports Error

**Symptoms**: User provides an error ID like "ERROR-abc123"

**Check**:
1. Search logs for the error ID: `grep "ERROR-abc123" /var/log/eve_dmv.log`
2. Look at the full error context and stacktrace

**Fix**:
1. If it's a temporary issue, advise user to retry
2. If it's a bug, note it for the next deployment
3. If it's a data issue, investigate and fix

### 5. Database Connection Issues

**Symptoms**: "database_unavailable" in health checks, connection errors in logs

**Check**:
1. Database is running: `systemctl status postgresql` (or equivalent)
2. Connection works: `pg_isready -h database_host`
3. Connection limits: Check PostgreSQL logs for "too many connections"

**Fix**:
1. Restart database if it's down
2. Restart app to reset connection pool
3. Check database configuration if connection limit hit

### 6. Rate Limiting Issues

**Symptoms**: Users getting "Too many requests" errors (HTTP 429)

**Check**:
- Rate limit warnings in logs: `grep "Rate limit exceeded" /var/log/eve_dmv.log`

**Fix**:
1. Usually temporary - ask user to wait 1 minute
2. If persistent, check for unusual traffic patterns
3. Consider adjusting rate limits if legitimate traffic

## Monitoring Checklist

### Daily (or when issues reported)
- [ ] Check health endpoint: `curl https://yourdomain.com/health`
- [ ] Look for errors in logs: `grep ERROR /var/log/eve_dmv.log | tail -20`
- [ ] Check for memory warnings: `grep "High memory" /var/log/eve_dmv.log | tail -5`

### Weekly
- [ ] Check slow queries: `grep "Slow query" /var/log/eve_dmv.log | tail -20`
- [ ] Review slow requests: `grep "Slow request" /var/log/eve_dmv.log | tail -20`
- [ ] Check disk space: `df -h`
- [ ] Verify backups are working

### Monthly
- [ ] Update dependencies: `mix deps.audit` (check for security issues)
- [ ] Review and clean up old logs
- [ ] Check for Phoenix/Elixir updates

## Log Analysis

### Important Log Patterns
- `ERROR-[id]` - User-facing errors with reference IDs
- `Slow query detected` - Database performance issues  
- `Slow request detected` - Application performance issues
- `High memory usage` - Memory pressure warnings
- `Rate limit exceeded` - Potential abuse or traffic spikes

### Useful Commands
```bash
# Recent errors
grep "ERROR-" /var/log/eve_dmv.log | tail -20

# Memory usage over time
grep "Memory usage:" /var/log/eve_dmv.log | tail -20

# Performance issues today
grep "$(date +%Y-%m-%d)" /var/log/eve_dmv.log | grep -E "(Slow query|Slow request)"

# Health check failures
grep "unhealthy" /var/log/eve_dmv.log | tail -10
```

## Deployment Process

### Standard Deployment
1. **Test locally**: `./scripts/deploy.sh` (this runs all checks)
2. **Stop old version**: `systemctl stop eve_dmv`
3. **Deploy new release**: Transfer and extract new release
4. **Run migrations**: `./bin/eve_dmv eval "EveDmv.Release.migrate()"`
5. **Start new version**: `systemctl start eve_dmv`
6. **Verify**: `curl https://yourdomain.com/health`

### Emergency Rollback
1. **Stop current version**: `systemctl stop eve_dmv`
2. **Restore previous release**: Switch to backup release
3. **Start**: `systemctl start eve_dmv`
4. **Verify**: Health check should work
5. **Note**: Database migrations might need manual rollback

### Hotfix Deployment
For urgent fixes:
1. **Make minimal change**
2. **Test change works**: Quick local test
3. **Deploy immediately**: Follow standard process
4. **Monitor closely**: Watch logs for 30 minutes

## Environment Variables

### Required for Production
```bash
SECRET_KEY_BASE=<64+ character secret>
DATABASE_URL=postgresql://user:pass@host/database
EVE_SSO_CLIENT_ID=<your eve sso client id>
EVE_SSO_CLIENT_SECRET=<your eve sso client secret>
PHX_HOST=<your domain name>
PHX_PORT=4010
```

### Optional but Recommended
```bash
PIPELINE_ENABLED=true
WANDERER_KILLS_SSE_URL=http://your-wanderer-host:4004/api/v1/kills/stream
```

## Contact & Escalation

### When to Escalate
- Health check fails for more than 5 minutes
- Multiple user reports of errors
- Memory usage above 4GB consistently
- Database connection failures

### Emergency Response
1. **Immediate**: Restart the application
2. **If restart doesn't help**: Check database status
3. **If database is fine**: Review recent logs for patterns
4. **If still broken**: Rollback to previous version
5. **Document**: What happened and what fixed it

## Performance Baselines

### Normal Performance
- Health check response: < 50ms
- Most requests: < 200ms
- Database queries: < 100ms (warnings logged for slower)
- Memory usage: 500MB - 1GB

### Warning Thresholds
- Health check response: > 500ms
- Requests: > 1000ms (logged as "Slow request")
- Database queries: > 100ms (logged as "Slow query")  
- Memory usage: > 1GB (logged as "High memory usage")

### Action Required
- Health check fails
- Memory usage > 2GB
- Multiple slow queries per minute
- Error rate > 1% of requests

---

**Remember**: This is for a small user base. Keep it simple, monitor the basics, and respond quickly to issues. Don't over-complicate unless you actually need more sophisticated monitoring.