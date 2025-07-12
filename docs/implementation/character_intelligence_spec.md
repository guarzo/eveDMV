# Character Intelligence Specification

## Overview
The character intelligence system provides comprehensive pilot analysis for recruiters, fleet commanders, and PvP enthusiasts. This consolidates design requirements from multiple sources.

## Target Users & Use Cases

### 1. Recruiters
**Goal**: Assess pilot quality and organizational fit
**Key Questions**: 
- Is this pilot skilled and active?
- Do they fit our corporation culture?
- What's their experience level?

### 2. Fleet Commanders
**Goal**: Understand pilot capabilities for fleet assignments
**Key Questions**:
- What ships can they fly effectively?
- What's their preferred role (DPS, Logi, Tackle)?
- How do they perform under pressure?

### 3. Hunters/PvP Pilots
**Goal**: Tactical assessment for engagement decisions
**Key Questions**:
- Should I engage this target?
- What fitting are they likely using?
- Do they have backup nearby?

## Core Intelligence Elements

### 1. Combat Performance Metrics
- **K/D Ratio**: Overall and by ship class
- **ISK Efficiency**: ISK destroyed vs ISK lost  
- **Solo vs Fleet**: Percentage of solo kills
- **Average Gang Size**: Typical fleet size they fly in
- **Kill Participation**: Final blows vs assists ratio
- **Activity Heat**: Kills/losses over time periods

### 2. Ship & Fitting Analysis
- **Most Used Ships**: Top 10 by frequency with success rates
- **Ship Specialization**: Primary ship categories and roles
- **Fitting Patterns**: Common module combinations and tactical approaches
- **Meta Adaptation**: How quickly they adapt to meta changes

### 3. Tactical Behavior Analysis
- **Engagement Patterns**: Preferred engagement ranges and tactics
- **Gang Composition**: Typical fleet roles and support requirements
- **Risk Assessment**: Tendency for high-risk vs safe engagements
- **Activity Zones**: Preferred systems and regions

### 4. Corporation & Alliance Context
- **Corporation History**: Previous affiliations and tenure
- **Alliance Activity**: Participation in major conflicts
- **Leadership Roles**: FC experience or specialized roles
- **Social Connections**: Key partnerships and frequent teammates

## Implementation Features

### Hunter-Focused Quick Assessment
```
Ship               | Times Flown | Typical Fit Type    | Avg Friends | Success Rate
-------------------|-------------|--------------------:|------------:|-------------
Loki               | 47          | HAM Shield         | 3-5         | 78%
Proteus            | 23          | Blaster Armor      | Solo        | 65%
Hecate             | 19          | Rail Kite          | 2-3         | 84%
Sabre              | 12          | Standard Bubble    | 5-15        | 92%
```

### Recruiter-Focused Analysis
- Activity trends (improving/declining)
- Corporation fit assessment
- Skill progression indicators
- Leadership potential markers

### Fleet Commander Intelligence
- Ship certification levels
- Doctrine familiarity
- Communication patterns
- Reliability metrics

## Data Sources & Integration
- Killmail data for combat analysis
- Corporation history from ESI
- Ship usage patterns from killmail fitting data
- Social network analysis from frequent teammates
- Geographic patterns from system activity

## Success Metrics
- Recruitment accuracy improvement
- Fleet assignment optimization
- Tactical decision support effectiveness
- User engagement with intelligence features

---

*This specification consolidates requirements from character-intelligence-design.md and character-intelligence-hunter-focused.md*