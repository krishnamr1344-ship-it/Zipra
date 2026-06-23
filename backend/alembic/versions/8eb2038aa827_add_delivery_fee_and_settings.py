"""add delivery fee and settings

Revision ID: 8eb2038aa827
Revises: e00aea3f3315
Create Date: 2026-06-24 01:18:29.025213

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '8eb2038aa827'
down_revision: Union[str, Sequence[str], None] = 'e00aea3f3315'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('app_settings',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('key', sa.String(length=100), nullable=False),
        sa.Column('value', sa.String(length=500), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_app_settings_key'), 'app_settings', ['key'], unique=True)

    op.add_column('orders', sa.Column('delivery_fee', sa.Numeric(precision=10, scale=2), nullable=False, server_default=sa.text('0.00')))
    op.alter_column('orders', 'delivery_fee', server_default=None)


def downgrade() -> None:
    op.drop_column('orders', 'delivery_fee')
    op.drop_index(op.f('ix_app_settings_key'), table_name='app_settings')
    op.drop_table('app_settings')
