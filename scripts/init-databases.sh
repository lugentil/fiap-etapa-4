#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"

echo "================================================"
echo "  Init Databases"
echo "================================================"

echo ""
echo "[1/4] Lendo endpoints do Terraform..."
cd "$TERRAFORM_DIR"

AUTH_ENDPOINT=$(terraform output -raw rds_auth_endpoint 2>/dev/null | cut -d: -f1)
FLAGS_ENDPOINT=$(terraform output -raw rds_flags_endpoint 2>/dev/null | cut -d: -f1)
TARGETING_ENDPOINT=$(terraform output -raw rds_targeting_endpoint 2>/dev/null | cut -d: -f1)

if [ -z "$AUTH_ENDPOINT" ] || [ -z "$FLAGS_ENDPOINT" ] || [ -z "$TARGETING_ENDPOINT" ]; then
  echo "ERRO: Não foi possível ler os endpoints do Terraform."
  echo "Execute 'terraform apply' primeiro."
  exit 1
fi

echo "  Auth RDS:      $AUTH_ENDPOINT"
echo "  Flags RDS:     $FLAGS_ENDPOINT"
echo "  Targeting RDS: $TARGETING_ENDPOINT"

echo ""
echo "[2/4] Lendo senhas..."

AUTH_PASS=$(grep 'auth_db' "$TERRAFORM_DIR/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
FLAGS_PASS=$(grep 'flags_db' "$TERRAFORM_DIR/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
TARGETING_PASS=$(grep 'targeting_db' "$TERRAFORM_DIR/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')

echo "  Senhas lidas do terraform.tfvars"

echo ""
echo "[3/4] Garantindo namespaces..."
for ns in auth-service flag-service targeting-service; do
  kubectl create namespace "$ns" 2>/dev/null || true
done

echo ""
echo "[4/4] Criando Jobs de inicialização..."
kubectl delete job init-auth-db -n auth-service 2>/dev/null || true
kubectl delete job init-flag-db -n flag-service 2>/dev/null || true
kubectl delete job init-targeting-db -n targeting-service 2>/dev/null || true

sleep 5

echo ""
echo "  --- auth-service (auth_db) ---"
cat <<YAML | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: init-auth-db
  namespace: auth-service
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: psql
        image: postgres:15-alpine
        command: ["sh", "-c"]
        args:
        - |
          PGPASSWORD=${AUTH_PASS} psql -h ${AUTH_ENDPOINT} -U postgres -d postgres -c "CREATE DATABASE auth_db;" 2>&1 || true

          PGPASSWORD=${AUTH_PASS} psql -h ${AUTH_ENDPOINT} -U postgres -d auth_db <<'SQL'
          CREATE TABLE IF NOT EXISTS api_keys (
              id SERIAL PRIMARY KEY,
              name VARCHAR(100) NOT NULL,
              key_hash VARCHAR(64) NOT NULL UNIQUE,
              is_active BOOLEAN DEFAULT true,
              created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
          );
          SQL

          echo "AUTH_DB_OK" > /dev/termination-log
        terminationMessagePolicy: File
YAML

echo "  --- flag-service (flags_db) ---"
cat <<YAML | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: init-flag-db
  namespace: flag-service
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: psql
        image: postgres:15-alpine
        command: ["sh", "-c"]
        args:
        - |
          PGPASSWORD=${FLAGS_PASS} psql -h ${FLAGS_ENDPOINT} -U postgres -d postgres -c "CREATE DATABASE flags_db;" 2>&1 || true

          PGPASSWORD=${FLAGS_PASS} psql -h ${FLAGS_ENDPOINT} -U postgres -d flags_db <<'SQL'
          CREATE TABLE IF NOT EXISTS flags (
              id SERIAL PRIMARY KEY,
              name VARCHAR(100) UNIQUE NOT NULL,
              description TEXT,
              is_enabled BOOLEAN NOT NULL DEFAULT false,
              created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
          );

          CREATE OR REPLACE FUNCTION trigger_set_timestamp()
          RETURNS TRIGGER AS \$\$
          BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
          END;
          \$\$ LANGUAGE plpgsql;

          DROP TRIGGER IF EXISTS set_timestamp ON flags;

          CREATE TRIGGER set_timestamp
          BEFORE UPDATE ON flags
          FOR EACH ROW
          EXECUTE PROCEDURE trigger_set_timestamp();
          SQL

          echo "FLAGS_DB_OK" > /dev/termination-log
        terminationMessagePolicy: File
YAML

echo "  --- targeting-service (targeting_db) ---"
cat <<YAML | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: init-targeting-db
  namespace: targeting-service
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: psql
        image: postgres:15-alpine
        command: ["sh", "-c"]
        args:
        - |
          PGPASSWORD=${TARGETING_PASS} psql -h ${TARGETING_ENDPOINT} -U postgres -d postgres -c "CREATE DATABASE targeting_db;" 2>&1 || true

          PGPASSWORD=${TARGETING_PASS} psql -h ${TARGETING_ENDPOINT} -U postgres -d targeting_db <<'SQL'
          CREATE TABLE IF NOT EXISTS targeting_rules (
              id SERIAL PRIMARY KEY,
              flag_name VARCHAR(100) UNIQUE NOT NULL,
              is_enabled BOOLEAN NOT NULL DEFAULT true,
              rules JSONB NOT NULL,
              created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
          );

          CREATE OR REPLACE FUNCTION trigger_set_timestamp()
          RETURNS TRIGGER AS \$\$
          BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
          END;
          \$\$ LANGUAGE plpgsql;

          DROP TRIGGER IF EXISTS set_timestamp ON targeting_rules;

          CREATE TRIGGER set_timestamp
          BEFORE UPDATE ON targeting_rules
          FOR EACH ROW
          EXECUTE PROCEDURE trigger_set_timestamp();
          SQL

          echo "TARGETING_DB_OK" > /dev/termination-log
        terminationMessagePolicy: File
YAML

echo ""
echo "================================================"
echo "  Aguardando Jobs completarem (~30s)..."
echo "================================================"
sleep 30

echo ""
echo "=== Resultados ==="

ALL_OK=true
for JOB_INFO in "auth-service:init-auth-db" "flag-service:init-flag-db" "targeting-service:init-targeting-db"; do
  NS="${JOB_INFO%%:*}"
  JOB="${JOB_INFO##*:}"

  STATUS=$(kubectl get job "$JOB" -n "$NS" -o jsonpath='{.status.succeeded}' 2>/dev/null)
  MSG=$(kubectl get pods -n "$NS" -l "job-name=$JOB" -o jsonpath='{.items[0].status.containerStatuses[0].state.terminated.message}' 2>/dev/null)

  if [ "$STATUS" = "1" ]; then
    echo "  [OK] $NS: $MSG"
  else
    echo "  [FAIL] $NS: Job não completou. Message: $MSG"
    ALL_OK=false
  fi
done

echo ""
if [ "$ALL_OK" = true ]; then
  echo "Todos os bancos inicializados com sucesso!"
  echo ""
  echo "Reiniciando deployments para reconectar..."
  for ns in auth-service flag-service targeting-service; do
    kubectl rollout restart deployment -n "$ns" "${ns}" 2>/dev/null || true
  done
  echo "Done! Verifique com: kubectl get pods -A"
else
  echo "Alguns jobs falharam. Verifique os logs acima."
  echo "Para re-executar: bash scripts/init-databases.sh"
fi
