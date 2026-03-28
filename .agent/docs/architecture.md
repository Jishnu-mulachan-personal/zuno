# Zuno – System Architecture

## Technology Stack

### Frontend (Flutter)
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State Management | Riverpod (preferred) or BLoC |
| Local Storage | Hive / Flutter Secure Storage |
| HTTP Client | Dio (with auth interceptors) |
| Charts | fl_chart |

### Backend (Python)
| Layer | Technology |
|---|---|
| Language | Python 3.12+ |
| Framework | FastAPI |
| Hosting | Google Cloud Run (Dockerized, serverless) |
| Async Tasks | Celery + Redis |
| Encryption | `cryptography` (Fernet symmetric encryption) |

### Data & Auth
| Layer | Technology |
|---|---|
| Platform | Supabase |
| Database | PostgreSQL |
| Auth | Firebase Phone number based and social login|
| Security | Row Level Security (RLS) |

### AI Engine
| Layer | Technology |
|---|---|
| Model | Google Gemini 2.5 Flash |
| SDK | `google-genai` Python SDK |
| Scheduling | Celery + Redis (Sunday cron for Tier 3 summaries) |

---

## 3-Tier Memory Architecture

```
Tier 1 — Today's Context        → daily_logs table         (every request)
Tier 2 — Last 7 Days            → daily_logs (aggregated)  (daily refresh)
Tier 3 — Long-term Patterns     → ai_summaries table       (Sunday cron)
```

The `/api/v1/dashboard/today` endpoint combines all three tiers into a single Gemini prompt context.

---

## Core API Endpoints

### Auth & Onboarding
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/v1/auth/register` | Creates user in Supabase + `users` table |
| POST | `/api/v1/couple/invite` | Generates secure invite link for Partner B |
| POST | `/api/v1/couple/join` | Links Partner B to Partner A's `relationship_id` |

### Daily Logging
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/v1/logs/daily` | Encrypt & save daily log, return streak update |
| GET | `/api/v1/logs/history?days=7` | Fetch last N days for both users (privacy filtered) |

#### POST `/api/v1/logs/daily` — Payload
```json
{
  "mood_emoji": "😔",
  "connection_felt": false,
  "context_tags": ["Work"],
  "journal_note": "Long day",
  "is_note_private": true
}
```

### Dashboard & AI
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/v1/dashboard/today` | Fetch 3-tier context → call Gemini → return dynamic UI state |
| POST | `/api/v1/insights/generate-weekly-summary` | Internal cron — batch-process Tier 3 memories |

#### GET `/api/v1/dashboard/today` — Response
```json
{
  "partner_status": {
    "logged_today": true,
    "mood": "🙂"
  },
  "dynamic_cards": [
    {"type": "insight", "content": "You both logged high stress today. Consider a quiet night in."},
    {"type": "cycle", "content": "Day 14. Approaching fertile window."}
  ]
}
```

---

## Backend Constraints

| # | Rule | Implementation |
|---|---|---|
| **Privacy Gate** | Never return `journal_note` or `cycle_data` to partner unless `is_note_private = False` | Django ORM queryset filter |
| **Encryption** | Fernet encrypt sensitive fields before save | Django pre-save signal or custom model field |
| **Prompt Construction** | Dynamically compile `users` + `daily_logs` + `ai_summaries` into prompt | `AI_SERV` context manager module |
