from app.ratelimit import RateLimiter


def test_expired_keys_are_purged_so_memory_cannot_grow_unbounded(monkeypatch):
  limiter = RateLimiter()
  monkeypatch.setattr(RateLimiter, "_PURGE_THRESHOLD", 50)

  clock = {"now": 1000.0}
  monkeypatch.setattr("app.ratelimit.time.monotonic", lambda: clock["now"])

  for i in range(100):
    limiter.check(f"forgot:user{i}@example.com", 3, 3600)
  assert len(limiter._hits) == 100

  # Bir saat sonra eski anahtarlar bir sonraki çağrıda temizlenir
  clock["now"] += 3601
  limiter.check("forgot:new@example.com", 3, 3600)
  assert len(limiter._hits) == 1


def test_window_slides_and_blocks_only_when_exceeded(monkeypatch):
  limiter = RateLimiter()
  clock = {"now": 0.0}
  monkeypatch.setattr("app.ratelimit.time.monotonic", lambda: clock["now"])
  for _ in range(3):
    limiter.check("k", 3, 60)
  try:
    limiter.check("k", 3, 60)
    raise AssertionError("429 beklenirdi")
  except Exception as e:
    assert getattr(e, "status_code", None) == 429
  clock["now"] += 61
  limiter.check("k", 3, 60)  # pencere kaydı, tekrar izin
