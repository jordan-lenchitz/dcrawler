#!/usr/bin/env bash
set -euo pipefail

SERVICE="${SERVICE:-dcrawler}"
REGION="${REGION:-us-central1}"
MEMORY="${MEMORY:-512Mi}"
MAX_CLIENTS="${DCRAWL_MAX_CLIENTS:-20}"
IDLE_SEC="${DCRAWL_IDLE_SEC:-900}"
TIMEOUT="${TIMEOUT:-3600}"
SA_NAME="${SA_NAME:-dcrawler-runner}"

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "Error: set PROJECT_ID or run 'gcloud config set project <PROJECT_ID>' first." >&2
  exit 1
fi

SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com}"

# Ensure a dedicated zero-privilege runtime service account exists (never use the default Editor SA)
if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Creating dedicated zero-privilege service account ${SERVICE_ACCOUNT}..."
  gcloud iam service-accounts create "${SA_NAME}" \
    --project "${PROJECT_ID}" \
    --display-name "dcrawler Cloud Run runtime (zero privileges)"
fi

echo "Deploying ${SERVICE} to Cloud Run (${REGION}, min=0, max=1, timeout=${TIMEOUT}s, memory=${MEMORY}, sa=${SERVICE_ACCOUNT})..."

gcloud run deploy "${SERVICE}" \
  --project "${PROJECT_ID}" \
  --source . \
  --region "${REGION}" \
  --service-account "${SERVICE_ACCOUNT}" \
  --allow-unauthenticated \
  --ingress all \
  --port 8080 \
  --timeout "${TIMEOUT}" \
  --min-instances 0 \
  --max-instances 1 \
  --concurrency 25 \
  --memory "${MEMORY}" \
  --cpu 1 \
  --cpu-throttling \
  --set-env-vars "DCRAWL_MODE=web,DCRAWL_IDLE_SEC=${IDLE_SEC},DCRAWL_MAX_CLIENTS=${MAX_CLIENTS}"
