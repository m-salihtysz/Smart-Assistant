"""sync_documents (cihaz verisi yedekleri)

Revision ID: 0004
Revises: 0003
"""
from alembic import op
import sqlalchemy as sa

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
  op.create_table(
    "sync_documents",
    sa.Column("id", sa.Integer(), primary_key=True),
    sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
    sa.Column("key", sa.String(), nullable=False),
    sa.Column("data", sa.Text(), nullable=False),
    sa.Column("version", sa.Integer(), nullable=False),
    sa.Column("updated_at", sa.DateTime(), nullable=False),
    sa.UniqueConstraint("user_id", "key", name="uq_sync_user_key"),
  )
  op.create_index("ix_sync_documents_id", "sync_documents", ["id"])
  op.create_index("ix_sync_documents_user_id", "sync_documents", ["user_id"])


def downgrade() -> None:
  op.drop_table("sync_documents")
