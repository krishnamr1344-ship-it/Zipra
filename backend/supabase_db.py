"""
supabase_db.py
Database adapter using supabase-py (service_role key).
Replaces SQLAlchemy for Supabase operations.
Auto-commits on write — no separate commit() needed.
"""
import os
from typing import Optional
from supabase import create_client, Client

_supabase: Optional[Client] = None


def get_db() -> Client:
    global _supabase
    if _supabase is not None:
        return _supabase

    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env")

    _supabase = create_client(url, key)
    return _supabase


def close_db():
    pass


# ─── Helpers ───────────────────────────────────────────────────────

def fetch_all(table: str, select: str = "*") -> list:
    return get_db().table(table).select(select).execute().data


def fetch_by(table: str, column: str, value, select: str = "*") -> list:
    return get_db().table(table).select(select).eq(column, value).execute().data


def fetch_one(table: str, column: str, value, select: str = "*") -> Optional[dict]:
    data = get_db().table(table).select(select).eq(column, value).limit(1).execute().data
    return data[0] if data else None


def insert(table: str, data: dict) -> dict:
    return get_db().table(table).insert(data).execute().data[0]


def update(table: str, data: dict, column: str, value) -> dict:
    return get_db().table(table).update(data).eq(column, value).execute().data[0]


def delete(table: str, column: str, value):
    get_db().table(table).delete().eq(column, value).execute()
