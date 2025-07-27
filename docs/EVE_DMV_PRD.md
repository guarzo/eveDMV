# EVE DMV Product Requirements Document

*Version 2.0 - January 2025*

## 1. Executive Summary

### 1.1 Product Overview
EVE DMV is a production-ready real-time PvP intelligence and analytics platform for EVE Online. Built with Phoenix LiveView and the Ash Framework, it provides comprehensive intelligence gathering, battle analysis, and fleet operations support for EVE pilots, corporations, and alliances.

### 1.2 Current Status: Feature Complete
As of January 2025, EVE DMV has achieved **100% implementation completeness** for all core user-facing features. All major implementation gaps have been resolved, placeholder code has been eliminated, and the application is production-ready with clean architecture throughout.

### 1.3 Key Achievements
- **Real-time killmail feed** with advanced filtering and infinite scroll
- **Comprehensive character intelligence** with threat scoring and behavioral analysis
- **Battle analysis system** with timeline reconstruction and phase detection
- **Multi-character account management** with seamless character switching
- **Surveillance profiles** with complex filtering and real-time matching
- **System activity analytics** with danger ratings and escalation detection
- **Fleet composition analysis** using real EVE static data
- **Clean codebase** with zero placeholder implementations in core features

## 2. Product Vision & Strategy

### 2.1 Vision Statement
To provide EVE Online players with the most comprehensive, accurate, and real-time PvP intelligence platform that enhances tactical decision-making and situational awareness.

### 2.2 Target Users
- **PvP Intelligence Analysts**: Gathering intel on hostile entities
- **Fleet Commanders**: Planning and executing fleet operations
- **Wormhole Corporation Members**: Managing chain security and operations
- **Intelligence Officers**: Monitoring threats and analyzing patterns
- **Solo/Small Gang Pilots**: Assessing risks and opportunities

### 2.3 Core Value Propositions
1. **Real-time Intelligence**: Live killmail feed with sub-second updates
2. **Accurate Analysis**: All data based on real EVE static data and combat logs
3. **Comprehensive Coverage**: Full spectrum from individual pilots to fleet operations
4. **Actionable Insights**: Clear threat assessments and tactical recommendations
5. **Clean Architecture**: Maintainable codebase with no placeholder implementations

## 3. Functional Requirements

### 3.1 ✅ Authentication & User Management (COMPLETE)

#### Core Features
- **EVE SSO Integration**: OAuth2 authentication with automatic token refresh
- **Multi-Character Support**: Account system managing multiple EVE characters
- **Character Switching**: Seamless switching without re-authentication
- **Session Management**: Persistent sessions with character context
- **Role-Based Access**: Basic admin/user role distinction

#### Technical Implementation
- Account-User relationship database schema
- Token lifecycle management with automatic refresh
- Session-based character context switching
- API key system for programmatic access

### 3.2 ✅ Live Kill Feed (COMPLETE)

#### Core Features
- **Real-time Updates**: Sub-second killmail display via SSE connection
- **Advanced Filtering**: Alliance, ship type, ISK value, and system-based filtering
- **Infinite Scroll**: Performance-optimized progressive loading
- **Rich Data Display**: Ship types, damage values, participants, locations
- **Activity Metrics**: System danger ratings and escalation detection

#### Technical Implementation
- Broadway pipeline with SSE producer for wanderer-kills integration
- Database-level filtering with 50-item pagination
- JavaScript hooks for smooth infinite loading
- Real-time filter preview with live killmail matching

### 3.3 ✅ Character Intelligence (COMPLETE)

#### Core Features
- **Threat Scoring**: Multi-dimensional threat assessment algorithm
- **Combat Statistics**: Kill/death ratios, ISK efficiency, activity patterns
- **Ship Preferences**: Detailed analysis of preferred ship types and weapons
- **Gang Size Patterns**: Behavioral analysis of fleet participation
- **Activity Analysis**: Temporal patterns and engagement frequency
- **Character Comparison**: Multi-character analysis and similarity matching

#### Technical Implementation
- Real database queries for all preference calculations
- Materialized views for performance optimization
- Comprehensive analytics engine with configurable weights
- Head-to-head comparison tools supporting 2-10 characters

### 3.4 ✅ Battle Analysis (COMPLETE)

#### Core Features
- **Battle Detection**: Automatic clustering of related killmails
- **Timeline Reconstruction**: Chronological battle event mapping
- **Phase Analysis**: Multi-phase detection with engagement patterns
- **Participant Analysis**: Role identification and performance metrics
- **Side Determination**: Intelligent alliance/corporation relationship analysis
- **Outcome Analysis**: Battle results and decisive moment identification

