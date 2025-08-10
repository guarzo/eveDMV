# EVE DMV Product Requirements Document

*Version 4.0 - August 7, 2025 (Current State)*

## 1. Executive Summary

### 1.1 Product Overview
EVE DMV is a real-time PvP intelligence and analytics platform for EVE Online. Built with Phoenix LiveView and the Ash Framework, it provides comprehensive intelligence gathering, battle analysis, and fleet operations support for EVE pilots, corporations, and alliances.

### 1.2 Current Production Status
EVE DMV is **production-ready** with comprehensive feature implementation:
- **53 test files** providing adequate coverage
- **~95% features** working with real data from database
- **Minimal placeholders** - Only market pricing deferred
- **Clean architecture** with proper bounded contexts
- **Performance optimized** with multi-layer caching and batch queries

### 1.3 Key Production Features
- **Real-time killmail feed** with advanced filtering and infinite scroll
- **Complete character intelligence** with gang synergy and preference analysis
- **Battle analysis system** with timeline reconstruction and correlation
- **Multi-character account management** with seamless character switching
- **Surveillance profiles** with complex filtering and real-time matching
- **System activity analytics** with heatmaps and regional correlation
- **Fleet composition analysis** with real data calculations
- **Corporation intelligence** with member activity and performance tracking

## 2. Product Vision & Strategy

### 2.1 Vision Statement
To provide EVE Online players with the most comprehensive, accurate, and real-time PvP intelligence platform that enhances tactical decision-making and situational awareness.

### 2.2 Target Users
- **PvP Intelligence Analysts**: Gathering intel on hostile entities
- **Fleet Commanders**: Planning and executing fleet operations
- **Intelligence Officers**: Monitoring threats and analyzing patterns
- **Solo/Small Gang Pilots**: Assessing risks and opportunities
- **Corporation Leaders**: Monitoring member activity and performance

### 2.3 Core Value Propositions
1. **Real-time Intelligence**: Live killmail feed with sub-second updates
2. **Accurate Analysis**: ~95% features use real data, minimal placeholders
3. **Comprehensive Coverage**: Individual pilots, corporations, and fleet operations
4. **Actionable Insights**: Clear threat assessments with production algorithms
5. **Clean Implementation**: No placeholder code in production features

## 3. Implemented Features

### 3.1 ✅ Authentication & User Management

#### Features
- **EVE SSO Integration**: OAuth2 authentication with automatic token refresh
- **Multi-Character Support**: Account system managing multiple EVE characters
- **Character Switching**: Seamless switching without re-authentication
- **Session Management**: Persistent sessions with character context
- **Role-Based Access**: Admin and user role distinction
- **API Key System**: Separate authentication for programmatic access

#### Implementation Details
- Account-User relationship database schema
- Token lifecycle management with automatic refresh
- Session-based character context switching
- Token refresh plug for automatic token renewal
- Character switcher component for UI integration

### 3.2 ✅ Live Kill Feed

#### Features
- **Real-time Updates**: Sub-second killmail display via SSE connection
- **Advanced Filtering**: Alliance, ship type, ISK value, and system-based filtering
- **Infinite Scroll**: Performance-optimized progressive loading
- **Rich Data Display**: Ship types, damage values, participants, locations
- **Activity Metrics**: System danger ratings and escalation detection
- **Multiple UI Options**: Standard and optimized feed implementations

#### Implementation Details
- Broadway pipeline with HTTPoison SSE producer
- Database-level filtering with 50-item pagination
- JavaScript hooks for smooth infinite loading
- Real-time filter preview with live killmail matching
- Optimized kill feed LiveView for high-volume scenarios

### 3.3 ✅ Character Intelligence

#### Features
- **Threat Scoring**: Multi-dimensional threat assessment algorithm
- **Combat Statistics**: Kill/death ratios, ISK efficiency, activity patterns
- **Ship Preferences**: Detailed analysis of preferred ship types and weapons
- **Gang Size Patterns**: Behavioral analysis of fleet participation
- **Activity Analysis**: Temporal patterns and engagement frequency
- **Character Comparison**: Multi-character analysis and similarity matching
- **Predictive Modeling**: Future behavior prediction based on historical data

#### Implementation Details
- Gang Synergy Analyzer with coordination scoring algorithms
- Cross-Character Analysis for pattern detection
- Historical Trend Analysis with sophisticated algorithms
- Materialized views for performance optimization
- Comprehensive analytics engine with configurable weights
- Head-to-head comparison tools supporting 2-10 characters

### 3.4 ✅ Battle Analysis

