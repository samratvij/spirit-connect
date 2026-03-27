from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.db import Conversation, Message
from pydantic import BaseModel

router = APIRouter()

class ConversationCreate(BaseModel):
    persona_id: str
    title: str | None = None

class ConversationUpdate(BaseModel):
    title: str

import json
from pydantic import BaseModel, field_validator

class MessageSchema(BaseModel):
    id: int
    role: str
    content: str
    images: list[str] | None = None
    created_at: datetime

    @field_validator("images", mode="before")
    @classmethod
    def parse_images(cls, value):
        if isinstance(value, str):
            try:
                return json.loads(value)
            except:
                return []
        return value

    class Config:
        from_attributes = True

class ConversationSchema(BaseModel):
    id: int
    persona_id: str
    title: str | None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

@router.get("/conversations", response_model=list[ConversationSchema])
async def list_conversations(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Conversation).order_by(Conversation.updated_at.desc()))
    return result.scalars().all()

@router.post("/conversations", response_model=ConversationSchema)
async def create_conversation(req: ConversationCreate, db: AsyncSession = Depends(get_db)):
    conv = Conversation(persona_id=req.persona_id, title=req.title)
    db.add(conv)
    await db.commit()
    await db.refresh(conv)
    return conv

@router.get("/conversations/{conversation_id}/messages", response_model=list[MessageSchema])
async def get_messages(conversation_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.created_at.asc())
    )
    return result.scalars().all()

@router.patch("/conversations/{conversation_id}")
async def update_conversation(conversation_id: int, req: ConversationUpdate, db: AsyncSession = Depends(get_db)):
    await db.execute(
        update(Conversation)
        .where(Conversation.id == conversation_id)
        .values(title=req.title)
    )
    await db.commit()
    return {"status": "ok"}
@router.delete("/conversations/{conversation_id}")
async def delete_conversation(conversation_id: int, db: AsyncSession = Depends(get_db)):
    # Delete messages first
    from sqlalchemy import delete
    await db.execute(delete(Message).where(Message.conversation_id == conversation_id))
    # Delete conversation
    await db.execute(delete(Conversation).where(Conversation.id == conversation_id))
    await db.commit()
    return {"status": "ok"}