#### Technical Implementation
- Time-gap analysis with configurable thresholds
- Alliance/corporation relationship graphs
- Attack pattern classification algorithms
- Performance-optimized clustering with battle context awareness

### 3.5 ✅ Fleet Operations (COMPLETE)

#### Core Features
- **Ship Classification**: Role-based ship categorization using static data
- **Composition Analysis**: Fleet balance and effectiveness assessment
- **DPS/EHP Calculations**: Estimates based on ship types and fittings
- **Mass Calculations**: Wormhole mass management using real ship data
- **Role Detection**: Ship role identification from EVE static data

#### Technical Implementation
- EVE static data integration (49,906 item types)
- Real ship attribute queries for mass and capabilities
- Role classification based on ship bonuses and characteristics
- Fleet optimization algorithms with composition recommendations

### 3.6 ✅ Surveillance Profiles (COMPLETE)

#### Core Features
- **Profile Management**: Full CRUD operations for surveillance profiles
- **Complex Filtering**: Range, temporal, proximity, and nested conditions
- **Real-time Matching**: Live killmail evaluation against profile criteria
- **Advanced Logic**: AND/OR combinations with condition prioritization
- **Performance Optimization**: Short-circuit evaluation and condition reordering

#### Technical Implementation
- Advanced filter engine with type-specific evaluators
- Database-optimized query generation
- Real-time profile matching with performance metrics
- Backward compatibility with existing profile formats

### 3.7 ✅ System Activity Analytics (COMPLETE)

#### Core Features
- **Danger Rating Calculation**: Multi-factor system risk assessment
- **Activity Trends**: Historical and real-time activity monitoring
- **Escalation Detection**: Automated threat level escalation
- **Regional Analysis**: Multi-system activity correlation
- **Heatmap Visualization**: Visual activity intensity mapping

#### Technical Implementation
- Comprehensive analytics dashboard with multiple views
- Real-time activity monitoring with configurable thresholds
- Performance metrics including activity intensity and PvP quality scores
- Multi-view interface (Overview, Regional, Trends, Heatmap)

### 3.8 ✅ Wormhole Operations (COMPLETE)

#### Core Features
- **System Classification**: Accurate wormhole class detection
- **Mass Management**: Real ship mass calculations from static data
- **Chain Intelligence**: Basic wormhole chain tracking
- **Activity Monitoring**: Wormhole-specific activity patterns
- **Home Defense Analysis**: Security threat assessment

#### Technical Implementation
- Fixed C-class detection using real EVE data
- Mass calculations based on actual ship attributes
- Wormhole-specific analytics and monitoring
- Integration with general activity tracking systems

## 4. Technical Architecture

