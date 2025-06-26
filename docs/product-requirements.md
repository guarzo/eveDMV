# EVE Online PvP Activity Tracker - Product Requirements Document

## 1. Executive Summary

### 1.1 Project Vision
A real-time PvP activity tracking platform for EVE Online that provides actionable intelligence for fleet commanders, recruiters, and PvP enthusiasts.

### 1.2 Key Value Propositions
- **Real-time Intelligence:** Live kill feed with enriched ISK values and fitting analysis
- **Deep Analytics:** Character, corporation, and alliance performance metrics
- **Smart Alerts:** Custom surveillance profiles with advanced filtering
- **Fleet Optimization:** Data-driven ship assignment recommendations
- **Community Building:** Social features for sharing and collaboration

### 1.3 Target Users
- **Fleet Commanders:** Need real-time battlefield intelligence and pilot assessment
- **Corporation Recruiters:** Require detailed pilot performance analysis
- **PvP Enthusiasts:** Want comprehensive kill/loss tracking and fitting analysis
- **Alliance Leadership:** Need strategic overview of member activity and performance

## 2. Business Requirements

### 2.1 Success Metrics
- **User Engagement:** 70% monthly active users within 6 months
- **Data Accuracy:** <5% variance from zKillboard data
- **Performance:** <200ms average page load time
- **Uptime:** 99.5% availability during peak hours (18:00-24:00 EVE time)

### 2.2 Compliance Requirements
- **EVE Online EULA:** Full compliance with CCP's third-party developer guidelines
- **Data Privacy:** GDPR-compliant handling of user data
- **Rate Limiting:** Respect all CCP ESI rate limits and guidelines

## 3. User Authentication & Access Control

### 3.1 EVE SSO Integration
**Requirement:** Users must authenticate using EVE Online's Single Sign-On (SSO) system.

**Authentication Flow:**
1. User clicks "Login with EVE Online"
2. Redirect to CCP OAuth2 authorization endpoint
3. Request minimal required scopes for character information
4. Handle authorization callback and token management
5. Automatic token refresh before expiration

### 3.2 Access Control Requirements

**Role-Based Access Matrix:**

| Feature | Guest User | Authenticated User | Corporation Officer |
|---|---|---|---|
| Live Kill Feed | ✔️ Read-only | ✔️ Full access | ✔️ Full access |
| Personal Character Pages | ❌ | ✔️ Own character only | ✔️ Full access |
| Other Character Pages | ❌ | Conditional* | ✔️ Full access |
| Corporation Analytics | ❌ | ❌ | ✔️ Own corp only |
| Alliance Analytics | ✔️ Read-only | ✔️ Read-only | ✔️ Full access |
| Surveillance Profiles | ❌ | ✔️ Personal only | ✔️ Corp-wide profiles |
| Fleet Optimizer | ❌ | Conditional* | ✔️ Full access |

*Conditional access requires ≥20 personal kills OR ≥50 corporation kills in past 90 days

### 3.3 Multi-Character Support
- Users can link multiple EVE characters to one account
- Character switcher in navigation for seamless role switching
- Separate surveillance profiles per character

## 4. Core Features & User Stories

### 4.1 Live Kill Feed
**As a fleet commander, I want to see real-time PvP activity so I can respond to threats and opportunities.**

**Requirements:**
- Real-time kill notifications (sub-5 second delay)
- Rich killmail data including ship types, ISK values, and participants
- Filtering by system, alliance, or custom criteria
- Mobile-responsive design for field commanders

**Acceptance Criteria:**
- Feed updates automatically without page refresh
- Shows last 100 kills with infinite scroll for history
- Click any kill to see detailed breakdown
- System highlighting for consecutive kills in same location

### 4.2 Character Intelligence
**As a recruiter, I want detailed character analysis to evaluate potential members.**

