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

EXTRACTION_SYSTEM_PROMPT = """You are a personal memory extraction assistant.

Given a single conversation exchange (one user message and one assistant response), extract discrete factual statements about the USER that are worth remembering for future conversations.

Rules:
- Output ONLY a valid JSON array of strings. No other text, ever.
- Each string is one short declarative fact about the user.
- Write facts in third person: "User prefers X", "User works at Y", "User is Z"
- Exclude generic small talk, questions about the weather, or assistant responses.
- If nothing worth remembering was said, output exactly: []
- Maximum 5 facts per turn.

Example output:
["User is gluten intolerant.", "User prefers concise answers."]"""


# ---------------------------------------------------------------------------
# System prompt builder
# ---------------------------------------------------------------------------

MEMORY_BLOCK_HEADER = "### USER CONTEXT (Memories)\n"

NO_MEMORY_BLOCK = ""


async def build_system_prompt(db: AsyncSession) -> str:
    """
    Fetch all memories and construct the system prompt injection block.
    Respects MAX_MEMORY_TOKENS — oldest/least-used memories are trimmed first.
    """
    memories = await get_all_memories(db)
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

async def get_all_memories(db: AsyncSession) -> list[Memory]:
    """Return all memories, most recently used / updated first."""
    result = await db.execute(
        select(Memory).order_by(Memory.last_used.desc().nullslast(), Memory.updated_at.desc())
    )
    return list(result.scalars().all())


async def get_memory_by_id(db: AsyncSession, memory_id: int) -> Memory | None:
    result = await db.execute(select(Memory).where(Memory.id == memory_id))
    return result.scalar_one_or_none()


async def create_memory(db: AsyncSession, content: str, source_turn: dict | None = None) -> Memory:
    memory = Memory(
        content=content,
        source_turn=json.dumps(source_turn) if source_turn else None,
    )
    db.add(memory)
    await db.commit()
    await db.refresh(memory)
    return memory


async def update_memory_content(db: AsyncSession, memory_id: int, content: str) -> Memory | None:
    await db.execute(
        update(Memory)
        .where(Memory.id == memory_id)
        .values(content=content, updated_at=datetime.now(timezone.utc))
    )
    await db.commit()
    return await get_memory_by_id(db, memory_id)


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

def _is_duplicate(new_fact: str, existing_facts: list[str], threshold: float = 0.6) -> int | None:
    """
    Simple word-overlap deduplication.
    Returns the index of the matching existing fact, or None if no duplicate found.
    """
    new_words = set(new_fact.lower().split())
    for i, existing in enumerate(existing_facts):
        existing_words = set(existing.lower().split())
        if not new_words or not existing_words:
            continue
        overlap = len(new_words & existing_words) / max(len(new_words), len(existing_words))
        if overlap >= threshold:
            return i
    return None


async def extract_and_store_memories(
    db: AsyncSession,
    user_message: str,
    assistant_message: str,
):
    """
    Run memory extraction on a completed Q&A turn and persist results.
    Called as a background task — errors are logged but don't affect the chat.
    """
    extraction_messages = [
        {"role": "system", "content": EXTRACTION_SYSTEM_PROMPT},
        {
            "role": "user",
            "content": (
                f'User message: "{user_message}"\n\n'
                f'Assistant response: "{assistant_message}"'
            ),
        },
    ]

    try:
        raw = await ollama.complete(extraction_messages)
        raw = raw.strip()

        # Parse JSON array
        facts: list[str] = json.loads(raw)
        if not isinstance(facts, list):
            logger.warning("Memory extraction returned non-list: %s", raw)
            return

    except (json.JSONDecodeError, Exception) as e:
        logger.warning("Memory extraction failed: %s", e)
        return

    if not facts:
        return

    # Load existing memories for deduplication
    existing_memories = await get_all_memories(db)
    existing_contents = [m.content for m in existing_memories]
    source_turn = {"user_msg": user_message, "assistant_msg": assistant_message}

    for fact in facts:
        fact = fact.strip()
        if not fact:
            continue

        dup_idx = _is_duplicate(fact, existing_contents)
        if dup_idx is not None:
            # Update existing memory with new phrasing
            existing_id = existing_memories[dup_idx].id
            await update_memory_content(db, existing_id, fact)
            existing_contents[dup_idx] = fact
            logger.info("Updated duplicate memory id=%d: %s", existing_id, fact)
        else:
            new_mem = await create_memory(db, fact, source_turn)
            existing_memories.append(new_mem)
            existing_contents.append(fact)
            logger.info("Stored new memory: %s", fact)
