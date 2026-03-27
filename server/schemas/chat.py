from datetime import datetime

from pydantic import BaseModel


class ChatMessage(BaseModel):
    role: str  # "user" | "assistant" | "system"
    content: str
    images: list[str] | None = None


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    model: str | None = None
    conversation_id: int | None = None


class ChatResponse(BaseModel):
    content: str
