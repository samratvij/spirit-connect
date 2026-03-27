from datetime import datetime

from sqlalchemy import DateTime, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class Memory(Base):
    __tablename__ = "memories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now(), nullable=False
    )
    last_used: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    # JSON blob of the source turn: {"user_msg": "...", "assistant_msg": "..."}
    source_turn: Mapped[str | None] = mapped_column(Text, nullable=True)
    
    # Vector embedding (stored as bytes/blob for local cosine similarity)
    embedding: Mapped[bytes | None] = mapped_column(Text, nullable=True) # sqlite can store large blobs in Text or LargeBinary
    
    # ID of the persona this memory belongs to (e.g., 'qwen-spirit', 'llama3.2')
    persona_id: Mapped[str | None] = mapped_column(Text, nullable=True)


class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    persona_id: Mapped[str] = mapped_column(Text, nullable=False)
    title: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now(), nullable=False
    )


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    conversation_id: Mapped[int] = mapped_column(Integer, nullable=False) # Simplified for SQLite
    role: Mapped[str] = mapped_column(Text, nullable=False) # 'user' or 'assistant'
    content: Mapped[str] = mapped_column(Text, nullable=False)
    images: Mapped[str | None] = mapped_column(Text, nullable=True) # JSON list of b64
    created_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )
