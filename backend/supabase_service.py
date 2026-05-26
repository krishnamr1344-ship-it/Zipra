"""
supabase_service.py
Supabase client for backend operations.
Uses service_role key (set in .env) for privileged writes.
"""
import os
from typing import Optional
from supabase import create_client, Client

_supabase: Optional[Client] = None


def get_supabase() -> Client:
    global _supabase
    if _supabase is not None:
        return _supabase

    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env")

    _supabase = create_client(url, key)
    return _supabase
