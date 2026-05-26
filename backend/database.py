"""
database.py
Purpose: Database connection via SQLAlchemy ORM.
Security: Reads credentials from .env only. Never hardcodes secrets.
          DB port is NOT exposed — connection originates from backend only.
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is required")

# engine manages the connection pool.
# Security: No raw SQL — all queries go through SQLAlchemy ORM.
engine = create_engine(DATABASE_URL, pool_pre_ping=True)

# SessionLocal creates new DB sessions (one per request).
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for all ORM models.
Base = declarative_base()


def get_db():
    """
    FastAPI dependency: yields a DB session and closes it after the request.
    Prevents connection leaks.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
