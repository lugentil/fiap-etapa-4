#!/bin/bash
set -euo pipefail

SERVICES_DIR="${1:?Usage: $0 <path-to-services-source-dir>}"
REGION="us-east-1"
PROJECT="togglemaster"
SERVICES=("auth-service" "flag-service" "targeting-service" "evaluation-service" "analytics-service")

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "================================================"
echo "AWS Account ID: ${ACCOUNT_ID}"
echo "ECR URL:        ${ECR_URL}"
echo "Source dir:     ${SERVICES_DIR}"
echo "================================================"

echo ""
echo "[1/4] Logging into ECR..."
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ECR_URL}"

echo ""
echo "[2/4] Building and pushing images..."
for SERVICE in "${SERVICES[@]}"; do
  SERVICE_PATH="${SERVICES_DIR}/${SERVICE}"
  IMAGE="${ECR_URL}/${PROJECT}/${SERVICE}:latest"

  if [ ! -d "${SERVICE_PATH}" ]; then
    echo "  [SKIP] ${SERVICE} - directory not found at ${SERVICE_PATH}"
    continue
  fi

  echo ""
  echo "  --- ${SERVICE} ---"

  echo "  Cleaning Docker cache..."
  docker rmi $(docker images -q) -f 2>/dev/null || true
  docker builder prune -a -f 2>/dev/null || true

  echo "  Building: ${IMAGE}"
  docker build -t "${IMAGE}" "${SERVICE_PATH}"

  echo "  Pushing:  ${IMAGE}"
  docker push "${IMAGE}"

  echo "  Cleaning up image..."
  docker rmi "${IMAGE}" -f 2>/dev/null || true

  echo "  [OK] ${SERVICE} pushed successfully"
done

echo ""
echo "  Final Docker cleanup..."
docker system prune -a -f 2>/dev/null || true

echo ""
echo "[3/4] Updating deployment YAMLs with Account ID..."
GITOPS_DIR="$(cd "$(dirname "$0")/../gitops/apps" && pwd)"

for SERVICE in "${SERVICES[@]}"; do
  DEPLOYMENT="${GITOPS_DIR}/${SERVICE}/deployment.yaml"
  if [ -f "${DEPLOYMENT}" ]; then
    sed -i "s|ACCOUNT_ID|${ACCOUNT_ID}|g" "${DEPLOYMENT}"
    echo "  [OK] ${SERVICE}/deployment.yaml updated"
  fi
done

echo ""
echo "[4/4] Creating ECR pull secrets..."
ECR_TOKEN=$(aws ecr get-login-password --region "${REGION}")

for SERVICE in "${SERVICES[@]}"; do
  kubectl create secret docker-registry ecr-secret \
    --namespace="${SERVICE}" \
    --docker-server="${ECR_URL}" \
    --docker-username=AWS \
    --docker-password="${ECR_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "  [OK] ecr-secret created in namespace ${SERVICE}"
done

echo ""
echo "================================================"
echo "All done! Check pod status with:"
echo "  kubectl get pods -A"
echo "================================================"
