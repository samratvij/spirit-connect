# Technical Solution Document
## Spirit Connect — Personal AI Assistant

| | |
|---|---|
| **Author** | Principal Software Developer |
| **Status** | Draft v1.0 |
| **Date** | March 25, 2026 |
| **Related** | PRD v1.0 |

---

## 1. System Overview

Spirit Connect is a two-tier system: a **Python FastAPI server** running on a personal laptop, and a **Flutter mobile client** connecting to it over a Tailscale VPN. All AI inference is delegated to **Ollama** running locally. Memory is persisted in a **SQLite** database on the laptop.

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                        MOBILE (Flutter)                       │
│                                                              │
│  ┌─────────────┐   ┌───────────────┐   ┌─────────────────┐  │
│  │ Chat Screen │   │ Memory Screen │   │ Settings Screen │  │
│  └──────┬──────┘   └───────┬───────┘   └────────┬────────┘  │
│         └──────────────────┴────────────────────┘           │
│                      ApiService (Dart)                        │
│                  Bearer token + base URL                      │
└───────────────────────────┬──────────────────────────────────┘
                            │ HTTPS over Tailscale VPN
                            │ (100.x.x.x:8000)
┌───────────────────────────▼──────────────────────────────────┐
│                    LAPTOP SERVER (FastAPI)                     │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Auth Middleware (Bearer token)            │ │
│  └───────────────────────────┬─────────────────────────────┘ │
│              ┌───────────────┴───────────────┐               │
│   ┌──────────▼──────────┐      ┌─────────────▼────────────┐  │
│   │  POST /chat          │      │  GET/PUT/DEL /memory     │  │
│   │  (streaming response)│      │  (memory CRUD)           │  │
│   └──────────┬──────────┘      └─────────────┬────────────┘  │
│              │                               │               │
│   ┌──────────▼──────────────────────────────▼────────────┐  │
│   │               OllamaService                           │  │
│   │   (chat completion + memory extraction calls)         │  │
│   └──────────┬────────────────────────────────────────────┘  │
│              │                                               │
│   ┌──────────▼────────────┐   ┌────────────────────────────┐ │
│   │  Ollama (qwen3:35b)   │   │  SQLite (memories.db)       │ │
│   │  localhost:11434      │   │  MemoryService (SQLAlchemy) │ │
│   └───────────────────────┘   └────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Technology Stack

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| LLM Runtime | Ollama | Latest | Local model serving, simple REST API |
| LLM Model | qwen3:35b | Latest | High capability, open weights |
| Backend language | Python | 3.11+ | Best LLM ecosystem; async support |
| Web framework | FastAPI | 0.110+ | Async, streaming SSE, auto-docs |
| ORM | SQLAlchemy (async) | 2.x | Type-safe, migration-friendly |
| Database | SQLite | 3.x | Zero-config, local, sufficient for personal use |
| Mobile framework | Flutter | 3.x | Single codebase for iOS + Android |
| HTTP client (mobile) | `dio` | Latest | Streaming support, interceptors for auth |
| Secure storage (mobile) | `flutter_secure_storage` | Latest | Keychain/Keystore backed credential storage |
| VPN | Tailscale | Latest | Zero-config WireGuard mesh VPN |
| Package manager | `uv` (Python) | Latest | Fast, deterministic dependency resolution |

---

## 3. Backend Design

### 3.1 Directory Structure

```
server/
├── main.py                  # FastAPI app factory, lifespan, router registration
├── config.py                # Settings via pydantic-settings (.env parsing)
├── database.py              # Async SQLAlchemy engine + session factory
│
├── middleware/
│   └── auth.py              # BearerTokenMiddleware
│
├── routes/
│   ├── chat.py              # POST /chat  (streaming)
│   └── memory.py            # GET/POST/PUT/DELETE /memory
│
├── services/
│   ├── ollama.py            # Ollama HTTP client (chat + extraction)
│   └── memory_service.py    # Memory DB CRUD + injection logic
│
├── models/
│   └── db.py                # SQLAlchemy ORM model: Memory
│
├── schemas/
│   ├── chat.py              # ChatRequest, ChatMessage pydantic models
│   └── memory.py            # MemoryRecord, MemoryCreate pydantic models
│
├── .env.example
└── requirements.txt
```

### 3.2 Configuration (`.env`)

```env
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_CHAT_MODEL=qwen3:35b
OLLAMA_MEMORY_MODEL=qwen3:35b      # can be a smaller model later
API_SECRET_KEY=<generate a strong random token>
DATABASE_URL=sqlite+aiosqlite:///./data/memories.db
MAX_MEMORY_TOKENS=2000             # soft cap on injected memory size
```

### 3.3 Database Schema

```sql
CREATE TABLE memories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    content     TEXT    NOT NULL,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_used   DATETIME,
    source_turn TEXT    -- JSON blob: {user_msg, assistant_msg}
);
```

No vector embeddings in v1. Memory recall is full-injection (all memories into system prompt). If the total token count of memories approaches `MAX_MEMORY_TOKENS`, older/less-recently-used memories are trimmed first.

### 3.4 API Endpoints

