# Zuno – Product Requirements Document (PRD) v3.0

## 1. Product Vision

Zuno is an AI-powered relationship companion that helps couples understand each other better through mood tracking, behavioral insights, and intelligent suggestions. The app combines emotional tracking, cycle awareness, and relationship intelligence in a simple, private, and non-intrusive experience.

**Tagline:** _Zuno – Understand your relationship, together._

---

## 2. Core Principles

- Extremely simple daily usage (<10 seconds)
- Emotion-first, not data-heavy
- Privacy-first design
- AI-driven insights based on real behavior
- Minimal UI (no clutter)

---

## 3. Target Users

- Couples (dating, engaged, married)
- Couples trying to conceive
- Long-distance relationships

---

## 4. Onboarding Flow

### 4.1 Welcome Screen
- Intro message
- CTA: Get Started

### 4.2 Relationship Status Options
- Dating
- Engaged
- Married
- Trying for a baby

### 4.3 Partner Invite
- Invite via link
- App usable solo but enhanced with partner

### 4.4 Goals Selection
- Improve communication
- Track moods
- Plan pregnancy
- Understand patterns
- Stay connected

### 4.5 Cycle Tracking Setup (Optional)
- Enable / Skip
- Last period date
- Cycle length (optional)

### 4.6 Privacy Preference
- Mostly private
- Balanced
- Mostly shared

---

## 5. App Navigation

Bottom Tabs (3 only):
- **Today** – Daily logging & partner status
- **Insights** – Trends & AI summaries
- **You** – Profile, privacy, journal

---

## 6. Home Screen (Today)

### 6.1 Core Inputs
- Mood (emoji tap)
- Connection (Yes/No)
- Context tags (Work, Partner, Health, etc.)

### 6.2 Partner Status
- Show partner mood
- Show if partner has logged

### 6.3 Smart Insight
- One short insight per day

---

## 7. Smart Dynamic Cards

| Card | Trigger | Content |
|---|---|---|
| Cycle Tracking | Cycle data enabled | Day of cycle, fertile window, log period |
| Pregnancy Planning | Goal = "Trying for a baby" | High fertility days, suggested intimacy timing |
| Mood + Cycle Insight | Correlation detected | "Mood drops before cycle" pattern |
| Couple Sync Card | Both users logged | Compare moods, suggest communication prompts |

> **RULE:** Show max 2–3 cards per day.

---

## 8. Insights Screen

### Weekly Summary
- Mood trend chart
- Connection frequency

### AI Insights
- Behavioral patterns
- Emotional trends

### Suggestions
- Simple actionable tips

---

## 9. Profile (You Tab)

### Sections
- Partner connection status
- Privacy settings (per-field controls)
- Reminder settings
- Journal (private notes)

---

## 10. Continuous Learning Questions

Delivered over time (not in onboarding). Format: one question at a time, tap-based answers.

Examples:
- How often do you meet?
- What causes stress?
- Cycle-related mood patterns

---

## 11. AI Personalization Engine

**Inputs:** Mood logs · Cycle data · User responses · Partner data

**Outputs:** Daily insights · Weekly summaries · Suggestions

### 3-Tier Memory Architecture

| Tier | Scope | Source Table | Refresh |
|---|---|---|---|
| Tier 1 | Today's context | `daily_logs` | Every request |
| Tier 2 | Last 7 days | `daily_logs` (aggregated) | Daily |
| Tier 3 | Long-term patterns | `ai_summaries` | Every Sunday (cron) |

---

## 12. Privacy Model

| Data Type | Default Visibility | User Override |
|---|---|---|
| Mood | Shared | Yes |
| Journal Notes | Private | Yes |
| Intimacy data | Controlled | Yes |
| Cycle data | Private | Yes |

---

## 13. Engagement & Retention

### 13.1 Daily Streak System
- Track consecutive logging days
- Display streak on home screen ("🔥 3-day connection streak")

### 13.2 Soft Gamification
- Weekly milestones ("Logged together 5 times this week")
- Gentle rewards (no aggressive gamification)

### 13.3 Partner-Based Motivation
- Notify when partner logs
- "Your partner checked in today ❤️"

### 13.4 Smart Notifications
- **Reminder:** "You usually check in around this time"
- **Couple reminder:** "Both of you haven't checked in today"
- **Encouragement:** "You've been consistent this week 👏"
- **Insight trigger:** "You've had a pattern this week worth seeing"

### 13.5 Instant Feedback Loop
After logging, show:
- Streak update
- Micro insight

---

## 14. Backend Logic Constraints

| # | Constraint | Detail |
|---|---|---|
| 1 | Privacy Gate | Django ORM must NEVER return `journal_note` or `cycle_data` to a partner query unless `is_note_private = False` |
| 2 | Encryption | Pre-save signal or custom model field runs Fernet encryption on sensitive fields before `model.save()` |
| 3 | Prompt Construction | Backend dynamically compiles AI prompt using `users`, `daily_logs`, `ai_summaries` tables for 3-tier context |

---

## 15. Success Metrics

- Daily / weekly active users
- Logging frequency (target: 3–4 logs/week/user)
- Partner connection rate
- Insight engagement rate

---

## 16. Future Scope

- Advanced pregnancy planning
- Relationship coaching AI
- Therapist integration
- Deeper analytics
