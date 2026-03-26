"""
Memory CRUD routes — GET / POST / PUT / DELETE /memory
"""

import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from schemas.memory import MemoryCreate, MemoryRecord, MemoryUpdate
from services import memory_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/memory", tags=["memory"])


@router.get("", response_model=list[MemoryRecord])
async def list_memories(db: AsyncSession = Depends(get_db)):
    """Return all stored memories, most recently used first."""
    memories = await memory_service.get_all_memories(db)
    return memories


@router.post("", response_model=MemoryRecord, status_code=201)
async def add_memory(payload: MemoryCreate, db: AsyncSession = Depends(get_db)):
    """Manually add a memory."""
    memory = await memory_service.create_memory(db, payload.content)
    return memory


@router.put("/{memory_id}", response_model=MemoryRecord)
async def edit_memory(
    memory_id: int,
    payload: MemoryUpdate,
    db: AsyncSession = Depends(get_db),
):
    """Edit the content of an existing memory."""
    memory = await memory_service.update_memory_content(db, memory_id, payload.content)
    if not memory:
        raise HTTPException(status_code=404, detail="Memory not found")
    return memory


@router.delete("/{memory_id}", status_code=204)
async def remove_memory(memory_id: int, db: AsyncSession = Depends(get_db)):
    """Delete a memory by ID."""
    deleted = await memory_service.delete_memory(db, memory_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Memory not found")
