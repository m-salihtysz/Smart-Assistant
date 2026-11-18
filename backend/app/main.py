from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .db import Base, engine
from .routers import auth, assistant, sync


settings = get_settings()

# Geliştirmede tablolar otomatik oluşur. Üretimde şema yalnızca Alembic ile yönetilir
# (`alembic upgrade head`); böylece göç gerektiren değişiklikler sessizce atlanmaz.
if not settings.is_production:
  Base.metadata.create_all(bind=engine)

app = FastAPI(title="Smart Assistant Backend")

# Mobil uygulama CORS gerektirmez; yalnızca açıkça izin verilen web origin'leri kabul edilir.
if settings.cors_origin_list:
  app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
  )


@app.get("/")
def read_root():
  return {"message": "Smart Assistant Backend çalışıyor"}


app.include_router(auth.router)
app.include_router(assistant.router)
app.include_router(sync.router)
