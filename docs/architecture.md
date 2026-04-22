# Zuno – System Architecture

## Technology Stack

### Frontend (Flutter)
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Navigation | GoRouter |
| Local Storage | `flutter_secure_storage` / `shared_preferences` |
| AI Integration | Supabase Edge Functions (Deno/TypeScript) |
| Charts | `fl_chart` |

### Backend (Supabase)
| Layer | Technology |
|---|---|
| Platform | Supabase (Serverless) |
| Functions | Supabase Edge Functions (Deno / TypeScript) |
| Database | PostgreSQL |
| Auth | Supabase Auth (Phone OTP, Google/Apple OAuth) |
| Security | Row Level Security (RLS) |
| Encryption | Fernet (Symmetric encryption for journal notes) |

### AI Engine
| Layer | Technology |
|---|---|
| Model | Google Gemini 1.5 Flash |
| Fallback | Automatic fallback to secondary provider/model |
| Integration | `@google/generative-ai` via Edge Functions |
| Tasks | Daily insights, partner observations, cycle health tips |

---

## 3-Tier Memory Architecture

Zuno uses a hierarchical memory system to provide contextually aware insights:

```
Tier 1 — Immediate Context     → daily_logs table (last 48 hours)
Tier 2 — Short-term Patterns   → ai_summary_user_session (last 7-14 days)
Tier 3 — Relationship Context  → ai_summary_relationship_session (Long-term dynamics)
```

The `generate_daily_insight` function aggregates these tiers into a structured prompt for Gemini.

---

## Core Edge Functions

| Function Name | Description | Trigger |
|---|---|---|
| `generate_daily_insight` | Generates a warm insight + 2 swipable personalized questions | App Dashboard Load (or force refresh) |
| `generate_partner_insights` | Processes partner observations and mood trends | Weekly / On-demand |
| `generate_weekly_insights` | Summarizes the week's highs/lows for Tier 3 memory | Sunday Cron |
| `notify_partner` | Sends real-time Push Notifications for partner activity | Database Webhook / Manual Trigger |
| `generate_cycle_insight` | Analyzes cycle data to provide health and connection tips | Daily check-in / Cycle phase change |

---

## Backend Constraints & Security

| # | Rule | Implementation |
|---|---|---|
| **Privacy Gate** | Partner A cannot see Partner B's private `journal_note` or detailed `cycle_data` | PostgreSQL RLS Policies |
| **Encryption** | `journal_note` is Fernet encrypted on the device before storage | `encrypt` (Dart) & `fernet` (Deno) |
| **Data Isolation** | Users can only see data if they belong to the same `relationship_id` | RLS `EXISTS` check on `users` table |
| **AI Fallback** | Insights must never fail to load if a specific AI model is down | `generateContentWithFallback` wrapper |

