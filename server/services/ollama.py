"""
Ollama HTTP client service.

Handles:
- Streaming chat completions
- Non-streaming calls (used for memory extraction)
"""

import json
from collections.abc import AsyncGenerator

import httpx

from config import settings

OLLAMA_CHAT_PATH = "/api/chat"


async def stream_chat(messages: list[dict]) -> AsyncGenerator[str, None]:
    """
    Stream a chat completion from Ollama.

    Yields decoded text delta strings as they arrive.
    """
    payload = {
        "model": settings.ollama_chat_model,
        "messages": messages,
        "stream": True,
        "think": False,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        async with client.stream(
            "POST",
            f"{settings.ollama_base_url}{OLLAMA_CHAT_PATH}",
            json=payload,
        ) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line.strip():
                    continue
                try:
                    data = json.loads(line)
                    delta = data.get("message", {}).get("content", "")
                    if delta:
                        yield delta
                    if data.get("done"):
                        break
                except json.JSONDecodeError:
                    continue


async def complete(messages: list[dict], model: str | None = None) -> str:
    """
    Non-streaming chat completion. Returns the full response content.
    Used for memory extraction where we need the full response at once.
    """
    chosen_model = model or settings.ollama_memory_model
    payload = {
        "model": chosen_model,
        "messages": messages,
        "stream": False,
        "think": False,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{settings.ollama_base_url}{OLLAMA_CHAT_PATH}",
            json=payload,
        )
        response.raise_for_status()
        data = response.json()
        return data.get("message", {}).get("content", "")
