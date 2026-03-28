# Zuno – Architecture Diagrams

## 1. System Topology

```mermaid
graph TD
    %% Client Layer
    subgraph Client ["🖥️ Client Layer"]
        F_APP["Flutter Mobile App\n(iOS / Android)"]
        W_WIDGET["OS Widgets\n(Lock / Home Screen)"]
        F_APP --- W_WIDGET
    end

    %% API / Gateway Layer
    subgraph API_Layer ["⚙️ API & Backend Layer — Google Cloud Run"]
        D_API["Python Django REST API"]
        E_MOD["🔒 Encryption Module\n(Cryptography / Fernet)"]
        AI_SERV["🤖 AI Context Manager\n& Aggregator"]

        D_API <--> E_MOD
        D_API <--> AI_SERV
    end

    %% Database Layer
    subgraph Database ["🗄️ Data Layer — Supabase"]
        PG[("PostgreSQL DB")]
        RLS{"🔒 Row Level Security"}
        PG --- RLS
    end

    %% External Services
    subgraph External ["🌐 External Services"]
        GEMINI["Google Gemini API\n2.5 Flash"]
        PUSH["FCM / APNs\nPush Notifications"]
    end

    %% Connections
    F_APP -- "HTTPS / REST" --> D_API
    D_API -- "SQL / TCP" --> PG
    AI_SERV -- "Prompt JSON" --> GEMINI
    D_API -- "Trigger" --> PUSH

    classDef secure fill:#f9f,stroke:#333,stroke-width:2px;
    class E_MOD,RLS secure;
```

---

## 2. Onboarding State Machine

```mermaid
stateDiagram-v2
    [*] --> Welcome
    Welcome --> RelationshipStatus : Get Started
    RelationshipStatus --> PartnerInvite
    PartnerInvite --> GoalsSelection
    GoalsSelection --> CycleSetup : Optional
    GoalsSelection --> PrivacyPreference : Skip cycle
    CycleSetup --> PrivacyPreference
    PrivacyPreference --> HomeScreen
    HomeScreen --> [*]
```

---

## 3. Daily Logging Flow

```mermaid
sequenceDiagram
    participant User as 👤 User (Flutter)
    participant API as Django API
    participant Enc as Encryption Module
    participant DB as Supabase PostgreSQL
    participant AI as Gemini 2.5 Flash

    User->>API: POST /api/v1/logs/daily
    API->>Enc: Encrypt journal_note & cycle_data
    Enc-->>API: Encrypted payload
    API->>DB: INSERT daily_log record
    DB-->>API: Saved + streak data
    API->>AI: GET /api/v1/dashboard/today (3-tier prompt)
    AI-->>API: Dynamic card content
    API-->>User: { streak, dynamic_cards }
```

---

## 4. 3-Tier AI Memory Architecture

```mermaid
graph LR
    subgraph T1 ["Tier 1 — Today"]
        L1["daily_logs\n(today)"]
    end
    subgraph T2 ["Tier 2 — Last 7 Days"]
        L2["daily_logs\n(aggregated)"]
    end
    subgraph T3 ["Tier 3 — Long-Term"]
        L3["ai_summaries\n(Sunday cron)"]
    end

    T1 --> CTX["AI Context\nManager"]
    T2 --> CTX
    T3 --> CTX
    CTX --> GEMINI["Gemini 2.5 Flash\nPrompt"]
    GEMINI --> CARDS["Dynamic UI Cards"]
```

---

## 5. Privacy Data Flow

```mermaid
graph TD
    LOG["Daily Log Entry"] --> PRIV{is_note_private?}
    PRIV -- "true (default)" --> SELF_ONLY["Visible to self only\n✅ User · ❌ Partner"]
    PRIV -- "false" --> SHARED["Visible to both\n✅ User · ✅ Partner"]

    CYCLEDATA["Cycle Data"] --> RLS{"Row Level Security\n(Supabase)"}
    RLS -- "Partner query" --> BLOCKED["❌ Blocked — private by default"]
    RLS -- "Self query" --> ALLOWED["✅ Returned"]
```
