#!/usr/bin/env bash
# Diagnostico de cluster EKS quando ha falha de TLS no kubelet.
# Rode: bash scripts/diagnose-cluster.sh > diagnose.log 2>&1
# Depois cole o conteudo de diagnose.log no chat.

set +e
echo "=========================================="
echo "1. Nodes e versoes"
echo "=========================================="
kubectl get nodes -o wide
echo
kubectl describe nodes | head -200

echo "=========================================="
echo "2. CSRs pendentes (kubelet bootstrap)"
echo "=========================================="
kubectl get csr -o wide

echo "=========================================="
echo "3. Pods do kube-system (CNI, kube-proxy, coredns, ebs-csi)"
echo "=========================================="
kubectl get pods -n kube-system -o wide

echo "=========================================="
echo "4. EKS addons instalados"
echo "=========================================="
aws eks list-addons --cluster-name togglemaster-cluster --region us-east-1
echo
for addon in vpc-cni coredns kube-proxy aws-ebs-csi-driver; do
  echo "--- $addon ---"
  aws eks describe-addon --cluster-name togglemaster-cluster --addon-name $addon --region us-east-1 2>/dev/null | jq -r '.addon | {status, addonVersion, health}' 2>/dev/null || echo "(nao instalado)"
done

echo "=========================================="
echo "5. Eventos recentes (top 30, ordenados)"
echo "=========================================="
kubectl get events -A --sort-by=.lastTimestamp | tail -30

echo "=========================================="
echo "6. EBS CSI Controller - describe (sem logs)"
echo "=========================================="
kubectl describe pod -n kube-system -l app=ebs-csi-controller | head -150

echo "=========================================="
echo "7. aws-node (VPC CNI) - describe"
echo "=========================================="
kubectl describe pod -n kube-system -l k8s-app=aws-node | head -100

echo "=========================================="
echo "8. metrics-server - describe"
echo "=========================================="
kubectl describe pod -n kube-system -l app.kubernetes.io/name=metrics-server | head -100

echo "=========================================="
echo "9. Tentar logs via API com flag de previous"
echo "=========================================="
kubectl logs -n kube-system -l k8s-app=aws-node --previous --tail=50 2>&1 | head -50

echo "=========================================="
echo "10. Instancias EC2 do node group"
echo "=========================================="
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=togglemaster-nodes" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{ID:InstanceId,IP:PrivateIpAddress,State:State.Name,LaunchTime:LaunchTime}' \
  --output table --region us-east-1

echo
echo "=========================================="
echo "FIM do diagnostico"
echo "=========================================="