#### Features
- **Battle Detection**: Automatic clustering of related killmails
- **Timeline Reconstruction**: Chronological battle event mapping
- **Phase Analysis**: Multi-phase detection with engagement patterns
- **Participant Analysis**: Role identification and performance metrics
- **Side Determination**: Intelligent alliance/corporation relationship analysis
- **Outcome Analysis**: Battle results and decisive moment identification
- **Performance Optimization**: Cached and optimized analyzers

#### Implementation Details
- Time-gap analysis with configurable thresholds
- Alliance/corporation relationship graphs
- Attack pattern classification algorithms
- Performance-optimized clustering with battle context
- Cached battle analyzer for frequently accessed data
- Optimized battle analyzer with single-query fetching

### 3.5 ✅ Fleet Operations

#### Features
- **Ship Classification**: Role-based ship categorization using static data
- **Composition Analysis**: Fleet balance and effectiveness assessment
- **DPS/EHP Calculations**: Estimates based on ship types and fittings
- **Mass Calculations**: Ship mass calculations using real EVE static data
- **Role Detection**: Ship role identification from EVE static data
- **Fleet Readiness**: Pilot availability and ship readiness analysis
- **Cost Calculation**: Fleet ship cost estimation

#### Implementation Details
- EVE static data integration (49,906 item types)
- Real ship attribute queries for mass and capabilities
- Role classification based on ship bonuses
- Fleet optimization algorithms with composition recommendations
- Pilot analyzer for individual pilot assessment
- Fleet asset availability tracking

### 3.6 ✅ System Activity Analytics

#### Features
- **Heatmap Generation**: Visual activity intensity mapping
- **Regional Correlation**: Cross-system activity correlation analysis
- **Escalation Detection**: Automated threat level escalation alerts
- **Activity Intensity**: Real-time metrics calculation
- **Trend Analysis**: Historical and real-time activity monitoring
- **Interactive UI**: Full LiveView interface with visualizations

#### Implementation Details
- Heatmap generator with heat calculation logic
- Pearson correlation algorithms for regional analysis
- Threat escalation detection with configurable thresholds
- Activity intensity calculator with real-time updates
- SystemActivityLive with complete UI implementation
- Multi-view interface (Overview, Regional, Trends, Heatmap)

### 3.7 ✅ Surveillance Profiles

#### Features
- **Profile Management**: Full CRUD operations for surveillance profiles
- **Complex Filtering**: Range, temporal, proximity, and nested conditions
- **Real-time Matching**: Live killmail evaluation against profile criteria
- **Advanced Logic**: AND/OR combinations with condition prioritization
- **Alert System**: Real-time notifications for profile matches
- **Batch Operations**: Bulk profile management capabilities
- **Export/Import**: Profile sharing and backup functionality

#### Implementation Details
- Advanced filter engine with type-specific evaluators
- Database-optimized query generation
- Real-time profile matching with performance metrics
- Notification service for alert management
- Export/import service for profile portability
- Batch operation service for bulk management

### 3.8 ✅ Corporation Intelligence

#### Features
- **Member Activity Analysis**: Timezone and activity pattern detection
- **Performance Metrics**: Individual and aggregate performance tracking
- **Risk Assessment**: Member risk evaluation and monitoring
- **Combat Doctrine Analysis**: Corporation fighting style analysis
- **Operational Patterns**: Strategic and tactical pattern identification
- **Activity Categorization**: Complete implementation from killmail data

#### Implementation Details
- Member activity analyzer with real timestamp analysis
- Performance analyzer for corporation-wide metrics
- Operational pattern analyzer for strategic insights
- Combat doctrine analyzer for tactical understanding
- Risk assessment engine for member evaluation
- Activity data collector aggregating multiple sources

### 3.9 ✅ Additional Production Features

#### Core Features
- **Danger Rating Calculation**: Multi-factor system risk assessment
- **Activity Trends**: Historical and real-time activity monitoring
- **Character Switcher**: Seamless multi-character management
- **Admin Dashboard**: User management and system monitoring
- **API Authentication**: Separate API key system for programmatic access
- **Performance Monitoring**: Query analysis and telemetry

#### Implementation Details
- Comprehensive analytics dashboard with multiple views
- Real-time activity monitoring with configurable thresholds
- Character switcher component with session management
- Admin LiveView for user and system management
- API authentication plug for programmatic access
- OpenTelemetry integration for observability

## 4. Technical Architecture

### 4.1 Technology Stack
- **Backend**: Elixir/Phoenix 1.7.21 with LiveView
- **Framework**: Ash Framework 3.4 for declarative resource management
- **Database**: PostgreSQL 16 with partitioning and materialized views
- **Pipeline**: Broadway for high-throughput killmail ingestion
- **Authentication**: EVE SSO OAuth2 with automatic token refresh
- **Monitoring**: OpenTelemetry for observability and performance monitoring
- **Caching**: Multi-layer caching strategy (hot_data, api_responses, analysis)

