# Spirit Connect

> A private, memory-enabled personal AI assistant — running entirely on your own hardware.

---

## What Is This?

**Spirit Connect** is a personal chatbot application that runs on your mobile phone and routes all AI inference through a server running on your own laptop. It is designed for people who want the intelligence of a large language model without sacrificing privacy or giving their data to cloud providers.

All data — conversations, memories, and configuration — lives **on your own machines**. Nothing is ever sent to a third-party cloud.

---

## Core Concept

```
 ┌─────────────────┐          Tailscale VPN          ┌────────────────────────┐
 │  Mobile App     │  ─────────────────────────────►  │  Laptop Server         │
 │  (Flutter)      │  ◄─────────────────────────────  │  (FastAPI + Ollama)    │
 │                 │        HTTPS / API Key Auth       │                        │
 └─────────────────┘                                   └────────┬───────────────┘
                                                                │
                                                   ┌───────────▼───────────┐
                                                   │  SQLite Memory Store  │
                                                   └───────────────────────┘
```

The mobile app is your interface. The laptop is your brain.

---

## Key Features

### 🧠 Persistent & Isolated Memory
After every conversation turn, the LLM automatically extracts a condensed set of facts and stores them in a local SQLite database. Memories are **isolated per persona**; the 'Assistant' persona has different memories than the 'Spirit' persona, ensuring contextually relevant assistance.

### 🖼️ Multimodal Support
Attach **images** and **text files** directly to your messages. Spirit Connect can process visuals (using vision-capable models like `qwen3.5` or `llava`) and extract text from documents to include in the conversation context.

### ⏹️ Interactive & Resilient Streaming
- **Stop Button**: Interrupt the LLM mid-sentence if the response isn't what you need.
- **Background Persistence**: The server continues saving responses even if your phone locks.
- **Auto-Sync**: The app automatically re-syncs your conversation history whenever you return from the background.

### 🔒 Private & Secure
- All inference is handled by **Ollama** running locally — no API calls to OpenAI, Anthropic, or any cloud
- Communication between phone and laptop is secured over **Tailscale** (WireGuard-based VPN)
- All API endpoints are protected by a static **Bearer token** stored on-device
- No data leaves your personal network

### 📱 Mobile-First Interface
A clean, fast Flutter app for iOS and Android. Supports:
- Conversational chat UI with smooth token streaming
- Sidebar chat history with deletion support
- Memory browser (view, edit, delete stored memories by persona)
- Settings panel (server URL, API key)

### ⚡ Powerful LLM Backend
Supports any model available in Ollama. Recommended: **qwen3.5:35b** or **qwen2-vl** for multimodal support.

---

## Project Scope

### In Scope
- FastAPI backend server (Python)
- Ollama integration for chat completion
- Automatic memory extraction and storage (SQLite)
- Memory injection into system prompt on every request
- API key authentication middleware
- Flutter mobile app with chat and memory UI
- Tailscale networking for secure remote access

### Out of Scope (v1)
- Multi-user support
- Web UI
- Cloud backup or sync
- Voice input/output
- Plugin or tool-use system
- Fine-tuning or model customization

---

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| Laptop CPU/GPU | Apple M2 or NVIDIA RTX 3080 | Apple M3 Max / M4 Pro |
| RAM | 32 GB | 64 GB |
| Storage | 40 GB free | 80 GB free |
| Mobile OS | iOS 16 / Android 12 | Latest |
| Network | Tailscale on both devices | — |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| LLM Runtime | Ollama (`qwen3:35b`) |
| Backend | Python, FastAPI |
| Memory Store | SQLite + SQLAlchemy |
| Mobile App | Flutter (Dart) |
| Networking | Tailscale (WireGuard VPN) |
| Auth | Static Bearer token (env var) |

---

## Project Structure

```
spirit-connect/
├── server/                  # FastAPI backend
│   ├── main.py              # App entrypoint
│   ├── routes/
│   │   ├── chat.py          # Chat completion endpoint
│   │   └── memory.py        # Memory CRUD endpoints
│   ├── services/
│   │   ├── ollama.py        # Ollama API client
│   │   └── memory.py        # Memory extraction logic
│   ├── models/
│   │   └── db.py            # SQLAlchemy models
│   ├── middleware/
│   │   └── auth.py          # API key middleware
│   ├── .env.example
│   └── requirements.txt
│
├── mobile/                  # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── chat_screen.dart
│   │   │   ├── memory_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── services/
│   │   │   └── api_service.dart
│   │   └── models/
│   │       ├── message.dart
│   │       └── memory.dart
│   └── pubspec.yaml
│
├── docs/
│   ├── PRD.md               # Product Requirements Document
│   └── TSD.md               # Technical Solution Document
│
└── README.md
```

---

## Getting Started

> ⚠️ Full setup instructions will be in `docs/TSD.md`

**Quick overview:**
1. Install Ollama and pull the model: `ollama pull qwen3.5:35b`
2. Install Python dependencies and start the server: `uvicorn main:app`
3. Install the Flutter app on your phone
4. Connect both devices to the same Tailscale network
5. Enter your laptop's Tailscale IP + API key in the app's settings

---

## Privacy Guarantee

Spirit Connect is built on a simple principle: **you own your data**.

- No telemetry
- No analytics
- No cloud dependencies
- Fully open-source

---

## License

MIT License — see `LICENSE` for details.
