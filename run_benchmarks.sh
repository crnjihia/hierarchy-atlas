#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# run_benchmarks.sh
# Hierarchy Atlas Benchmark Automation Script
# Starts PostgreSQL via Docker Compose, validates health, and executes pgbench
# ============================================================================

echo "==> Ensuring PostgreSQL container is running..."
docker compose up -d

echo "==> Waiting for database to be ready..."
until docker compose exec -T db pg_isready -U dev -d hierarchy_atlas > /dev/null 2>&1; do
    echo "Waiting for PostgreSQL..."
    sleep 2
done
echo "==> PostgreSQL is healthy and ready."

echo "==> Running Hierarchy Atlas pgbench suite..."
docker compose exec -T db python /benchmarks/run_benchmarks.py 2>/dev/null || python benchmarks/run_benchmarks.py

echo "==> Benchmarks completed successfully."
