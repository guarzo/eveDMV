# EVE DMV Documentation

## Project Overview

EVE DMV is an Elixir Phoenix application for tracking EVE Online PvP data. For implementation details, see [CLAUDE.md](/workspace/CLAUDE.md).

## Current Project Status

**Last Updated**: January 2025 (Sprint 3 Complete)

### What Actually Works ✅
- **Kill Feed** (`/feed`) - Real-time killmail display with SSE integration
- **Character Analysis** (`/analysis/:character_id`) - Shows real killmail data
- **Authentication** - EVE SSO OAuth integration
- **Database Schema** - Partitioned tables for scalability
- **Broadway Pipeline** - Processes ~50-100 killmails/minute
- **Static Data** - 49,894 EVE items loaded including all ships
- **Monitoring Dashboard** (`/monitoring`) - Error tracking and pipeline health

### What Doesn't Work Yet 🚧
- **Battle Analysis** - Returns empty data
- **Corporation Intelligence** - Placeholder UI only
- **Fleet Composition Tools** - Not implemented
- **Wormhole Features** - All return mock data
- **Surveillance Profiles** - Database exists but no functionality
- **Price Integration** - Tables exist but not connected to APIs

### Key Project Status Documents

- **[PROJECT_STATUS.md](/workspace/PROJECT_STATUS.md)** - High-level status overview
- **[ACTUAL_PROJECT_STATE.md](/workspace/ACTUAL_PROJECT_STATE.md)** - Detailed technical reality
- **[DEVELOPMENT_PROGRESS_TRACKER.md](/workspace/DEVELOPMENT_PROGRESS_TRACKER.md)** - Sprint tracking

## 📁 Documentation Structure

### 🏗️ Architecture
Technical design and system architecture documentation.

| Document | Purpose |
|----------|---------|
| [Database Schema](./architecture/database-schema.md) | Entity relationships and data model |
| [Database Partitioning](./architecture/database-partitioning.md) | Partitioning strategy for killmail data |
| [Caching Strategy](./architecture/caching-strategy.md) | Multi-layer caching approach |
| [Enriched/Raw Analysis](./architecture/enriched-raw-analysis.md) | Decision to remove enriched table |

### 💻 Development
Development environment setup and best practices.

| Document | Purpose |
|----------|---------|
| [Dev Container Setup](./development/devcontainer.md) | Development environment configuration |
| [Performance Optimization](./development/performance-optimization.md) | Performance best practices |
| [Pull Request Checklist](./development/pull-request-checklist.md) | Code review standards |

### 🔧 Implementation
Feature specifications and integration guides.

| Document | Purpose |
|----------|---------|
| [Missed Items](./implementation/missed-items.md) | Honest list of unimplemented ESI features |
| [ESI Integration Summary](./implementation/esi-integration-summary.md) | EVE ESI integration status |
| [Service Integration](./implementation/service-integration.md) | External API integration |
| [Character Intelligence Design](./implementation/character-intelligence-design.md) | Character intel specification |

### 🏃 Sprints
Sprint planning and tracking documentation.

```
sprints/
├── completed/                     # Finished sprints
│   ├── REALITY_CHECK_SPRINT_1.md # Stabilization sprint (Dec 2024)
│   ├── SPRINT_3_PLAN.md         # Polish & Stabilize plan
│   └── SPRINT_3_PROGRESS.md      # Sprint 3 results (31/30 points)
├── planned/                      # Future sprints
│   └── SPRINT_2_CHARACTER_INTELLIGENCE_ENHANCEMENT.md
└── current/                      # Active sprint work
```

### 📚 Reference
Reference materials and external data specifications.

| Document | Purpose |
|----------|---------|
| [External Data Sources](./reference/external-data-sources.md) | Third-party API integrations |
| [Module Tags](./reference/module-tags.md) | Module categorization system |

### 🗄️ Archive
Historical documents preserved for reference.

- `archive/old-overclaiming-sprints/` - Pre-reality-check sprint documents that claimed features were complete when they were actually stubs

## 🚀 Getting Started

For new developers joining the project:

1. **Understand the reality:** Read [ACTUAL_PROJECT_STATE.md](/workspace/ACTUAL_PROJECT_STATE.md) 
2. **Set up development:** Follow the [Dev Container Setup](./development/devcontainer.md) guide
3. **Understand the system:** Review [CLAUDE.md](/workspace/CLAUDE.md) for implementation details
4. **Check what's missing:** Review [Missed Items](./implementation/missed-items.md)

## Development Philosophy

**"If it returns mock data, it's not done."**

We only mark features as complete when they:
- Query real data from the database
- Use actual algorithms (no hardcoded values)
- Have tests with real data
- Include accurate documentation

## Sprint History

### Completed Sprints
1. **Reality Check Sprint 1** (Dec 2024) - Stabilized core features, fixed Character Intelligence
2. **Sprint 3: Polish & Stabilize** (Jan 2025) - Fixed runtime errors, removed enriched table complexity

### Next Priorities
1. Battle Analysis - Group kills into battles
2. Corporation Intelligence - Basic member activity
3. Performance optimization
4. Additional Character Intel features

---

*Last updated: Post-Sprint 3 documentation cleanup - January 2025*