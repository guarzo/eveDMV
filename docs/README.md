# EVE Online PvP Tracker - Documentation

This directory contains all project documentation organized into logical categories. Each document serves a specific purpose in the development and understanding of the EVE PvP Tracker platform.

## 📋 Core Documents

| Document | Purpose | Audience |
|----------|---------|----------|
| [Product Requirements Document](./product-requirements.md) | Complete functional specification and business requirements | Product owners, stakeholders, developers |

## 🏗️ Architecture

Technical design and system architecture documentation.

| Document | Purpose | Key Topics |
|----------|---------|------------|
| [Technical Design](./architecture/DESIGN.md) | Complete system architecture and technology stack | Phoenix LiveView, PostgreSQL, Redis, Broadway pipeline |
| [Database Schema](./architecture/database-schema.md) | Entity relationship diagram and data model | Tables, relationships, indexes |
| [Database Partitioning](./architecture/database-partitioning.md) | Partitioning strategy for killmail data | Range partitioning, performance optimization |
| [Caching Strategy](./architecture/caching-strategy.md) | Multi-layer caching approach | ETS tables, Redis, Cachex configuration |

## 💻 Development

Development environment setup and best practices.

| Document | Purpose | Key Topics |
|----------|---------|------------|
| [Dev Container Setup](./development/devcontainer.md) | Development environment configuration | Docker, VS Code, automatic setup |
| [Pull Request Checklist](./development/pull-request-checklist.md) | Code review and quality standards | Testing, documentation, performance |
| [Performance Optimization](./development/performance-optimization.md) | Performance best practices | LiveView optimization, database tuning |

## 🔧 Implementation Guides

Detailed implementation specifications for core features.

| Document | Purpose | Key Topics |
|----------|---------|------------|
| [Killmail Pipeline](./implementation/killmail-pipeline.md) | Broadway pipeline implementation | SSE consumption, data enrichment |
| [Service Integration](./implementation/service-integration.md) | External API integration | wanderer-kills, EVE ESI |
| [Authentication Edge Cases](./implementation/authentication-edge-cases.md) | Complex authentication scenarios | Corp transfers, token expiration |
| [Surveillance Profile Matching](./implementation/surveillance-profile-matching.md) | Profile filtering system | JSON schema, performance optimization |
| [Data Freshness](./implementation/data-freshness.md) | Data freshness management | Retry policies, error handling |

## 📚 Reference

Reference materials and external data specifications.

| Document | Purpose | Key Topics |
|----------|---------|------------|
| [External Data Sources](./reference/external-data-sources.md) | Third-party API integrations | Janice, Mutamarket, static EVE data |
| [Module Tags](./reference/module-tags.md) | Module categorization system | ISK calculations, performance metrics |

## 🚀 Getting Started

For new developers joining the project:

1. **Start here:** Read the [Product Requirements Document](./product-requirements.md) to understand what we're building
2. **Understand the system:** Review the [Technical Design](./architecture/DESIGN.md) for architecture overview
3. **Set up development:** Follow the [Dev Container Setup](./development/devcontainer.md) guide
4. **Code standards:** Familiarize yourself with the [Pull Request Checklist](./development/pull-request-checklist.md)

## 📖 Document Conventions

### File Naming
- Use lowercase with hyphens for multi-word filenames
- Be descriptive: `authentication-edge-cases.md` not `auth.md`
- Group related files in appropriate subdirectories

### Content Structure
- Use clear, descriptive headings
- Include code examples where appropriate
- Cross-reference related documents
- Keep information current and accurate

### Updates
- Update documentation alongside code changes
- Use the pull request process for documentation changes
- Ensure links remain valid after file moves or renames

## 🔗 External Links

- [EVE ESI Documentation](https://esi.evetech.net/ui/)
- [Phoenix LiveView Guide](https://hexdocs.pm/phoenix_live_view/)
- [PostgreSQL Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [Broadway Documentation](https://hexdocs.pm/broadway/)

---

*Last updated: Initial organization - 2024* 