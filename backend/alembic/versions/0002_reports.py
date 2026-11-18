"""reports table (AI yanıt bildirimleri)

Revision ID: 0002
Revises: 0001
"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
  op.create_table(
    "reports",
    sa.Column("id", sa.Integer(), primary_key=True),
    sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
    sa.Column("content", sa.String(), nullable=False),
    sa.Column("reason", sa.String(), nullable=True),
    sa.Column("created_at", sa.DateTime(), nullable=False),
  )
  op.create_index("ix_reports_id", "reports", ["id"])
  op.create_index("ix_reports_user_id", "reports", ["user_id"])


def downgrade() -> None:
  op.drop_table("reports")
