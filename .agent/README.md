# Zuno – Agent Knowledge Base

> This folder is the single source of truth for the Zuno app design and architecture.
> Feed these documents to your AI coding agent (Cursor, Copilot, Devin, etc.) to generate project code.

---

## 📁 Folder Structure

```
.agent/
├── README.md                         ← This file
├── docs/
│   ├── prd.md                        ← Full Product Requirements Document (v3.0)
│   ├── architecture.md               ← Tech stack, API endpoints, backend constraints
│   ├── design_system.md              ← "The Digital Hearth" design system
│   └── database_schema.md            ← PostgreSQL schema + RLS policies
└── diagrams/
    └── architecture_diagrams.md      ← Mermaid diagrams (system topology, data flows)
```

---

## 🚀 Quick Start Prompt for AI Agents

Copy and paste into Cursor / Copilot / Devin:

```
Act as an expert Full-Stack developer. Review the architecture, PRD, and API spec in the .agent/docs/ folder for the 'Zuno' app.

Step 1: Initialize the Python Django backend project.
Step 2: Set up the database models from .agent/docs/database_schema.md reflecting the 3-Tier memory architecture.
Step 3: Create the Fernet encryption utility function for journal_note and cycle_data fields.
Step 4: Implement the privacy gate — the Django ORM must NEVER return journal_note or cycle_data to a partner query unless is_note_private = False.
```

---

## 📖 Document Index

| File | Purpose |
|---|---|
| [prd.md](docs/prd.md) | Full PRD: onboarding, screens, AI engine, engagement, privacy |
| [architecture.md](docs/architecture.md) | Tech stack, all API endpoints, backend constraints |
| [design_system.md](docs/design_system.md) | The Digital Hearth colors, typography, components, do/don't |
| [database_schema.md](docs/database_schema.md) | PostgreSQL DDL + Supabase RLS policies |
| [architecture_diagrams.md](diagrams/architecture_diagrams.md) | Mermaid: system topology, state machine, sequence, privacy flow |

---

## 🏗️ Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| State Management | Riverpod | Scalable reactive streams for Flutter |
| Backend | Django + DRF | Rapid REST API + ORM for complex queries |
| Encryption | Fernet (symmetric) | Field-level encryption before DB write |
| AI Model | Gemini 2.5 Flash | Speed + multimodal capability |
| DB Auth | Supabase RLS | Row-level privacy without app-layer complexity |
| Async Tasks | Celery + Redis | Sunday cron for Tier 3 AI summaries |
