#!/usr/bin/env bash
set -euo pipefail

SERVICE="${SERVICE:-dcrawler}"
REGION="${REGION:-us-central1}"
MEMORY="${MEMORY:-512Mi}"
MAX_CLIENTS="${DCRAWL_MAX_CLIENTS:-20}"
IDLE_SEC="${DCRAWL_IDLE_SEC:-900}"

echo "Deploying ${SERVICE} to Cloud Run (${REGION}, min=0, max=1, timeout=3600s, memory=${MEMORY})..."

gcloud run deploy "${SERVICE}" \
  --source . \
  --region "${REGION}" \
  --allow-unauthenticated \
  --port 8080 \
  --timeout 3600 \
  --min-instances 0 \
  --max-instances 1 \
  --concurrency 25 \
  --memory "${MEMORY}" \
  --cpu 1 \
  --set-env-vars "DCRAWL_MODE=web,DCRAWL_IDLE_SEC=${IDLE_SEC},DCRAWL_MAX_CLIENTS=${MAX_CLIENTS}"