**Requirements:**
- Comprehensive PvP statistics and trends
- Kill/death ratios with temporal analysis
- Ship diversity and fitting analysis
- Corporation history and activity patterns
- Performance metrics (Mass Balance, Usefulness Index)

**Acceptance Criteria:**
- Character search with autocomplete
- Visual charts showing activity over time
- Export functionality for recruitment records
- Comparison tools between multiple characters

### 4.3 Surveillance Profiles
**As a PvP enthusiast, I want custom alerts for specific activities or targets.**

**Requirements:**
- Complex filter creation (character, corp, alliance, system, ship type, ISK value, modules)
- Boolean logic (AND/OR) for advanced filtering
- Real-time notifications with customizable alerts
- Profile sharing within corporations

**Acceptance Criteria:**
- Drag-and-drop filter builder interface
- Audio/visual notification options
- Profile templates for common use cases
- Performance: <200ms filter evaluation per killmail

### 4.4 Fleet Optimizer
**As a fleet commander, I want ship assignment recommendations based on pilot experience.**

**Requirements:**
- Input fleet composition or killmail links
- Analyze pilot history and ship proficiency
- Recommend optimal ship assignments per doctrine
- Export formatted fleet compositions

**Acceptance Criteria:**
- Support for common fleet doctrines (shield, armor, etc.)
- Pilot experience scoring algorithm
- Alternative recommendations if pilots unavailable
- Integration with popular EVE fleet management tools

## 5. User Interface Requirements

### 5.1 Design Principles
- **EVE Online Visual Language:** Dark theme with accent colors matching EVE UI
- **Information Density:** Maximize data visibility without overwhelming users
- **Mobile Responsive:** Essential features accessible on mobile devices
- **Accessibility:** WCAG 2.1 AA compliance for color contrast and keyboard navigation

### 5.2 Navigation Structure
**Primary Navigation:**
- Live Kill Feed (default landing page)
- Character Search & Analytics
- Corporation/Alliance Directory
- System Intelligence
- Personal Dashboard
- Surveillance Profiles

**Secondary Navigation:**
- User profile and settings
- Character switcher (for multi-character accounts)
- Help and documentation
- Logout

### 5.3 Page Layout Requirements

#### Live Kill Feed Page
**Information Architecture:**
- Real-time activity stream as primary content
- Filtering controls in sidebar
- Quick-access surveillance profile switcher
- System activity heatmap (optional)

**Data Display:**
- Timestamp with relative time ("2 minutes ago")
- Ship icons with tech level indicators
- System security status visual indicators
- ISK value with color coding (green >100M, red <10M)
- Participant count and alliance affiliations

#### Character Analysis Pages
**Required Sections:**
- Character header (portrait, name, corp/alliance, join dates)
- Key performance metrics dashboard
- Activity timeline with filtering
- Ship usage analysis
- Recent killmails participation

**Interactive Elements:**
- Expandable killmail details
- Exportable charts and data
- Comparison mode (vs other characters)
- Historical trend analysis

#### Surveillance Profile Management
**User Interface Requirements:**
- Visual filter builder with drag-and-drop
- Real-time filter preview
- Profile templates and sharing
- Notification settings panel
- Performance monitoring (alerts per hour)

## 6. Data Requirements

### 6.1 Primary Data Sources
- **wanderer-kills API:** Enriched killmail data with ISK values, module analysis, and pilot metrics
- **EVE ESI:** Character, corporation, alliance, and universe data
- **zKillboard:** Fallback killmail source
- **Janice/Mutamarket:** Market price data for ISK calculations

### 6.2 Data Retention Policy
- **Active killmails:** 2 years minimum retention
- **User profiles:** Indefinite (with GDPR deletion rights)
- **Cache data:** 24 hours maximum (auto-purged)
- **Audit logs:** 1 year minimum for security compliance

### 6.3 Data Quality Requirements
- **Completeness:** 99%+ of EVE Online killmails captured within 5 minutes
- **Accuracy:** <5% variance from authoritative sources (zKillboard)
- **Enrichment success:** >95% of killmails successfully enriched with ISK/module data
- **Real-time latency:** <5 seconds from EVE kill to platform display

