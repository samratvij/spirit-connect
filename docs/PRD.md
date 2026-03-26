# Product Requirements Document
## Spirit Connect — Personal AI Assistant

| | |
|---|---|
| **Author** | Senior Product Manager |
| **Status** | Draft v1.0 |
| **Date** | March 25, 2026 |
| **Product** | Spirit Connect |

---

## 1. Executive Summary

Spirit Connect is a private, memory-enabled personal AI assistant deployed as a mobile application. The system routes all inference through the user's own hardware, with a FastAPI backend on a personal laptop serving a Flutter frontend on iOS/Android. It is scoped exclusively for single-user personal use and prioritizes privacy, continuity of conversation context, and ease of access over a secure tunnel.

This document defines the product requirements, user stories, acceptance criteria, and success metrics for v1.

---

## 2. Problem Statement

### The Problem
Large language model assistants (ChatGPT, Claude, Gemini) are powerful but require users to share potentially sensitive personal information with third-party cloud infrastructure. There is no guarantee of data privacy, no persistent personalized memory across sessions, and no control over how that data is stored or used.

### Who Is Affected
Individuals who want the benefits of a highly capable AI assistant but:
- Handle sensitive personal, professional, or financial information
- Are privacy-conscious and distrust cloud data storage
- Want an assistant that **remembers them** across sessions, not one that forgets them every conversation

### Why It Matters
The best personal assistant is one that knows you deeply over time. Today's cloud AI products strip that possibility away by design (stateless sessions, legal liability around data retention). A personal, self-hosted assistant solves this gap.

---

## 3. Goals & Non-Goals

### Goals (v1)
| # | Goal |
|---|------|
| G1 | User can have natural, multi-turn conversations with a capable LLM via mobile |
| G2 | The assistant builds and references a long-term memory of facts about the user |
| G3 | All data stays on the user's personal hardware — zero cloud dependency |
| G4 | Access is secured via VPN + API key — only the user can reach the server |
| G5 | The user can view, edit, and delete stored memories |
| G6 | Setup is achievable by a technically proficient non-developer |

### Non-Goals (v1)
- Multi-user or family account support
- Web browser interface
- Voice input or text-to-speech output
- Cloud backup or synchronization
- Plugin / tool-calling system (web search, calendar, etc.)
- Fine-tuning or model training

---

## 4. User Personas

### Primary: "The Private Professional"
- Age: 30–50
- Profile: Knowledge worker, entrepreneur, or researcher
- Behavior: Discusses sensitive work decisions, personal health, finances with the assistant
- Pain point: "I want AI help but I don't want my data on someone else's servers"
- Technical level: Can follow setup instructions; owns a capable Apple Silicon laptop

---

## 5. User Stories

### 5.1 Chat & Response

| ID | As a user, I want to... | So that... | Priority |
|----|------------------------|------------|----------|
| US-01 | Send a message from my phone and receive a response from the LLM | I can have natural conversations | P0 |
| US-02 | See the response stream in real time (token by token) | It feels responsive and alive | P1 |
| US-03 | Have conversation history visible in the chat UI during a session | I can refer back to earlier parts of our conversation | P0 |
| US-04 | Start a new conversation / clear the current session | I can switch topics cleanly | P1 |

### 5.2 Memory

| ID | As a user, I want to... | So that... | Priority |
|----|------------------------|------------|----------|
| US-05 | Have the assistant remember facts about me across sessions | It feels like a real personal assistant, not a blank slate every time | P0 |
| US-06 | See which memories the assistant has stored about me | I have transparency into what it knows | P1 |
| US-07 | Delete specific memories | I can correct mistakes or remove outdated info | P1 |
| US-08 | Edit a memory | I can fix inaccuracies without deleting and rethinking | P2 |
| US-09 | Be shown which memories were used in a response | I can understand why the assistant said something | P2 |

### 5.3 Security & Access

| ID | As a user, I want to... | So that... | Priority |
|----|------------------------|------------|----------|
| US-10 | Access the chatbot from anywhere on my Tailscale VPN | I can use it away from home without exposing the server to the open internet | P0 |
| US-11 | Require authentication to talk to the server | No one else can use or read my assistant even if they're on my network | P0 |
| US-12 | Configure the server URL and API key in-app | I can set up the app without modifying code | P0 |

### 5.4 Settings & Control

| ID | As a user, I want to... | So that... | Priority |
|----|------------------------|------------|----------|
| US-13 | Choose which LLM model to use from a list of available Ollama models | I can switch between models easily | P2 |
| US-14 | Adjust system prompt or assistant personality | I can personalize the experience | P2 |

