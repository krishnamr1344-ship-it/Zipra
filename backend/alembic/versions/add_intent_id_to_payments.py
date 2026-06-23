"""add intent_id to payments

Revision ID: add_intent_id
Revises: 8eb2038aa827
Create Date: 2026-06-23 21:45:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'add_intent_id'
down_revision: Union[str, None] = '8eb2038aa827'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS intent_id UUID REFERENCES payment_intents(id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_payments_intent_id ON payments(intent_id)")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_payments_intent_id")
    op.execute("ALTER TABLE payments DROP COLUMN IF EXISTS intent_id")
