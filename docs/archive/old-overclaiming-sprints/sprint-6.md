# Sprint 6: Chain Analytics & Enhanced Intelligence (Revised)

## Sprint Overview
- **Sprint Number**: 6
- **Duration**: 2 weeks (Weeks 11-12)
- **Theme**: Chain analytics, Discord notifications, and mapper API
- **Goal**: Provide deep chain analysis without recreating map topology

## Key Assumptions (Revised)
1. **No Map Topology Recreation** - The mapper already handles visual topology; we focus on analytics
2. **Use Existing SSE Feed** - wanderer-kills SSE already provides enriched killmail data
3. **Analytics over Visualization** - Provide insights and analysis about chain activity
4. **API for Mapper Integration** - Expose our analytics for mapper consumption

## User Stories

### Story 1: Chain Activity Analytics Engine (8 pts)
**As a** WH Fleet Commander  
**I want** comprehensive chain activity analysis  
**So that** I can understand threats and patterns without leaving my mapper

**Acceptance Criteria:**
- [ ] Activity heat maps by system over time
- [ ] Threat scoring based on kill patterns
- [ ] Corporation/Alliance presence tracking
- [ ] Ship class distribution analysis
- [ ] Time-based activity patterns (hourly/daily)
- [ ] Chain-wide threat summary dashboard

**Technical Tasks:**
- [ ] Create ChainAnalyticsService
- [ ] Build activity aggregation queries
- [ ] Implement threat scoring algorithm
- [ ] Create time-series data models
- [ ] Build analytics caching layer
- [ ] Add real-time updates from SSE feed

### Story 2: Discord Notification System (5 pts)
**As a** WH Corporation Member  
**I want** intelligent Discord notifications  
**So that** I'm alerted to important chain events

**Acceptance Criteria:**
- [ ] Configurable alert rules (by system, entity, ship type)
- [ ] Smart notification grouping (prevent spam)
- [ ] Rich embeds with tactical information
- [ ] @mention support for critical alerts
- [ ] Per-channel configuration
- [ ] Alert history and acknowledgment

**Technical Tasks:**
- [ ] Create DiscordWebhook resource
- [ ] Build NotificationRule system
- [ ] Implement smart batching/grouping
- [ ] Create Discord embed formatter
- [ ] Add rate limiting and cooldowns
- [ ] Build notification configuration UI

### Story 3: Mapper Integration API (4 pts)
**As a** Mapper Developer  
**I want** REST API for chain analytics  
**So that** I can enhance my mapper with EVE DMV intelligence

**Acceptance Criteria:**
- [ ] RESTful API endpoints for chain analytics
- [ ] SSE endpoint for real-time updates
- [ ] API key authentication
- [ ] Standardized response formats
- [ ] Rate limiting per API key
- [ ] OpenAPI documentation

**Technical Tasks:**
- [ ] Create Phoenix API pipeline
- [ ] Implement API key authentication
- [ ] Build analytics endpoints
- [ ] Add SSE streaming endpoint
- [ ] Create OpenAPI spec
- [ ] Add rate limiting

### Story 4: Enhanced SSE Feed Processing (4 pts)
**As a** System Administrator  
**I want** robust SSE feed handling  
**So that** we never miss critical intelligence

**Acceptance Criteria:**
- [ ] Automatic reconnection with backoff
- [ ] Message deduplication
- [ ] Failed message retry queue
- [ ] Health monitoring and alerting
- [ ] Performance metrics tracking
- [ ] Configurable processing rules

**Technical Tasks:**
- [ ] Enhance SSE producer resilience
- [ ] Add message deduplication
- [ ] Implement retry queue with DLQ
- [ ] Create health check endpoints
- [ ] Add Prometheus metrics
- [ ] Build processing rule engine

## Technical Architecture

### Analytics Pipeline
```
wanderer-kills SSE → Broadway Pipeline → Analytics Engine → Cache Layer
                                      ↓
                          Notification Engine → Discord
                                      ↓
                              API Endpoints ← Mapper
```

### Data Flow
1. SSE feed provides enriched killmail data
2. Analytics engine processes in real-time
3. Results cached for API performance
4. Notifications triggered by rules engine
5. Mapper polls API or subscribes to SSE stream

### Key Components
- **ChainAnalyticsService** - Core analytics logic
- **NotificationEngine** - Rule-based alert system
- **MapperAPIController** - RESTful endpoints
- **AnalyticsCache** - Redis-backed cache layer

## Success Metrics
- Analytics queries complete in <100ms
- 99.9% SSE feed uptime
- <1s notification delivery time
- API response time <50ms (cached)
- Zero duplicate notifications

## Dependencies
- Existing wanderer-kills SSE feed
- Discord webhook API
- Redis for caching (new)
- Existing Broadway pipeline

## Definition of Done
- [ ] All acceptance criteria met
- [ ] Unit tests >90% coverage
- [ ] API documentation complete
- [ ] Performance benchmarks passed
- [ ] Integration tests passing
- [ ] Manual QA completed
- [ ] Production deployment ready