---

## 6. Functional Requirements

### 6.1 Chat
- **FR-01**: The app MUST send user messages to the backend `/chat` endpoint with the full current-session conversation history
- **FR-02**: The backend MUST retrieve all stored memories and inject them into the system prompt before calling Ollama
- **FR-03**: The backend MUST support streaming responses (Server-Sent Events or chunked HTTP)
- **FR-04**: The app MUST render streamed responses progressively

### 6.2 Memory Extraction
- **FR-05**: After each LLM response, the backend MUST automatically invoke a secondary LLM call to extract factual memories from the Q&A pair
- **FR-06**: Extracted memories MUST be stored as discrete bullet-point facts in SQLite
- **FR-07**: Duplicate or near-duplicate memories MUST be detected and merged or skipped
- **FR-08**: Each memory record MUST store: content, creation timestamp, last-referenced timestamp, and source turn ID

### 6.3 Memory Management
- **FR-09**: The app MUST provide a memory viewer screen listing all stored memories
- **FR-10**: The user MUST be able to delete any memory from this screen
- **FR-11**: The user MUST be able to edit the text of any memory from this screen (P2)

### 6.4 Authentication & Security
- **FR-12**: All API endpoints MUST require a valid `Authorization: Bearer <token>` header
- **FR-13**: Requests without a valid token MUST return HTTP 401
- **FR-14**: The API key MUST be stored as an environment variable on the server and as secure storage on the device (not plain text)

### 6.5 Configuration
- **FR-15**: The app MUST allow the user to configure: server base URL, API key
- **FR-16**: Settings MUST persist across app restarts

---

## 7. Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-01 | Response latency (first token) | < 3 seconds on local network |
| NFR-02 | Memory extraction time | < 5 seconds after response completes |
| NFR-03 | App startup time | < 2 seconds on modern mobile hardware |
| NFR-04 | Data residency | 100% on-device, zero cloud egress |
| NFR-05 | Auth failure response time | < 100ms |
| NFR-06 | Memory store scalability | Graceful performance up to 10,000 memory records |
| NFR-07 | Platform support | iOS 16+ and Android 12+ |

---

## 8. User Experience Requirements

- **UX-01**: Chat interface must feel native and responsive — no web-view feel
- **UX-02**: Streaming response should animate smoothly (no flicker)
- **UX-03**: Memory screen must be simple — a plain list with tap-to-edit/swipe-to-delete
- **UX-04**: Connection errors (server offline, wrong API key) must show clear, actionable error messages
- **UX-05**: The app must not require re-entering credentials after first setup

---

## 9. Acceptance Criteria (Definition of Done)

| Feature | Done When |
|---------|-----------|
| Chat | User sends message, model responds within 3s, response appears streamed in the UI |
| Memory | After a conversation about a personal fact, the next session's response references that fact without being re-told |
| Memory viewer | User can open memory screen, see all facts, delete one, and confirm it no longer affects responses |
| Auth | A request with no/wrong API key is rejected before reaching Ollama |
| Settings | User changes server URL, restarts app, and connects to the new server without re-entering the key |

---

## 10. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Memory context window overflow (too many memories) | Medium | High | Implement a cap + relevance-based pruning strategy |
| Model hallucinating false memories | Medium | High | Store memories verbatim from extraction; allow easy deletion |
| Tailscale IP change breaks connectivity | Low | Medium | Surface clear error message; allow re-config in settings |
| qwen3:35b too slow for acceptable latency | Medium | High | Measure on target hardware; document minimum specs clearly |
| Memory extraction adds too much latency | Low | Medium | Run extraction asynchronously after response is delivered |

---

## 11. Success Metrics

| Metric | Target (90 days post-launch) |
|--------|------------------------------|
| Daily chat sessions | > 1 per day (personal use) |
| Memory accumulation | > 50 memories without performance degradation |
| Zero data leaks | No conversations accessible outside Tailscale network |
| Setup time | < 30 minutes for target user persona |

---

## 12. Open Questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| OQ-01 | Should memory extraction use the same model as chat, or a smaller/faster one? | Engineering | Open |
| OQ-02 | What is the maximum number of memory tokens to inject before truncation? | Engineering | Open |
| OQ-03 | Should there be a "memory off" toggle per-session? | Product | Open |
| OQ-04 | Should the app work offline if the laptop server is unreachable? | Product | Open |