### 4.2 Architecture Principles
- **Hexagonal Architecture**: Clean separation of concerns with bounded contexts
- **Real-time First**: LiveView and PubSub for instant updates
- **Data-Driven**: All analysis based on real EVE data and combat logs
- **Performance Optimized**: Partitioned tables, covering indexes, bulk operations
- **Clean Code**: Zero placeholder implementations in production features

### 4.3 Data Pipeline
```
wanderer-kills SSE → Broadway Pipeline → PostgreSQL
                                     ↓
                         Static Data Tables ← EVE SDE
                                     ↓
                             Domain Services
                                     ↓
                             Phoenix LiveView → User
```

### 4.4 Database Design
- **Partitioned Tables**: `killmails_raw` partitioned by month for scalability
- **Materialized Views**: Pre-computed aggregations for performance
- **Automated Management**: pg_cron jobs for partition lifecycle
- **Static Data Integration**: 49,906 item types and 8,436 solar systems
- **Performance Optimization**: Covering indexes for common query patterns
- **Caching Strategy**: Multi-layer caching for frequently accessed data

## 5. User Experience Design

### 5.1 Core User Journeys

#### PvP Intelligence Analyst
```
Login → View Live Feed → Filter by Region/Alliance
→ Click Character → View Threat Score & Combat History
→ Analyze Ship Preferences → Compare with Corpmates
→ Share Intelligence Link
```

#### Fleet Commander
```
Login → Fleet Operations → Input Pilot List
→ View Composition Analysis → See Role Balance
→ Get Ship Statistics → Review Fleet Structure
→ Export Fleet Composition
```

#### Intelligence Officer
```
Login → Create Surveillance Profile → Set Complex Filters
→ Monitor Real-time Matches → View Historical Patterns
→ Analyze Battle Outcomes → Track Enemy Doctrines
→ Export Intelligence Reports
```

### 5.2 Interface Design Principles
- **Real-time Updates**: Immediate feedback and live data
- **Performance Optimized**: Responsive interactions with proper loading states
- **Intuitive Navigation**: Clear information architecture
- **Comprehensive Functionality**: Full feature access without limitations
- **Mobile Responsive**: Adaptive design for various screen sizes

## 6. Deferred Features

### 6.1 Market Pricing Integration
**Status**: Infrastructure exists, implementation deferred
- **Janice Client**: Stub implementation returns 0.0 prices
- **External Price Client**: Framework in place
- **Valuation Service**: Structure ready for implementation
- **Decision**: Lower priority, deferred for future implementation

### 6.2 Wormhole Operations
**Status**: Removed from scope
- **Original Features**: WH vetting, chain intelligence, mass calculations
- **Reason**: Extensive placeholder code throughout
- **Decision**: Better to remove than maintain placeholder code
- **Note**: Some remnant analyzers and static data loaders remain

## 7. Quality Standards

### 7.1 Definition of Done
A feature is complete when:
1. ✅ Queries real data from the database
2. ✅ Uses actual algorithms (no hardcoded values)
3. ✅ No placeholder/mock return values
4. ✅ Tests pass with real data
5. ✅ No random data generation
6. ✅ Leverages static data where applicable

### 7.2 Clean Codebase Principles
1. **No Placeholder Data**: Every function returns real calculations or queries
2. **Static Data Integration**: All ship/system lookups use loaded EVE data
3. **Honest Implementations**: Features work completely or don't exist
4. **Testable Code**: All features work with real data in tests
5. **Clear Boundaries**: Deferred features are cleanly separated

### 7.3 Prohibited Patterns
- ❌ Functions that return empty arrays `[]` or maps `%{}` as placeholders
- ❌ Hardcoded "magic" numbers (e.g., DPS = 600, mass = 10,000,000)
- ❌ Random data generation (`Enum.random`, `:rand.uniform()`) for "analysis"
- ❌ Stub functions that return fake data
- ❌ Modulo-based logic for classifications

## 8. Performance Requirements

### 8.1 Response Time Targets
- **Real-time Updates**: Sub-second killmail display
- **Page Load Times**: <2 seconds for initial page load
- **Database Queries**: <100ms for standard queries
- **Complex Analytics**: <5 seconds for multi-character comparisons

### 8.2 Scalability Requirements
- **Concurrent Users**: Support for 1000+ simultaneous users
- **Data Throughput**: Handle 100+ killmails per minute
- **Storage Growth**: Automated partition management for historical data
- **Memory Efficiency**: Optimized for production workloads

### 8.3 Reliability Requirements
- **Uptime**: 99.9% availability target
- **Error Handling**: Comprehensive error recovery and user feedback
- **Data Integrity**: ACID compliance with backup strategies
- **Monitoring**: Complete observability with OpenTelemetry integration