## 7. Performance Requirements

### 7.1 Response Time Requirements
- **Page load time:** <2 seconds for 95% of requests
- **Search queries:** <500ms for character/corporation lookup
- **Live feed updates:** <5 seconds latency from source
- **Filter evaluation:** <200ms for surveillance profile matching

### 7.2 Scalability Requirements
- **Concurrent users:** Support 1,000+ simultaneous active users
- **Data throughput:** Handle 1,000+ killmails per hour during peak activity
- **Storage growth:** 500GB+ annual data growth capacity
- **Geographic distribution:** Sub-200ms response times globally

### 7.3 Availability Requirements
- **Uptime target:** 99.5% availability during EVE Online peak hours
- **Planned maintenance:** <4 hours monthly, scheduled during off-peak
- **Disaster recovery:** <1 hour RTO, <24 hours RPO
- **Graceful degradation:** Core features remain functional during external API outages

## 8. Security & Compliance

### 8.1 Data Protection
- **Encryption:** TLS 1.3 for all data in transit
- **Authentication:** EVE SSO integration only (no custom passwords)
- **Session management:** Secure, encrypted session tokens with automatic expiration
- **API security:** Rate limiting and request validation

### 8.2 Privacy Requirements
- **GDPR compliance:** User data deletion within 30 days of request
- **Data minimization:** Collect only necessary EVE character data
- **Transparency:** Clear privacy policy and data usage terms
- **User control:** Export personal data functionality

### 8.3 EVE Online Compliance
- **CCP Developer Guidelines:** Full adherence to third-party application rules
- **ESI rate limiting:** Respect all official API rate limits
- **EULA compliance:** No real-money trading features or violations
- **Character data:** Only publicly available information unless explicitly authorized

## 9. Technical Constraints

### 9.1 External Dependencies
- **EVE ESI:** Primary dependency for character/universe data
- **wanderer-kills:** Critical dependency for enriched killmail data
- **Market APIs:** Janice/Mutamarket for ISK valuations
- **Infrastructure:** Cloud hosting with auto-scaling capabilities

### 9.2 Browser Compatibility
- **Modern browsers:** Chrome 90+, Firefox 88+, Safari 14+, Edge 90+
- **Mobile browsers:** iOS Safari 14+, Chrome Mobile 90+
- **JavaScript requirement:** ES2020+ support required
- **Progressive enhancement:** Core features work without JavaScript

### 9.3 Platform Requirements
- **Database:** PostgreSQL 13+ with JSON support
- **Backend:** Elixir/Phoenix with LiveView for real-time features
- **Caching:** Redis for session management and real-time data
- **Monitoring:** Application performance monitoring and alerting

## 10. Success Criteria & KPIs

### 10.1 User Engagement Metrics
- **Monthly Active Users:** 70% of registered users active monthly
- **Session Duration:** Average 15+ minutes per session
- **Feature Adoption:** 50%+ of users create surveillance profiles
- **Retention Rate:** 60% user retention after 30 days

### 10.2 Technical Performance Metrics
- **Uptime:** 99.5% availability during EVE Online peak hours
- **Performance:** 95% of page loads under 2 seconds
- **Data Quality:** 99%+ killmail capture rate within 5 minutes
- **User Satisfaction:** 4.0+ average rating in user feedback

### 10.3 Business Success Metrics
- **Community Growth:** 10,000+ registered users within 12 months
- **Content Quality:** Featured in EVE community publications
- **Developer Recognition:** CCP community appreciation or mention
- **Sustainability:** Self-hosted costs covered by donations/sponsorships

---

This Product Requirements Document provides the complete functional specification for the EVE PvP Tracker platform. For detailed technical implementation guidance, refer to the [Technical Design Document](./DESIGN.md).