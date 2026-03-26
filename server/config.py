from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    ollama_base_url: str = "http://localhost:11434"
    ollama_chat_model: str
    ollama_memory_model: str

    # Auth
    api_secret_key: str

    # Database
    database_url: str = "sqlite+aiosqlite:///./data/memories.db"

    # Memory
    max_memory_tokens: int = 2000


settings = Settings()
