#!/usr/bin/env bash
set -euo pipefail

docker compose exec -T redis redis-cli FLUSHDB >/dev/null

docker compose exec -T pymongo-api python - <<'PY'
import time
import urllib.request

url = "http://localhost:8080/helloDoc/users"
durations = []
for _ in range(2):
    started = time.perf_counter()
    with urllib.request.urlopen(url) as response:
        response.read()
    durations.append((time.perf_counter() - started) * 1000)

print(f"first request:  {durations[0]:.2f} ms")
print(f"second request: {durations[1]:.2f} ms")
assert durations[1] < 100, f"cached request took {durations[1]:.2f} ms"
PY
