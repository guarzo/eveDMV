# 🚀 EVE DMV - Project Overview

## Vision Statement

EVE DMV is a real-time PvP activity tracking platform for EVE Online that provides actionable intelligence for fleet commanders, recruiters, and PvP enthusiasts. Our goal is to become the go-to intelligence platform for EVE Online players by offering deep analytics, real-time alerts, and data-driven recommendations.

## 🎯 Project Goals

1. **Real-time Intelligence**: Provide sub-5 second latency for critical PvP data
2. **Actionable Insights**: Transform raw killmail data into tactical recommendations
3. **Community Tool**: Build a platform that serves 10,000+ active EVE players
4. **Performance Excellence**: Maintain <200ms page loads and 99.5% uptime
5. **EVE Ecosystem Integration**: Full compliance with CCP guidelines while maximizing data utility

## 👥 Target Users & Personas

### Fleet Commanders
- **Need**: Real-time battlefield intelligence and pilot assessment
- **Features**: Live kill feed, hot zone tracking, fleet composition analysis
- **Success**: Better tactical decisions, improved fleet survival rates

### Corporation Recruiters
- **Need**: Detailed pilot performance analysis for vetting
- **Features**: Character intelligence, activity patterns, performance metrics
- **Success**: Higher quality recruits, reduced security risks

### PvP Enthusiasts
- **Need**: Comprehensive kill/loss tracking and fitting analysis
- **Features**: Personal analytics, fitting recommendations, trend analysis
- **Success**: Improved PvP performance, better ship selection

### Alliance Leadership
- **Need**: Strategic overview of member activity and performance
- **Features**: Alliance analytics, territory control metrics, member assessment
- **Success**: Better strategic planning, improved member engagement

## 🔧 Core Features

### 1. Live Kill Feed
- Real-time PvP activity stream from wanderer-kills SSE feed
- Enriched ISK values from Janice and Mutamarket APIs
- System statistics and hot zone identification
- Advanced filtering and search capabilities

### 2. Character Intelligence
- Hunter-focused tactical analysis
- Ship usage patterns and preferences
- Known associates and common fleets
- Weakness identification and counter-tactics
- Activity heat maps and timezone analysis

### 3. Smart Surveillance System
- Custom alert profiles with complex filtering
- Real-time notifications via webhooks/Discord
- Pattern matching for specific behaviors
- Bulk profile management tools

### 4. Fleet Optimizer
- Data-driven ship assignment recommendations
- Pilot experience matching
- Optimal fleet composition suggestions
- Performance prediction models

### 5. Performance Analytics
- Mass balance calculations
- Usefulness index metrics
- Kill/death ratios and trends
- ISK efficiency analysis

## 💻 Technical Architecture

### Backend Stack
- **Elixir/Phoenix 1.7.21**: Core application framework
- **Ash Framework 3.4**: Declarative resource management
- **Broadway**: Real-time killmail processing pipeline
- **PostgreSQL**: Primary database with monthly partitioning
- **Redis/ETS**: Multi-layer caching for performance

### Frontend Stack
- **Phoenix LiveView**: Real-time UI updates without JavaScript
- **Tailwind CSS**: Utility-first styling
- **Alpine.js**: Minimal JavaScript enhancements
- **Chart.js**: Data visualization

### External Integrations
- **wanderer-kills**: Primary enriched killmail source
- **EVE ESI**: Character, corporation, universe data
- **Janice API**: Market pricing data
- **Mutamarket**: Abyssal module pricing
- **zKillboard**: Fallback killmail source

## 📈 Project Status

### Current Sprint (Sprint 2 - Week 2)
- ✅ 52/50 story points completed
- 🚧 3 features in progress (13 pts)
- 🐛 0 critical bugs

### Completed Features
- EVE SSO authentication system
- Real-time kill feed with SSE integration
- Character intelligence pages
- Basic surveillance system
- External API integrations
- Player analytics engine

### In Progress
- Alliance Analytics Dashboard
- Value Enrichment with Real-time Pricing
- Batch Profile Management Tools

## 🗺️ Roadmap Overview

### Phase 1: Foundation ✅ (Weeks 1-2)
- Core infrastructure setup
- Real-time data pipeline
- Basic UI and authentication

### Phase 2: Intelligence Platform 🚧 (Weeks 3-8)
- **Sprint 2**: PvP Analytics Core
- **Sprint 3**: Corporation Intelligence
- **Sprint 4**: Geographic Intelligence
- **Sprint 5**: Fleet Composition Analysis
- **Sprint 6**: Polish & Performance

### Phase 3: Advanced Features (Weeks 9-12)
- Machine learning predictions
- Advanced pattern recognition
- API for third-party tools
- Mobile companion app

## 📊 Success Metrics

### User Engagement
- 70% monthly active users within 6 months
- 5+ minutes average session duration
- 3+ features used per session

### Technical Performance
- <200ms average page load time
- <5s killmail processing latency
- 99.5% uptime during peak hours

### Data Quality
- 99%+ killmail capture rate
- <5% ISK value variance from zKillboard
- 100% ESI data freshness within TTL

### Community Growth
- 10,000+ registered users in 12 months
- 1,000+ daily active users
- 100+ surveillance profiles created daily

## 🛠️ Development Workflow

### Quality Standards
- Automated testing with >80% coverage
- Credo static analysis passing
- Dialyzer type checking clean
- Performance benchmarks met

### Development Process
1. Feature design in `/docs/implementation/`
2. Implementation with test coverage
3. Code review via pull request
4. Automated CI/CD checks
5. Deployment to staging
6. Production release

### Getting Started
1. Read [Product Requirements](../product-requirements.md)
2. Review [Technical Design](../architecture/DESIGN.md)
3. Set up [Dev Container](../development/devcontainer.md)
4. Check [Current Sprint](../sprints/sprint-2.md)

## 🔐 Compliance & Security

### EVE Online Compliance
- Full adherence to CCP's Third-Party Policy
- No automation or botting features
- Respect for player privacy
- Transparent data usage

### Security Measures
- OAuth2 authentication only
- No password storage
- Encrypted API tokens
- Regular security audits
- GDPR compliance

## 📞 Contact & Support

- **GitHub**: [Project Repository](https://github.com/yourusername/eve-dmv)
- **Discord**: [Community Server](https://discord.gg/evedmv)
- **Email**: support@evedmv.com

---

*Last updated: 2025-06-29*