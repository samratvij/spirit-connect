"""
Memory service — handles:
- CRUD operations on the memories SQLite table
- Memory extraction from a conversation turn (via Ollama)
- Deduplication of extracted memories
- Building the system prompt block from stored memories
"""

import json
import logging
from datetime import datetime, timezone

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from models.db import Memory
from services import ollama

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Extraction prompt
# ---------------------------------------------------------------------------

EXTRACTION_SYSTEM_PROMPT = """You are a personal memory manager. 

Your goal is to maintain a clean, unique, and condensed set of factual memories about the USER.

INPUT:
1. EXISTING MEMORIES: A list of things already known about the user.
2. NEW CONVERSATION: A recent exchange between the user and assistant.

TASK:
Identify any NEW facts or UPDATES to existing facts from the new conversation.

RULES:
- Output ONLY a valid JSON object with two keys: "new_facts" (list of strings) and "updates" (list of objects with "id" and "content").
- DO NOT repeat information already in EXISTING MEMORIES.
- DO NOT store or extract information about the ASSISTANT, its personality, its rules, or its role. Only store facts about the USER (e.g., preferences, history, bio, location).
- **CRITICAL: Derive facts ONLY from what the USER has stated or confirmed.** The assistant's messages are for context only. If the assistant suggests a fact ("You sound hungry") but the user doesn't confirm it, do NOT store it.
- If a new fact contradicts or provides a better/more recent version of an existing memory, put it in "updates" with that memory's ID.
- Keep facts short, third-party ("User likes X"), and important.
- If no new info, return {"new_facts": [], "updates": []}

EXAMPLE OUTPUT:
{
  "new_facts": ["User recently started learning piano."],
  "updates": [{"id": 5, "content": "User now lives in New York (moved from Boston)."}]
}"""


# ---------------------------------------------------------------------------
# System prompt builder
# ---------------------------------------------------------------------------

MEMORY_BLOCK_HEADER = "### USER CONTEXT (Memories)\n"

NO_MEMORY_BLOCK = ""


async def build_system_prompt(db: AsyncSession, persona_id: str, query: str | None = None) -> str:
    """
    Construct the memory context block.
    If 'query' is provided, performs semantic retrieval.
    Otherwise, returns most recent memories.
    """
    if query:
        memories = await find_relevant_memories(db, query, persona_id, limit=10)
    else:
        memories = await get_all_memories(db, persona_id)

    if not memories:
        return NO_MEMORY_BLOCK

    lines = [f"- {m.content}" for m in memories]
    full_block = MEMORY_BLOCK_HEADER + "\n".join(lines)

    # Soft token cap: ~4 chars per token heuristic
    max_chars = settings.max_memory_tokens * 4
    if len(full_block) <= max_chars:
        return full_block

    # Trim from the end (least recently used are last in the sorted list)
    trimmed_lines = []
    running = len(MEMORY_BLOCK_HEADER)
    for line in lines:
        if running + len(line) + 1 > max_chars:
            break
        trimmed_lines.append(line)
        running += len(line) + 1

    return MEMORY_BLOCK_HEADER + "\n".join(trimmed_lines)


# ---------------------------------------------------------------------------
# CRUD
# ---------------------------------------------------------------------------

async def get_all_memories(db: AsyncSession, persona_id: str | None = None) -> list[Memory]:
    """Return memories, optionally filtered by persona, most recently used / updated first."""
    stmt = select(Memory).order_by(Memory.last_used.desc().nullslast(), Memory.updated_at.desc())
    if persona_id:
        stmt = stmt.where(Memory.persona_id == persona_id)
    
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_memory_by_id(db: AsyncSession, memory_id: int) -> Memory | None:
    result = await db.execute(select(Memory).where(Memory.id == memory_id))
    return result.scalar_one_or_none()


async def create_memory(db: AsyncSession, content: str, persona_id: str, source_turn: dict | None = None) -> Memory:
    embedding = await ollama.embed(content)
    memory = Memory(
        content=content,
        persona_id=persona_id,
        source_turn=json.dumps(source_turn) if source_turn else None,
        embedding=json.dumps(embedding).encode("utf-8"),
    )
    db.add(memory)
    await db.commit()
    await db.refresh(memory)
    return memory


