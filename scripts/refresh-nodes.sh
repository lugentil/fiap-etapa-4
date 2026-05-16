#!/usr/bin/env bash
# Forca o EKS a recriar os nodes do node group atual.
# Necessario quando o kubelet ficou com TLS quebrado e os addons base foram
# atualizados (vpc-cni, kube-proxy, coredns). Os addons reconfiguram os pods
# do daemonset, mas o kubelet em si so reinicia o TLS bootstrap quando o node
# e recriado.
#
# Uso: bash scripts/refresh-nodes.sh

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-togglemaster-cluster}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

echo "Forcando update do node group para criar instancias novas..."
aws eks update-nodegroup-version \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "togglemaster-nodes" \
  --force \
  --region "$REGION"

echo
echo "Aguardando node group voltar a ACTIVE (pode levar 5-10min)..."
aws eks wait nodegroup-active \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "togglemaster-nodes" \
  --region "$REGION"

echo
echo "Nodes apos refresh:"
kubectl get nodes -o wide

echo
echo "Pronto. Agora roda 'kubectl logs' em qualquer pod para confirmar que o TLS voltou."
