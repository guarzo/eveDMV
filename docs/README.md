# EVE DMV Documentation

Documentation for EVE DMV development, deployment, and operations.

## 📋 Core Documentation

| Document | Description |
|----------|-------------|
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | System design, patterns, and technical architecture |
| **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** | Production deployment and operations guide |
| **[OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md)** | Operational procedures and troubleshooting |
| **[EVE_DMV_PRD.md](EVE_DMV_PRD.md)** | Product Requirements Document |
| **[TEAM_STYLE_GUIDE.md](TEAM_STYLE_GUIDE.md)** | Code standards and team conventions |
| **[WEB_LAYER_BEST_PRACTICES.md](WEB_LAYER_BEST_PRACTICES.md)** | Web layer implementation patterns |

## 🚀 Quick Start

### For New Developers
1. Read **[`/CLAUDE.md`](../CLAUDE.md)** for essential commands and architecture overview
2. Check **[ARCHITECTURE.md](ARCHITECTURE.md)** for technical patterns
3. Reference **[TEAM_STYLE_GUIDE.md](TEAM_STYLE_GUIDE.md)** for code standards

### For Operations/Deployment
1. Follow **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** for production setup
2. Reference **[OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md)** for troubleshooting

### For Quality Assurance
- Run `./scripts/quality_check.sh` for automated quality gates
- Apply **[TEAM_STYLE_GUIDE.md](TEAM_STYLE_GUIDE.md)** for code reviews

## 🎯 Current Project Status

EVE DMV features:
- ✅ Real-time killmail pipeline via Broadway
- ✅ EVE SSO authentication
- ✅ Character, corporation, and system intelligence
- ✅ Battle detection and analysis
- ✅ Surveillance profiles with real-time matching
- ✅ Market pricing integration via Janice API

See **[`/CLAUDE.md`](../CLAUDE.md)** for detailed implementation status.

## 📝 Main Project Instructions

The primary development guide is located at: **[`/CLAUDE.md`](../CLAUDE.md)**

This file contains:
- Commands for setup, testing, and development
- Architecture overview and key concepts
- Essential development rules and patterns
- Environment configuration and setup
- Database operations and maintenance

---

*Documentation last updated: 2025-12-19*