async def update_memory_content(db: AsyncSession, memory_id: int, content: str) -> Memory | None:
    embedding = await ollama.embed(content)
    await db.execute(
        update(Memory)
        .where(Memory.id == memory_id)
        .values(
            content=content, 
            updated_at=datetime.now(timezone.utc),
            embedding=json.dumps(embedding).encode("utf-8"),
        )
    )
    await db.commit()
    return await get_memory_by_id(db, memory_id)


def _cosine_similarity(v1: list[float], v2: list[float]) -> float:
    if not v1 or not v2 or len(v1) != len(v2):
        return 0.0
    dot_product = sum(a * b for a, b in zip(v1, v2))
    magnitude1 = sum(a * a for a in v1) ** 0.5
    magnitude2 = sum(a * a for a in v2) ** 0.5
    if magnitude1 == 0 or magnitude2 == 0:
        return 0.0
    return dot_product / (magnitude1 * magnitude2)


async def find_relevant_memories(db: AsyncSession, query: str, persona_id: str, limit: int = 5) -> list[Memory]:
    """
    Find the top N memories most semantically similar to the query.
    """
    all_memories = await get_all_memories(db, persona_id)
    if not all_memories:
        return []

    query_vec = await ollama.embed(query)
    
    scored_memories = []
    for m in all_memories:
        if not m.embedding:
            continue
        try:
            m_vec = json.loads(m.embedding.decode("utf-8"))
            score = _cosine_similarity(query_vec, m_vec)
            scored_memories.append((score, m))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue

    # Sort by score descending
    scored_memories.sort(key=lambda x: x[0], reverse=True)
    return [m for score, m in scored_memories[:limit]]


async def delete_memory(db: AsyncSession, memory_id: int) -> bool:
    result = await db.execute(delete(Memory).where(Memory.id == memory_id))
    await db.commit()
    return result.rowcount > 0


async def mark_memories_used(db: AsyncSession):
    """Update last_used timestamp for all memories (called after each chat turn)."""
    await db.execute(
        update(Memory).values(last_used=datetime.now(timezone.utc))
    )
    await db.commit()


# ---------------------------------------------------------------------------
# Extraction & deduplication
# ---------------------------------------------------------------------------



async def extract_and_store_memories(
    db: AsyncSession,
    user_message: str,
    assistant_message: str,
    persona_id: str,
):
    """
    Run memory extraction on a completed Q&A turn and persist results.
    Considers existing memories to avoid duplicates and perform updates.
    """
    # Load all existing memories for context
    existing_memories = await get_all_memories(db, persona_id)
    
    # Format existing memories for the prompt (ID: Content)
    memories_context = "\n".join([f"{m.id}: {m.content}" for m in existing_memories])
    if not memories_context:
        memories_context = "(No existing memories)"

    extraction_messages = [
        {"role": "system", "content": EXTRACTION_SYSTEM_PROMPT},
        {
            "role": "user",
            "content": (
                f"### EXISTING MEMORIES\n{memories_context}\n\n"
                f'### NEW CONVERSATION\nUser: "{user_message}"\nAssistant: "{assistant_message}"'
            ),
        },
    ]

    try:
        raw = await ollama.complete(extraction_messages)
        # Handle potential "Thinking..." or extra text
        if "```json" in raw:
            raw = raw.split("```json")[1].split("```")[0]
        elif "{" not in raw:
             # Fallback: if model just doesn't respond with JSON
             return

        result = json.loads(raw)
        new_facts: list[str] = result.get("new_facts", [])
        updates: list[dict] = result.get("updates", [])

    except (json.JSONDecodeError, Exception) as e:
        logger.warning("Memory extraction failed or returned invalid JSON: %s", e)
        return

    source_turn = {"user_msg": user_message, "assistant_msg": assistant_message}

    # Handle Updates
    for upd in updates:
        try:
            m_id = int(upd.get("id", -1))
            m_content = upd.get("content", "").strip()
            if m_id != -1 and m_content:
                await update_memory_content(db, m_id, m_content)
                logger.info("Updated existing memory id=%d: %s", m_id, m_content)
        except Exception:
            continue

    # Handle New Facts
    for fact in new_facts:
        fact = fact.strip()
        if not fact:
            continue
        
        # Final safety: simple check if it really is new (case insensitive exact match)
        if any(fact.lower() == m.content.lower() for m in existing_memories):
            continue

        await create_memory(db, fact, persona_id, source_turn)
        logger.info("Stored new memory: %s", fact)
