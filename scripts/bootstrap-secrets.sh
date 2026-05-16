#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Reading Terraform outputs ==="
cd "${SCRIPT_DIR}/../terraform"

AUTH_DB_ENDPOINT=$(terraform output -raw rds_auth_endpoint)
FLAGS_DB_ENDPOINT=$(terraform output -raw rds_flags_endpoint)
TARGETING_DB_ENDPOINT=$(terraform output -raw rds_targeting_endpoint)
REDIS_ENDPOINT=$(terraform output -raw elasticache_endpoint)
SQS_URL=$(terraform output -raw sqs_queue_url)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

echo "=== Creating namespaces ==="
NAMESPACES="auth-service flag-service targeting-service evaluation-service analytics-service"
for ns in $NAMESPACES; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

echo "=== Creating auth-service secrets ==="
kubectl create secret generic auth-service-secrets \
  --from-literal=DATABASE_URL="postgres://postgres:${AUTH_DB_PASSWORD}@${AUTH_DB_ENDPOINT}/auth_db" \
  --from-literal=MASTER_KEY="${MASTER_KEY}" \
  -n auth-service --dry-run=client -o yaml | kubectl apply -f -

echo "=== Creating flag-service secrets ==="
kubectl create secret generic flag-service-secrets \
  --from-literal=DATABASE_URL="postgres://postgres:${FLAGS_DB_PASSWORD}@${FLAGS_DB_ENDPOINT}/flags_db" \
  --from-literal=AUTH_SERVICE_URL="http://auth-service.auth-service.svc:8001" \
  -n flag-service --dry-run=client -o yaml | kubectl apply -f -

echo "=== Creating targeting-service secrets ==="
kubectl create secret generic targeting-service-secrets \
  --from-literal=DATABASE_URL="postgres://postgres:${TARGETING_DB_PASSWORD}@${TARGETING_DB_ENDPOINT}/targeting_db" \
  --from-literal=AUTH_SERVICE_URL="http://auth-service.auth-service.svc:8001" \
  -n targeting-service --dry-run=client -o yaml | kubectl apply -f -

echo "=== Creating evaluation-service secrets ==="
kubectl create secret generic evaluation-service-secrets \
  --from-literal=REDIS_URL="redis://${REDIS_ENDPOINT}:6379" \
  --from-literal=PORT="8004" \
  --from-literal=FLAG_SERVICE_URL="http://flag-service.flag-service.svc:8002" \
  --from-literal=TARGETING_SERVICE_URL="http://targeting-service.targeting-service.svc:8003" \
  --from-literal=SERVICE_API_KEY="${SERVICE_API_KEY}" \
  --from-literal=AWS_SQS_URL="${SQS_URL}" \
  -n evaluation-service --dry-run=client -o yaml | kubectl apply -f -

echo "=== Creating analytics-service secrets ==="
kubectl create secret generic analytics-service-secrets \
  --from-literal=PORT="8005" \
  --from-literal=AWS_SQS_URL="${SQS_URL}" \
  --from-literal=AWS_DYNAMODB_TABLE="${DYNAMODB_TABLE}" \
  -n analytics-service --dry-run=client -o yaml | kubectl apply -f -

echo "=== Creating AWS credentials secrets ==="
AWS_AK="${AWS_ACCESS_KEY_ID:-$(aws configure get aws_access_key_id 2>/dev/null || echo "")}"
AWS_SK="${AWS_SECRET_ACCESS_KEY:-$(aws configure get aws_secret_access_key 2>/dev/null || echo "")}"
AWS_ST="${AWS_SESSION_TOKEN:-$(aws configure get aws_session_token 2>/dev/null || echo "")}"

if [ -z "$AWS_AK" ] || [ -z "$AWS_SK" ]; then
  echo "AVISO: Credenciais AWS não encontradas."
  echo "No CloudShell, exporte antes de rodar:"
  echo "  export AWS_ACCESS_KEY_ID=..."
  echo "  export AWS_SECRET_ACCESS_KEY=..."
  echo "  export AWS_SESSION_TOKEN=..."
fi

for ns in evaluation-service analytics-service; do
  kubectl create secret generic aws-credentials \
    --from-literal=AWS_ACCESS_KEY_ID="${AWS_AK}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SK}" \
    --from-literal=AWS_SESSION_TOKEN="${AWS_ST}" \
    --from-literal=AWS_REGION="${AWS_REGION}" \
    -n "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

echo "=== Creating ECR pull secrets ==="
ECR_TOKEN=$(aws ecr get-login-password --region "${AWS_REGION}")
ECR_SERVER="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

for ns in $NAMESPACES; do
  kubectl create secret docker-registry ecr-secret \
    --docker-server="${ECR_SERVER}" \
    --docker-username=AWS \
    --docker-password="${ECR_TOKEN}" \
    -n "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

echo ""
echo "=== Initializing databases ==="
bash "${SCRIPT_DIR}/init-databases.sh" || echo "AVISO: init-databases falhou. Execute manualmente: bash scripts/init-databases.sh"

echo ""
echo "=== Bootstrap complete! ==="
echo ""
echo "O ArgoCD e as Applications sao provisionados automaticamente pelo Terraform."
echo ""
echo "ArgoCD admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "ArgoCD URL:"
echo "  kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
echo "Ingress URL:"
echo "  kubectl -n nginx get svc nginx-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
