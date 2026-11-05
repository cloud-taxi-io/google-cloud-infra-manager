#!/usr/bin/env bash
# Deploy this infra with Google Cloud Infrastructure Manager.
# Usage: PROJECT_ID=... IMAGE=... ./deploy.sh [apply|preview|delete]
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
REGION="${REGION:-europe-west1}"
DEPLOYMENT="${DEPLOYMENT:-pubsub-cloudrun}"
SA_NAME="${SA_NAME:-infra-manager}"
SA="projects/${PROJECT_ID}/serviceAccounts/${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
ACTION="${1:-apply}"
# Optional: Identity Platform test phone numbers as JSON (kept out of git), e.g.
#   TEST_PHONE_NUMBERS_JSON='{"+33612345678":"123456"}' ./deploy.sh apply
TEST_PHONE_NUMBERS_JSON="${TEST_PHONE_NUMBERS_JSON:-{\}}"

case "$ACTION" in
  apply)
    IMAGE="${IMAGE:?set IMAGE}"
    gcloud infra-manager deployments apply "projects/${PROJECT_ID}/locations/${REGION}/deployments/${DEPLOYMENT}" \
      --service-account="${SA}" \
      --local-source=terraform \
      --input-values="^|^project_id=${PROJECT_ID}|region=${REGION}|image=${IMAGE}|identity_test_phone_numbers_json=${TEST_PHONE_NUMBERS_JSON}"
    ;;
  preview)
    IMAGE="${IMAGE:?set IMAGE}"
    gcloud infra-manager previews create "projects/${PROJECT_ID}/locations/${REGION}/previews/${DEPLOYMENT}-preview" \
      --service-account="${SA}" \
      --local-source=terraform \
      --input-values="^|^project_id=${PROJECT_ID}|region=${REGION}|image=${IMAGE}|identity_test_phone_numbers_json=${TEST_PHONE_NUMBERS_JSON}"
    ;;
  delete)
    gcloud infra-manager deployments delete "projects/${PROJECT_ID}/locations/${REGION}/deployments/${DEPLOYMENT}"
    ;;
  *) echo "Usage: $0 [apply|preview|delete]"; exit 1 ;;
esac
