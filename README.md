# Zuno

Zuno is an AI-powered relationship companion designed to help couples deepen their connection through mood tracking, cycle awareness, and intelligent, empathetic insights.

## ✨ Features

- **Mood Spectrum:** A continuous slider to track energy and mood accurately.
- **AI Daily Insights:** Personalized relationship reflections powered by Gemini.
- **Daily Questions:** AI-generated swipable questions to spark meaningful conversations.
- **Partner Observations:** A structured way to check in on how your partner is vibing.
- **Cycle Tracking:** Integrated cycle awareness for both partners, providing health and connection tips.

## 🛠️ Technology Stack

- **Frontend:** [Flutter](https://flutter.dev/) with Riverpod for state management.
- **Backend:** [Supabase](https://supabase.com/) for Database, Auth, and Edge Functions.
- **AI:** Google Gemini 1.5 Flash.
- **Cloud:** Serverless infrastructure via Supabase Edge Functions.

## 📖 Documentation

For detailed information on the system architecture and design, see the `docs` folder:

- [System Architecture](docs/architecture.md)
- [Database Schema](docs/database_schema.md)
- [Product Requirements (PRD)](docs/prd.md)
- [Design System](docs/design_system.md)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Supabase CLI (if working on Edge Functions)

### Setup

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/Jishnu-mulachan-personal/zuno.git
    cd zuno
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Environment Variables**:
    Create a `.env` file in the root directory and add your Supabase credentials:
    ```env
    SUPABASE_URL=your_supabase_url
    SUPABASE_ANON_KEY=your_supabase_anon_key
    FERNET_KEY=your_fernet_encryption_key
    ```

4.  **Run the app**:
    ```bash
    flutter run
    ```

## 🔐 Security & Privacy

Zuno uses field-level Fernet encryption for journal notes and Row Level Security (RLS) in PostgreSQL to ensure that private data stays private. Partner communication is only enabled after both users are linked to a shared `relationship_id`.

---
*Built with ❤️ for couples everywhere.*
