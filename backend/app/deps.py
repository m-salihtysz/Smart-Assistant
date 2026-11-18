from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from .config import get_settings
from .db import get_db
from .models import User
from .security import ALGORITHM


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")
settings = get_settings()


def get_current_user(
  token: Annotated[str, Depends(oauth2_scheme)],
  db: Annotated[Session, Depends(get_db)],
) -> User:
  credentials_error = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Geçersiz veya süresi dolmuş token",
    headers={"WWW-Authenticate": "Bearer"},
  )
  try:
    payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
  except JWTError:
    raise credentials_error from None

  email = payload.get("sub")
  if not email:
    raise credentials_error

  user = db.query(User).filter(User.email == email).first()
  if user is None or not user.is_active:
    raise credentials_error
  return user


DbSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]
