import threading
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

from .config import get_settings


class RateLimiter:
  """Bellek içi, süreç başına kayan pencere sınırlayıcı (tek sunucu için yeterli)."""

  # Bu kadar anahtar birikirse süresi dolmuşlar temizlenir (saldırgan sınırsız anahtar üretemesin).
  _PURGE_THRESHOLD = 5000
  _MAX_WINDOW = 3600

  def __init__(self) -> None:
    self._hits: dict[str, deque[float]] = defaultdict(deque)
    self._lock = threading.Lock()

  def _purge(self, now: float) -> None:
    stale = [k for k, h in self._hits.items() if not h or now - h[-1] > self._MAX_WINDOW]
    for k in stale:
      del self._hits[k]

  def check(self, key: str, limit: int, window: int) -> None:
    now = time.monotonic()
    with self._lock:
      if len(self._hits) > self._PURGE_THRESHOLD:
        self._purge(now)
      hits = self._hits[key]
      while hits and now - hits[0] > window:
        hits.popleft()
      if len(hits) >= limit:
        retry_after = max(1, int(window - (now - hits[0])))
        raise HTTPException(
          status_code=status.HTTP_429_TOO_MANY_REQUESTS,
          detail="Çok fazla deneme. Lütfen biraz sonra tekrar dene.",
          headers={"Retry-After": str(retry_after)},
        )
      hits.append(now)

  def reset(self) -> None:
    with self._lock:
      self._hits.clear()


limiter = RateLimiter()


def auth_rate_limit(request: Request) -> None:
  settings = get_settings()
  client = request.client.host if request.client else "unknown"
  limiter.check(
    f"auth:{request.url.path}:{client}",
    settings.auth_rate_limit_attempts,
    settings.auth_rate_limit_window_seconds,
  )
