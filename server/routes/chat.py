"""
Chat route — POST /chat

Streams the LLM response as Server-Sent Events.
After the full response is collected, triggers memory extraction as a background task.
"""

import asyncio
import json
import logging

from fastapi import APIRouter, BackgroundTasks, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.chat import ChatRequest
from services import memory_service, ollama

logger = logging.getLogger(__name__)
router = APIRouter()


async def _sse_generator(messages: list[dict], db: AsyncSession, background_tasks: BackgroundTasks):
    """
    Streams Ollama response as SSE, then schedules memory extraction.
    """
    full_response_parts: list[str] = []
    user_message = ""

    # Extract the last user message for memory extraction
    for msg in reversed(messages):
        if msg["role"] == "user":
            user_message = msg["content"]
            break

    try:
        async for delta in ollama.stream_chat(messages):
            full_response_parts.append(delta)
            payload = json.dumps({"delta": delta})
            yield f"data: {payload}\n\n"

        yield "data: [DONE]\n\n"

    except Exception as e:
        logger.error("Ollama streaming error: %s", e)
        yield f"data: {json.dumps({'error': str(e)})}\n\n"
        return

    # Schedule memory extraction after stream completes
    if full_response_parts and user_message:
        assistant_message = "".join(full_response_parts)
        background_tasks.add_task(
            memory_service.extract_and_store_memories,
            db,
            user_message,
            assistant_message,
        )
        background_tasks.add_task(memory_service.mark_memories_used, db)


@router.post("/chat")
async def chat(
    request: ChatRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """
    Stream a chat response.

    Prepends all stored memories as a system prompt.
    Schedules memory extraction after the response is delivered.
    """
    # Build memory context from stored memories
    memory_context = await memory_service.build_system_prompt(db)
    
    # Process messages to handle memory injection
    messages = [m.model_dump() for m in request.messages]
    
    if memory_context and messages:
        # Prepend memories to the content of the first message
        # This keeps the 'system' role clean so Ollama uses the Modelfile default
        messages[0]["content"] = f"{memory_context}\n\n{messages[0]['content']}"

    return StreamingResponse(
        _sse_generator(messages, db, background_tasks),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
