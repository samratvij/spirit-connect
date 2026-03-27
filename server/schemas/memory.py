from datetime import datetime

from pydantic import BaseModel


class MemoryRecord(BaseModel):
    id: int
    content: str
    created_at: datetime
    updated_at: datetime
    last_used: datetime | None
    persona_id: str

    model_config = {"from_attributes": True}


class MemoryCreate(BaseModel):
    content: str


class MemoryUpdate(BaseModel):
    content: str