#### `POST /chat`
Streams an AI response.

**Request:**
```json
{
  "messages": [
    {"role": "user", "content": "What should I have for dinner?"},
    {"role": "assistant", "content": "How about pasta?"},
    {"role": "user", "content": "I'm gluten intolerant actually"}
  ]
}
```

**Processing flow:**
1. Auth middleware validates Bearer token
2. Fetch all memories from DB → format as system prompt block
3. Build full message list: `[system_memory_prompt] + messages`
4. Stream Ollama response back to client via SSE
5. After stream completes: fire-and-forget background task → memory extraction

**Response:** `text/event-stream` (SSE)
```
data: {"delta": "How about"}
data: {"delta": " rice"}
data: [DONE]
```

#### Memory Extraction (internal, background)

After each chat turn, a separate Ollama call is made with a dedicated extraction prompt:

```
System: You are a memory extraction assistant. Extract any personal facts, 
preferences, or important context from the following conversation turn. 
Output as a JSON array of short declarative sentences. 
Output [] if nothing worth remembering was said.
Output only JSON.

User turn: "<user message>"
Assistant turn: "<assistant response>"
```

Each extracted fact is checked for semantic similarity against existing memories (simple string matching in v1; vector similarity in v2). New or updated facts are upserted.

#### `GET /memory`
Returns all stored memories, sorted by `updated_at` descending.

**Response:**
```json
[
  {
    "id": 12,
    "content": "User is gluten intolerant.",
    "created_at": "2026-03-25T22:00:00",
    "updated_at": "2026-03-25T22:00:00",
    "last_used": "2026-03-25T22:15:00"
  }
]
```

#### `PUT /memory/{id}`
Update the content of a memory record.

#### `DELETE /memory/{id}`
Delete a memory record by ID.

### 3.5 Authentication Middleware

```python
class BearerTokenMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path in ["/health", "/docs", "/openapi.json"]:
            return await call_next(request)
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer ") or auth[7:] != settings.API_SECRET_KEY:
            return JSONResponse({"detail": "Unauthorized"}, status_code=401)
        return await call_next(request)
```

### 3.6 System Prompt Construction

```
You are a highly knowledgeable personal AI assistant.

## What You Know About The User
- User is gluten intolerant.
- User prefers concise answers.
- User works in software engineering.
- User exercises in the mornings.

Use this context naturally in your responses. Do not explicitly enumerate these 
facts back to the user unless asked. Prioritize being helpful over being formal.
```

This block is prepended as a `system` role message to every Ollama call.

---

## 4. Mobile App Design

### 4.1 Directory Structure

```
mobile/lib/
├── main.dart
├── app.dart                  # MaterialApp, theme, routing
│
├── screens/
│   ├── chat_screen.dart      # Main chat UI
│   ├── memory_screen.dart    # Memory browser
│   └── settings_screen.dart  # Server URL + API key config
│
├── services/
│   └── api_service.dart      # Dio HTTP client, SSE streaming
│
├── models/
│   ├── message.dart          # ChatMessage model
│   └── memory.dart           # MemoryRecord model
│
├── widgets/
│   ├── message_bubble.dart   # Single chat bubble
│   ├── memory_tile.dart      # Memory list item
│   └── streaming_indicator.dart
│
└── providers/
    ├── chat_provider.dart    # State management for chat
    └── memory_provider.dart  # State management for memory list
```

### 4.2 State Management

Use **Riverpod** for its simplicity and testability at this scale. Two primary providers:

- `chatProvider`: manages `List<ChatMessage>`, streaming state, error state
- `memoryProvider`: manages `List<MemoryRecord>`, loading/success/error states

### 4.3 SSE Streaming (Dart)

```dart
final stream = dio.get<ResponseBody>(
  '$baseUrl/chat',
  data: requestBody,
  options: Options(responseType: ResponseType.stream),
);
stream.listen((chunk) {
  final lines = utf8.decode(chunk).split('\n');
  for (final line in lines) {
    if (line.startsWith('data: ') && line != 'data: [DONE]') {
      final json = jsonDecode(line.substring(6));
      // append delta to current message
    }
  }
});
```

### 4.4 Secure Credential Storage

API key and server URL stored via `flutter_secure_storage`:
- iOS: Keychain
- Android: Android Keystore-backed `EncryptedSharedPreferences`

Never stored in plain `SharedPreferences`.

---

## 5. Networking & Security

### 5.1 Tailscale Setup

1. Install Tailscale on both laptop and phone
2. Log in to the **same Tailscale account** on both devices
3. The laptop gets a stable Tailscale IP (e.g. `100.64.0.1`)
4. FastAPI binds to `0.0.0.0:8000`; Tailscale firewall naturally limits access to VPN peers only
5. No port forwarding, no firewall rules beyond Tailscale defaults

> Note: The user already uses Tailscale for Immich. Spirit Connect simply uses a different port (`8000`) on the same Tailscale IP. No additional configuration on the Tailscale account is needed.

### 5.2 HTTPS (Optional but Recommended)

For v1, Tailscale provides end-to-end WireGuard encryption, making plain HTTP over Tailscale already safe. However, for defense-in-depth:

