"""initial schema (users, messages)

Revision ID: 0001
Revises:
"""
from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
  op.create_table(
    "users",
    sa.Column("id", sa.Integer(), primary_key=True),
    sa.Column("email", sa.String(), nullable=False),
    sa.Column("hashed_password", sa.String(), nullable=False),
    sa.Column("name", sa.String(), nullable=True),
    sa.Column("birth_date", sa.DateTime(), nullable=True),
    sa.Column("is_active", sa.Boolean(), nullable=False),
    sa.Column("created_at", sa.DateTime(), nullable=False),
  )
  op.create_index("ix_users_id", "users", ["id"])
  op.create_index("ix_users_email", "users", ["email"], unique=True)
  op.create_table(
    "messages",
    sa.Column("id", sa.Integer(), primary_key=True),
    sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
    sa.Column("role", sa.String(), nullable=False),
    sa.Column("content", sa.String(), nullable=False),
    sa.Column("created_at", sa.DateTime(), nullable=False),
  )
  op.create_index("ix_messages_id", "messages", ["id"])


def downgrade() -> None:
  op.drop_table("messages")
  op.drop_table("users")
