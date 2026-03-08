from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .db import Base, engine
from .routers import auth, assistant


Base.metadata.create_all(bind=engine)

app = FastAPI(title="Personal Assistant Backend")

app.add_middleware(
  CORSMiddleware,
  allow_origins=["*"],  # Geliştirme için açık; prod'da domain'e göre kısıtla
  allow_credentials=True,
  allow_methods=["*"],
  allow_headers=["*"],
)


@app.get("/")
def read_root():
  return {"message": "Personal Assistant Backend çalışıyor"}


app.include_router(auth.router)
app.include_router(assistant.router)

