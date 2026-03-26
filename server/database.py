from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from config import settings

engine = create_async_engine(settings.database_url, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session


async def init_db():
    """Create all tables on startup."""
    # Ensure data directory exists
    import os
    os.makedirs("data", exist_ok=True)
    async with engine.begin() as conn:
        from models.db import Memory  # noqa: F401 — ensures model is registered
        await conn.run_sync(Base.metadata.create_all)
