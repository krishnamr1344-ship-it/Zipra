"""initial_schema

Revision ID: e00aea3f3315
Revises:
Create Date: 2026-06-23 15:24:07.945690

Baseline migration — all tables are created by Base.metadata.create_all()
in main.py on startup.
After deploying, stamp this revision:
    alembic stamp e00aea3f3315

Future schema changes should use:
    alembic revision --autogenerate -m "description"
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'e00aea3f3315'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
