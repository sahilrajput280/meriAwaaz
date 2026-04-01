#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

###############################################################################
### CLEANUP ON EXIT
###############################################################################

cleanup() {
  echo ""
  echo "Shutting down..."

  # Stop backend services
  if [[ -f "$BASE_DIR/scripts/stop_services.sh" ]]; then
    bash "$BASE_DIR/scripts/stop_services.sh" 2>/dev/null || true
  fi

  # Stop UI
  if [[ -n "$UI_PID" ]] && kill -0 "$UI_PID" 2>/dev/null; then
    kill -TERM "$UI_PID" 2>/dev/null || true
  fi

  # Stop docker compose
  docker compose -f docker-compose-local.yaml down 2>/dev/null || true

  echo "Done."
}

trap cleanup EXIT INT TERM

###############################################################################
### 1) Start infrastructure (docker compose)
###############################################################################

echo "Starting infrastructure services (postgres, redis, minio, coturn)..."
docker compose -f docker-compose-local.yaml up -d

echo "Waiting for services to be healthy..."
for service in postgres redis minio; do
  echo -n "  Waiting for $service..."
  for i in $(seq 1 30); do
    status=$(docker compose -f docker-compose-local.yaml ps --format json "$service" 2>/dev/null \
      | python3 -c "import sys,json; data=sys.stdin.read().strip(); rows=json.loads(data) if data.startswith('[') else [json.loads(l) for l in data.splitlines() if l]; print(rows[0].get('Health','') if rows else '')" 2>/dev/null || true)
    if [[ "$status" == "healthy" ]]; then
      echo " ready"
      break
    fi
    if [[ $i -eq 30 ]]; then
      echo " timeout (continuing anyway)"
    fi
    sleep 1
    echo -n "."
  done
done

###############################################################################
### 2) Start backend services
###############################################################################

echo ""
echo "Starting backend services..."
bash "$BASE_DIR/scripts/start_services_dev.sh" &
BACKEND_PID=$!

###############################################################################
### 3) Start UI frontend
###############################################################################

echo ""
echo "Starting UI frontend (Next.js)..."
cd "$BASE_DIR/ui"
npm run dev &
UI_PID=$!
cd "$BASE_DIR"

###############################################################################
### 4) Summary
###############################################################################

echo ""
echo "──────────────────────────────────────────────────"
echo "Dograh dev environment started"
echo ""
echo "  Backend API:  http://localhost:8000"
echo "  Frontend UI:  http://localhost:3000"
echo "  MinIO:        http://localhost:9001"
echo ""
echo "Press Ctrl+C to stop everything"
echo "──────────────────────────────────────────────────"

wait $BACKEND_PID $UI_PID
