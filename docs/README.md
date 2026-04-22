# Zuno – Agent Knowledge Base

> This folder is the single source of truth for the Zuno app design and architecture.
> Feed these documents to your AI coding agent (Cursor, Copilot, Devin, etc.) to generate project code.

---

## 📁 Folder Structure

```
docs/
├── prd.md                        ← Full Product Requirements Document (v3.1)
├── architecture.md               ← Tech stack, Edge Functions, backend constraints
├── design_system.md              ← "The Digital Hearth" design system
└── database_schema.md            ← PostgreSQL schema + RLS policies
```

---

## 🚀 Quick Start Prompt for AI Agents

Copy and paste into Cursor / Copilot / Devin:

```
Act as an expert Flutter and Supabase developer. Review the architecture, PRD, and database schema in the docs/ folder for the 'Zuno' app.

Step 1: Set up the database tables and RLS policies from docs/database_schema.md.
Step 2: Implement the Supabase Edge Functions for daily insights and partner notifications.
Step 3: Create the Fernet encryption utility in Flutter for journal_note fields.
Step 4: Ensure the Flutter frontend integrates with the 3-Tier memory architecture via Edge Functions.
```

---

## 📖 Document Index

| File                                                          | Purpose                                                         |
| ------------------------------------------------------------- | --------------------------------------------------------------- |
| [prd.md](prd.md)                                         | Full PRD v3.1: onboarding, screens, AI engine, engagement, privacy   |
| [architecture.md](architecture.md)                       | Tech stack, Edge Functions, backend constraints                  |
| [design_system.md](design_system.md)                     | The Digital Hearth colors, typography, components, do/don't     |
| [database_schema.md](database_schema.md)                 | PostgreSQL DDL + Supabase RLS policies                          |

---

## 🏗️ Key Design Decisions

| Decision         | Choice             | Reason                                         |
| ---------------- | ------------------ | ---------------------------------------------- |
| State Management | Riverpod           | Scalable reactive streams for Flutter          |
| Backend          | Supabase           | Serverless Auth, DB, and Edge Functions        |
| Encryption       | Fernet (symmetric) | Field-level encryption before DB write         |
| AI Model         | Gemini 1.5 Flash   | Speed + large context window for relationship history |
| DB Auth          | Supabase Auth      | Native integration with RLS                    |
| AI Fallback      | Dual Provider      | Ensures reliability of daily insights          |

## Cycle Tracking Integration

| Feature | Description |
|---|---|
| Cycle Calendar | Visual tracking for menstruation, follicular, ovulation, and luteal phases. |
| Day Insights | AI-generated tips explaining energy levels and mood based on cycle phase. |
| Partner Education | Helps partners understand current needs and how to offer support. |
| Health Tips | Personalized care suggestions (e.g., diet, activity). |