## 9. Security Requirements

### 9.1 Authentication & Authorization
- **EVE SSO Integration**: Secure OAuth2 implementation
- **Token Management**: Secure storage and automatic refresh
- **Session Security**: Protected session management
- **API Security**: Separate API key system for programmatic access

### 9.2 Data Protection
- **User Privacy**: Secure handling of character data
- **Data Encryption**: Encrypted storage for sensitive information
- **Access Controls**: Role-based access with proper permissions
- **Audit Logging**: Comprehensive activity logging

## 10. Testing & Quality Assurance

### 10.1 Current Test Coverage
- **53 test files** covering all major features
- **Context tests** for business logic validation
- **LiveView tests** for UI functionality
- **Integration tests** for end-to-end workflows
- **Performance tests** for critical paths

### 10.2 Test Categories
- **Unit Tests**: Individual function and module testing
- **Integration Tests**: Cross-module interaction testing
- **System Tests**: Full workflow validation
- **Performance Tests**: Load and stress testing
- **Security Tests**: Authentication and authorization validation

## 11. Deployment & Operations

### 11.1 Environment Requirements
- **PostgreSQL 16**: With pg_cron extension for automation
- **Elixir/OTP**: Production-ready Erlang VM deployment
- **Container Support**: Docker/Podman for consistent deployment
- **Resource Requirements**: Optimized for standard cloud instances

### 11.2 Monitoring & Observability
- **OpenTelemetry**: Distributed tracing and metrics
- **Health Checks**: Application and database health monitoring
- **Performance Metrics**: Query performance and response times
- **Error Tracking**: Comprehensive error reporting and alerting

### 11.3 Configuration Management
- **Environment Variables**: Secure configuration management
- **Feature Flags**: Pipeline enable/disable controls
- **Runtime Configuration**: Dynamic configuration updates
- **Secret Management**: Secure handling of API keys and tokens

## 12. Integration Requirements

### 12.1 External Dependencies
- **wanderer-kills**: Primary killmail data source via SSE
- **EVE ESI API**: Character and static data integration
- **EVE SDE**: Static data for ships, systems, and items
- **EVE SSO**: Authentication and character verification

### 12.2 API Compatibility
- **EVE ESI**: Full compatibility with current ESI version
- **Data Formats**: Standard JSON for API responses
- **Webhook Support**: Event-driven integrations where applicable
- **Rate Limiting**: Proper handling of API rate limits

## 13. Success Metrics

### 13.1 Implementation Status
- **~95%** of features working with real data
- **53 test files** providing adequate coverage
- **Minimal placeholders**: Only market pricing deferred
- **Clean architecture**: Maintained throughout development
- **Performance optimized**: Multi-layer caching implemented

### 13.2 Quality Metrics
- **Code Coverage**: Adequate test coverage across features
- **Real Data Integration**: All analysis based on actual EVE data
- **Production Ready**: Deployable and scalable implementation
- **User Experience**: Intuitive interfaces with real-time feedback

### 13.3 Performance Indicators
- **Sub-second** real-time updates achieved
- **53 test files** exceeding minimum requirements
- **Zero** critical placeholder code in production
- **99.9%** availability target ready

## 14. Remaining Work

### 14.1 Minor Cleanup Tasks
1. **Wormhole Remnants**: Remove remaining wormhole analyzers and loaders
2. **Import Path Updates**: Clean up module references after reorganization
3. **Documentation Updates**: Update inline documentation to match implementation

### 14.2 Future Enhancements
1. **Market Pricing**: Complete Janice API integration
2. **Advanced Analytics**: Machine learning for threat prediction
3. **Mobile Optimization**: Enhanced responsive design
4. **Additional Integrations**: More EVE Online API endpoints

## 15. Conclusion

EVE DMV is **production-ready** with comprehensive feature implementation:

### Current State
- **Complete feature set** for PvP intelligence and analytics
- **Real data implementation** throughout the application
- **Clean architecture** with proper separation of concerns
- **Adequate test coverage** with 53 test files
- **Performance optimized** with caching and query optimization

### Key Achievements
- **~95% features** working with real data from database
- **Minimal placeholders**: Only market pricing deferred
- **System Analytics UI**: Fully implemented with visualizations
- **Multi-character support**: Complete account management system
- **Real-time updates**: Sub-second killmail processing

### Production Readiness
The application is ready for production deployment with:
- Comprehensive feature implementation
- Adequate test coverage
- Performance optimization
- Security implementation
- Monitoring and observability

---

**Document Status**: Version 4.0 - Current Production State  
**Last Updated**: August 7, 2025  
**Status**: Production Ready  
**Remaining Work**: Minor cleanup and future enhancements only