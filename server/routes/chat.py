"""
Chat route — POST /chat

Streams the LLM response as Server-Sent Events.
After the full response is collected, triggers memory extraction as a background task.
"""

import asyncio
import json
import logging

print("DEBUG: chat.py is being loaded/reloaded")

from fastapi import APIRouter, BackgroundTasks, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy import func, update
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.chat import ChatRequest
from services import memory_service, ollama

logger = logging.getLogger(__name__)
router = APIRouter()


async def _sse_generator(
    messages: list[dict], 
    db: AsyncSession, 
    background_tasks: BackgroundTasks, 
    model: str,
    conversation_id: int | None = None
):
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
        async for delta in ollama.stream_chat(messages, model=model):
            full_response_parts.append(delta)
            payload = json.dumps({"delta": delta})
            yield f"data: {payload}\n\n"

        yield "data: [DONE]\n\n"

    except Exception as e:
        logger.error("Ollama streaming error: %s", e)
        yield f"data: {json.dumps({'error': str(e)})}\n\n"
        return

    # Post-stream tasks
    if full_response_parts and user_message:
        assistant_message = "".join(full_response_parts)
        
        # 1. Store Assistant Message if history is enabled
        if conversation_id:
            from models.db import Message, Conversation
            from sqlalchemy import update
            db.add(Message(conversation_id=conversation_id, role="assistant", content=assistant_message))
            # Update conversation timestamp
            await db.execute(update(Conversation).where(Conversation.id == conversation_id).values(updated_at=func.now()))
            await db.commit()

        # 2. Extract Memories
        background_tasks.add_task(
            memory_service.extract_and_store_memories,
            db,
            user_message,
            assistant_message,
            model,
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
    """
    persona_id = request.model or settings.ollama_chat_model
    
    # Persistent History: Save the User's message first
    if request.conversation_id:
        from models.db import Message
        # The last message in request.messages is the current turn
        user_msg = request.messages[-1]
        user_msg_text = user_msg.content
        user_images_json = json.dumps(user_msg.images) if user_msg.images else None
        db.add(Message(conversation_id=request.conversation_id, role="user", content=user_msg_text, images=user_images_json))
        await db.commit()

    # Build memory context
    user_query = request.messages[-1].content if request.messages else None
    memory_context = await memory_service.build_system_prompt(db, persona_id, query=user_query)
    
    messages = [m.model_dump() for m in request.messages]
    
    # Log for debugging
    last_msg = messages[-1] if messages else {}
    num_images = len(last_msg.get("images", [])) if last_msg.get("images") else 0
    debug_line = f"Chat route hit: {len(messages)} messages. Last msg role={last_msg.get('role')} has_images={num_images > 0} ({num_images})\n"
    with open("/tmp/ollama_debug.log", "a") as f:
        f.write(debug_line)
    
    if memory_context and messages:
        messages[0]["content"] = f"{memory_context}\n\n{messages[0]['content']}"

    return StreamingResponse(
        _sse_generator(messages, db, background_tasks, model=persona_id, conversation_id=request.conversation_id),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
