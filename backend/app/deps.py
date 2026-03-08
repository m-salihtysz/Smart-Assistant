from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from .config import get_settings
from .db import get_db
from .models import User
from .schemas import TokenData


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")
settings = get_settings()


def get_current_user(
  token: Annotated[str, Depends(oauth2_scheme)],
  db: Annotated[Session, Depends(get_db)],
) -> User:
  try:
    payload = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
    email: str | None = payload.get("sub")
    if email is None:
      raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik doğrulama başarısız",
      )
    token_data = TokenData(email=email)
  except JWTError:
    raise HTTPException(
      status_code=status.HTTP_401_UNAUTHORIZED,
      detail="Geçersiz token",
    )

  user = db.query(User).filter(User.email == token_data.email).first()
  if user is None:
    raise HTTPException(
      status_code=status.HTTP_401_UNAUTHORIZED,
      detail="Kullanıcı bulunamadı",
    )
  return user


DbSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]