- Use `mkcert` to generate a locally-trusted TLS certificate
- Configure `uvicorn` with `--ssl-keyfile` and `--ssl-certfile`
- The Flutter app must trust the certificate (use `SecurityContext` in Dart)

This is a v1.5 improvement; document it but don't block on it.

### 5.3 API Key Generation

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Store in `.env` on server. Enter manually in app settings on first launch.

---

## 6. Memory System Deep Dive

### 6.1 Extraction Prompt Design

The extraction prompt uses a strict JSON-only output contract to prevent parsing failures. Temperature should be set low (`0.1`) for this call to ensure deterministic output.

```python
EXTRACTION_SYSTEM_PROMPT = """
You are a personal memory extraction assistant.

Given a single conversation exchange (one user message and one assistant response), 
extract discrete factual statements about the USER that are worth remembering for 
future conversations.

Rules:
- Output ONLY a valid JSON array of strings
- Each string is one short declarative fact about the user
- Write facts in third person: "User prefers X", "User works at Y", "User is Z"
- Exclude generic statements, assistant responses, or questions
- If nothing worth remembering: output []
- Maximum 5 facts per turn

Example output:
["User is gluten intolerant.", "User prefers concise answers."]
"""
```

### 6.2 Deduplication Strategy (v1)

Simple substring matching:
- Before inserting a new fact, check if any existing memory contains 80%+ of the same key words
- If so, update the existing record's `content` and `updated_at` instead of inserting

### 6.3 Context Window Management

Before building the system prompt:
1. Fetch all memories, sorted by `last_used DESC, updated_at DESC`
2. Estimate token count (heuristic: 1 token ≈ 4 characters)
3. Include memories greedily until `MAX_MEMORY_TOKENS` is reached
4. Truncated memories are not deleted — just not injected this turn

---

## 7. Error Handling Strategy

| Scenario | Server Behavior | Client Behavior |
|----------|----------------|-----------------|
| Ollama not running | 503 with message | "AI server unavailable" toast |
| Wrong API key | 401 Unauthorized | Redirect to settings screen |
| Memory DB locked | Log warning, skip extraction | Silent (don't block chat) |
| Server unreachable (laptop off) | — | "Cannot connect" with retry |
| Stream interrupted mid-response | Close SSE connection | Show partial response + error indicator |
| Memory extraction fails | Log error, skip | Silent (don't block chat) |

---

## 8. Setup & Deployment

### 8.1 Server Setup (Laptop)

```bash
# 1. Install Ollama
brew install ollama
ollama pull qwen3:35b  # NOTE: confirm exact model tag

# 2. Clone repo and navigate to server
cd spirit-connect/server

# 3. Install Python deps
pip install uv
uv sync

# 4. Configure environment
cp .env.example .env
# Edit .env: set API_SECRET_KEY to your generated token

# 5. Run server
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 8.2 Auto-start on macOS (launchd)

Create a `launchd` plist at `~/Library/LaunchAgents/com.spiritconnect.server.plist` to start the server automatically at login. Template to be provided in `server/launchd/`.

### 8.3 Mobile App Setup

```bash
cd spirit-connect/mobile
flutter pub get
flutter run          # for dev
flutter build ios    # for production (requires Xcode)
flutter build apk    # for Android
```

On first launch:
1. Open Settings screen
2. Enter Tailscale IP of laptop: `http://100.x.x.x:8000`
3. Enter API key (from `.env`)
4. Tap "Test Connection" — should return 200 OK

---

## 9. Future Considerations (v2+)

| Feature | Approach |
|---------|---------|
| Semantic memory search | Add `chromadb` vector store; embed memories with `nomic-embed-text` via Ollama |
| Smaller memory extraction model | Use `qwen2.5:3b` or `llama3.2:3b` for extraction to reduce latency |
| Memory categories / tags | Add `category` field to DB; filter injection by relevance |
| Voice input | Integrate `whisper` (via Ollama or standalone) on the server; push-to-talk in app |
| Conversation history persistence | Store full chat logs in DB; allow browsing past conversations |
| HTTPS with cert | `mkcert` + uvicorn SSL args + Dart `SecurityContext` |
| Multi-model switching | Endpoint to list `ollama list` output; model selector in settings |

---

## 10. Testing Strategy

### Unit Tests (Python)
- Memory extraction parsing: valid JSON, empty array, malformed responses
- Deduplication logic: exact match, partial match, no match
- Auth middleware: valid token, missing header, wrong token
- System prompt construction: memory truncation at token limit

### Integration Tests
- Full chat flow: message → Ollama → stream → extraction → DB
- Memory CRUD: create, read, update, delete via API

### Mobile Tests
- Widget tests: chat bubble rendering, memory tile
- Integration test: send message → assert response appears in UI

### Manual Testing Checklist
- [ ] Server starts with no errors
- [ ] Chat works end-to-end on local network
- [ ] Chat works over Tailscale VPN (phone on LTE)
- [ ] Wrong API key is rejected
- [ ] A stated fact reappears in next session without re-telling
- [ ] Deleting a memory removes it from next session's context
- [ ] App handles server-offline gracefully
