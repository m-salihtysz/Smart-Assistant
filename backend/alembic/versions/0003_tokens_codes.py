"""refresh token'lar, e-posta kodları, users.email_verified

Revision ID: 0003
Revises: 0002
"""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
  # Mevcut kullanıcılar doğrulanmış sayılır (server_default=true).
  with op.batch_alter_table("users") as batch:
    batch.add_column(sa.Column("email_verified", sa.Boolean(), nullable=False, server_default=sa.true()))
  op.create_table(
    "refresh_tokens",
    sa.Column("id", sa.Integer(), primary_key=True),
    sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
    sa.Column("token_hash", sa.String(), nullable=False),
    sa.Column("expires_at", sa.DateTime(), nullable=False),
    sa.Column("revoked", sa.Boolean(), nullable=False, server_default=sa.false()),
    sa.Column("created_at", sa.DateTime(), nullable=False),
  )
  op.create_index("ix_refresh_tokens_id", "refresh_tokens", ["id"])
  op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"])
  op.create_index("ix_refresh_tokens_token_hash", "refresh_tokens", ["token_hash"], unique=True)
  op.create_table(
    "email_codes",
    sa.Column("id", sa.Integer(), primary_key=True),
    sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
    sa.Column("purpose", sa.String(), nullable=False),
    sa.Column("code_hash", sa.String(), nullable=False),
    sa.Column("expires_at", sa.DateTime(), nullable=False),
    sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
    sa.Column("created_at", sa.DateTime(), nullable=False),
  )
  op.create_index("ix_email_codes_id", "email_codes", ["id"])
  op.create_index("ix_email_codes_user_id", "email_codes", ["user_id"])


def downgrade() -> None:
  op.drop_table("email_codes")
  op.drop_table("refresh_tokens")
  with op.batch_alter_table("users") as batch:
    batch.drop_column("email_verified")