### 4.1 Technology Stack
- **Backend**: Elixir/Phoenix 1.7.21 with LiveView
- **Framework**: Ash Framework 3.4 for declarative resource management
- **Database**: PostgreSQL 16 with partitioning and materialized views
- **Pipeline**: Broadway for high-throughput killmail ingestion
- **Authentication**: EVE SSO OAuth2 with automatic token refresh
- **Monitoring**: OpenTelemetry for observability and performance monitoring

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
Login → Fleet Optimizer → Input Pilot List
→ View Composition Analysis → See Role Balance
→ Get DPS/Tank Estimates → Check Wormhole Mass
→ Share Fleet Composition
```

#### Wormhole Corporation Member
```
Login → View Chain Activity → See Recent Kills
→ Track Home Defense Metrics → Monitor Entry Points
→ Check Mass Calculations → Plan Fleet Movements
```

#### Intelligence Officer
```
Login → Create Surveillance Profile → Set Complex Filters
→ Monitor Real-time Matches → View Historical Patterns
→ Analyze Battle Outcomes → Track Enemy Doctrines
```

### 5.2 Interface Design Principles
- **Real-time Updates**: Immediate feedback and live data
- **Performance Optimized**: Responsive interactions with proper loading states
- **Intuitive Navigation**: Clear information architecture
- **Comprehensive Functionality**: Full feature access without limitations

## 6. Quality Standards

### 6.1 Definition of Done
A feature is complete when:
1. ✅ Queries real data from the database
2. ✅ Uses actual algorithms (no hardcoded values)
3. ✅ No placeholder/mock return values
4. ✅ Tests pass with real data
5. ✅ No random data generation
6. ✅ Leverages static data where applicable

### 6.2 Clean Codebase Principles
1. **No Placeholder Data**: Every function returns real calculations or queries
2. **Static Data Integration**: All ship/system lookups use loaded EVE data
3. **Honest Implementations**: Features work completely or don't exist
4. **Testable Code**: All features work with real data in tests
5. **Clear Boundaries**: Deferred features are cleanly separated

### 6.3 Prohibited Patterns
- ❌ Functions that return empty arrays `[]` or maps `%{}` as placeholders
- ❌ Hardcoded "magic" numbers (e.g., DPS = 600, mass = 10,000,000)
- ❌ Random data generation (`Enum.random`, `:rand.uniform()`) for "analysis"
- ❌ Stub functions that return fake data
- ❌ Modulo-based logic for classifications (e.g., `ship_type_id % 10`)

## 7. Performance Requirements

### 7.1 Response Time Targets
- **Real-time Updates**: Sub-second killmail display
- **Page Load Times**: <2 seconds for initial page load
- **Database Queries**: <100ms for standard queries
- **Complex Analytics**: <5 seconds for multi-character comparisons

### 7.2 Scalability Requirements
- **Concurrent Users**: Support for 1000+ simultaneous users
- **Data Throughput**: Handle 100+ killmails per minute
- **Storage Growth**: Automated partition management for historical data
- **Memory Efficiency**: Optimized for production workloads

### 7.3 Reliability Requirements
- **Uptime**: 99.9% availability target
- **Error Handling**: Comprehensive error recovery and user feedback
- **Data Integrity**: ACID compliance with backup strategies
- **Monitoring**: Complete observability with OpenTelemetry integration

## 8. Security Requirements

### 8.1 Authentication & Authorization
- **EVE SSO Integration**: Secure OAuth2 implementation
- **Token Management**: Secure storage and automatic refresh
- **Session Security**: Protected session management
- **API Security**: Separate API key system for programmatic access

### 8.2 Data Protection
- **User Privacy**: Secure handling of character data
- **Data Encryption**: Encrypted storage for sensitive information
- **Access Controls**: Role-based access with proper permissions
- **Audit Logging**: Comprehensive activity logging

## 9. Integration Requirements

### 9.1 External Dependencies
- **wanderer-kills**: Primary killmail data source via SSE
- **EVE ESI API**: Character and static data integration
- **EVE SDE**: Static data for ships, systems, and items
- **EVE SSO**: Authentication and character verification

### 9.2 API Compatibility
- **EVE ESI**: Full compatibility with current ESI version
- **Data Formats**: Standard JSON for API responses
- **Webhook Support**: Event-driven integrations where applicable

## 10. Deployment & Operations

### 10.1 Environment Requirements
- **PostgreSQL 16**: With pg_cron extension for automation
- **Elixir/OTP**: Production-ready Erlang VM deployment
- **Container Support**: Docker/Podman for consistent deployment
- **Resource Requirements**: Optimized for standard cloud instances

### 10.2 Monitoring & Observability
- **OpenTelemetry**: Distributed tracing and metrics
- **Health Checks**: Application and database health monitoring
- **Performance Metrics**: Query performance and response times
- **Error Tracking**: Comprehensive error reporting and alerting

## 11. Success Metrics

### 11.1 Feature Completeness
- **100%** of major requirements implemented
- **Zero** placeholder implementations in core features
- **Complete** user interface coverage for all features

### 11.2 Quality Metrics
- **Clean Architecture**: Maintainable codebase following design principles
- **Real Data Integration**: All analysis based on actual EVE data
- **Production Ready**: Deployable and scalable implementation
- **User Experience**: Intuitive interfaces with real-time feedback

### 11.3 Performance Indicators
- **Sub-second** real-time updates
- **70%+** test coverage minimum
- **Zero** critical placeholder code in production
- **99.9%** availability target

## 12. Future Roadmap

### 12.1 Enhancement Opportunities
1. **Advanced Analytics**: Machine learning for threat prediction
2. **Visual Improvements**: Enhanced UI/UX and data visualization
3. **Performance Optimization**: Further database and query optimization
4. **Integration Features**: Additional EVE Online API integrations
5. **Mobile Experience**: Responsive design improvements

### 12.2 Technical Debt Maintenance
1. **Code Quality**: Continuous refactoring and optimization
2. **Test Coverage**: Expand automated testing suite
3. **Documentation**: Keep implementation docs current
4. **Dependencies**: Regular security and version updates

## 13. Conclusion

EVE DMV has successfully transitioned from a development prototype to a **production-ready PvP intelligence platform** with comprehensive functionality and clean architecture throughout. All major requirements have been implemented with real data integration, eliminating placeholder code and providing genuine value to EVE Online players.

The platform now serves as a solid foundation for future enhancements while maintaining the highest standards of code quality and user experience. With 100% feature completeness for core functionality, EVE DMV is ready for production deployment and continued evolution based on user feedback and emerging requirements.

---

**Document Status**: Version 2.0 - Feature Complete  
**Last Updated**: January 2025  
**Next Review**: Q2 2025