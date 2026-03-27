#!/usr/bin/env bash
# start.sh — Start the Spirit Connect server
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f ".env" ]; then
  echo "❌  .env not found. Copy .env.example and configure it first:"
  echo "    cp .env.example .env && nano .env"
  exit 1
fi

# Install dependencies if .venv doesn't exist
if [ ! -d ".venv" ]; then
  echo "🔧  Creating virtual environment..."
  uv venv
fi

echo "📦  Syncing dependencies..."
uv sync --no-install-project

echo "🚀  Starting Spirit Connect server..."
uv run --no-project python main.py
