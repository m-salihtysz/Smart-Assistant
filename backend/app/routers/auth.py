from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from .. import models, schemas
from ..db import get_db
from ..security import hash_password, verify_password, create_access_token
from ..deps import CurrentUser


router = APIRouter(prefix="/auth", tags=["auth"])


DbSession = Annotated[Session, Depends(get_db)]


@router.post("/register", response_model=schemas.UserRead, status_code=status.HTTP_201_CREATED)
def register(user_in: schemas.UserCreate, db: DbSession):
  existing = db.query(models.User).filter(models.User.email == user_in.email).first()
  if existing is not None:
    raise HTTPException(
      status_code=status.HTTP_400_BAD_REQUEST,
      detail="Bu e-posta ile zaten kayıt var.",
    )

  db_user = models.User(
    email=user_in.email.lower(),
    hashed_password=hash_password(user_in.password),
    name=user_in.name,
    birth_date=datetime.combine(user_in.birth_date, datetime.min.time()) if user_in.birth_date else None,
  )
  db.add(db_user)
  db.commit()
  db.refresh(db_user)
  return db_user


@router.post("/login", response_model=schemas.Token)
def login(
  form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
  db: DbSession,
):
  user = db.query(models.User).filter(models.User.email == form_data.username.lower()).first()
  if user is None or not verify_password(form_data.password, user.hashed_password):
    raise HTTPException(
      status_code=status.HTTP_401_UNAUTHORIZED,
      detail="E-posta veya şifre hatalı.",
    )

  access_token = create_access_token(subject=user.email)
  return schemas.Token(access_token=access_token)


@router.get("/me", response_model=schemas.UserRead)
def read_me(current_user: CurrentUser):
  return current_user


@router.put("/me", response_model=schemas.UserRead)
def update_me(
  update: schemas.UserUpdate,
  current_user: CurrentUser,
  db: DbSession,
):
  if update.name is not None:
    current_user.name = update.name
  if update.birth_date is not None:
    current_user.birth_date = datetime.combine(update.birth_date, datetime.min.time())

  db.add(current_user)
  db.commit()
  db.refresh(current_user)
  return current_user

