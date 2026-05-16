#!/bin/bash
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
PROJECT="togglemaster"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERRO]${NC} $1"; }
step() { echo -e "\n${YELLOW}========== $1 ==========${NC}"; }

wait_for() {
  local msg="$1" check_cmd="$2" max_wait="${3:-300}" elapsed=0
  echo -n "$msg"
  while eval "$check_cmd" &>/dev/null && [ $elapsed -lt $max_wait ]; do
    echo -n "."
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo " done (${elapsed}s)"
}

step "1/11 — ECR Repositories"
for repo in $(aws ecr describe-repositories --region "$REGION" --query "repositories[].repositoryName" --output text 2>/dev/null); do
  aws ecr delete-repository --repository-name "$repo" --force --region "$REGION" 2>/dev/null && log "ECR: $repo" || warn "ECR: $repo (já deletado ou erro)"
done

step "2/11 — EKS Clusters"
for cluster in $(aws eks list-clusters --region "$REGION" --query "clusters[]" --output text 2>/dev/null); do
  for ng in $(aws eks list-nodegroups --cluster-name "$cluster" --region "$REGION" --query "nodegroups[]" --output text 2>/dev/null); do
    aws eks delete-nodegroup --cluster-name "$cluster" --nodegroup-name "$ng" --region "$REGION" 2>/dev/null && log "Nodegroup: $ng (deletando...)" || warn "Nodegroup: $ng"
  done
  for ng in $(aws eks list-nodegroups --cluster-name "$cluster" --region "$REGION" --query "nodegroups[]" --output text 2>/dev/null); do
    wait_for "  Esperando nodegroup $ng deletar" \
      "aws eks describe-nodegroup --cluster-name $cluster --nodegroup-name $ng --region $REGION 2>/dev/null" 600
  done
  aws eks delete-cluster --cluster-name "$cluster" --region "$REGION" 2>/dev/null && log "Cluster: $cluster (deletando...)" || warn "Cluster: $cluster"
done
for cluster in $(aws eks list-clusters --region "$REGION" --query "clusters[]" --output text 2>/dev/null); do
  wait_for "  Esperando cluster $cluster deletar" \
    "aws eks describe-cluster --name $cluster --region $REGION 2>/dev/null" 600
done

step "3/11 — RDS Instances"
for db in $(aws rds describe-db-instances --region "$REGION" --query "DBInstances[].DBInstanceIdentifier" --output text 2>/dev/null); do
  aws rds delete-db-instance --db-instance-identifier "$db" --skip-final-snapshot --delete-automated-backups --region "$REGION" 2>/dev/null \
    && log "RDS: $db (deletando...)" || warn "RDS: $db"
done
for db in $(aws rds describe-db-instances --region "$REGION" --query "DBInstances[].DBInstanceIdentifier" --output text 2>/dev/null); do
  wait_for "  Esperando RDS $db deletar" \
    "aws rds describe-db-instances --db-instance-identifier $db --region $REGION 2>/dev/null" 600
done

step "4/11 — ElastiCache"
for cache in $(aws elasticache describe-cache-clusters --region "$REGION" --query "CacheClusters[].CacheClusterId" --output text 2>/dev/null); do
  aws elasticache delete-cache-cluster --cache-cluster-id "$cache" --region "$REGION" 2>/dev/null \
    && log "ElastiCache: $cache (deletando...)" || warn "ElastiCache: $cache"
done

step "5/11 — SQS Queues"
for queue in $(aws sqs list-queues --region "$REGION" --query "QueueUrls[]" --output text 2>/dev/null); do
  aws sqs delete-queue --queue-url "$queue" --region "$REGION" 2>/dev/null && log "SQS: $queue" || warn "SQS: $queue"
done

step "6/11 — DynamoDB Tables"
for table in $(aws dynamodb list-tables --region "$REGION" --query "TableNames[]" --output text 2>/dev/null); do
  aws dynamodb delete-table --table-name "$table" --region "$REGION" 2>/dev/null && log "DynamoDB: $table" || warn "DynamoDB: $table"
done

step "7/11 — Load Balancers"
for lb in $(aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[].LoadBalancerArn" --output text 2>/dev/null); do
  for listener in $(aws elbv2 describe-listeners --load-balancer-arn "$lb" --region "$REGION" --query "Listeners[].ListenerArn" --output text 2>/dev/null); do
    aws elbv2 delete-listener --listener-arn "$listener" --region "$REGION" 2>/dev/null
  done
  aws elbv2 delete-load-balancer --load-balancer-arn "$lb" --region "$REGION" 2>/dev/null && log "ELBv2: $lb" || warn "ELBv2: $lb"
done
for lb in $(aws elb describe-load-balancers --region "$REGION" --query "LoadBalancerDescriptions[].LoadBalancerName" --output text 2>/dev/null); do
  aws elb delete-load-balancer --load-balancer-name "$lb" --region "$REGION" 2>/dev/null && log "Classic ELB: $lb" || warn "Classic ELB: $lb"
done
for tg in $(aws elbv2 describe-target-groups --region "$REGION" --query "TargetGroups[].TargetGroupArn" --output text 2>/dev/null); do
  aws elbv2 delete-target-group --target-group-arn "$tg" --region "$REGION" 2>/dev/null && log "Target Group: $tg" || warn "TG: $tg"
done

step "8/11 — Esperando ENIs liberarem"
sleep 30

for sg in $(aws rds describe-db-subnet-groups --region "$REGION" --query "DBSubnetGroups[].DBSubnetGroupName" --output text 2>/dev/null); do
  aws rds delete-db-subnet-group --db-subnet-group-name "$sg" --region "$REGION" 2>/dev/null && log "DB Subnet Group: $sg" || warn "DB Subnet Group: $sg"
done
for sg in $(aws elasticache describe-cache-subnet-groups --region "$REGION" --query "CacheSubnetGroups[].CacheSubnetGroupName" --output text 2>/dev/null); do
  [ "$sg" = "default" ] && continue
  aws elasticache delete-cache-subnet-group --cache-subnet-group-name "$sg" --region "$REGION" 2>/dev/null && log "Cache Subnet Group: $sg" || warn "Cache Subnet Group: $sg"
done

step "9/11 — VPC Cleanup"

for VPC_ID in $(aws ec2 describe-vpcs --region "$REGION" --filters "Name=isDefault,Values=false" --query "Vpcs[].VpcId" --output text 2>/dev/null); do
  log "Limpando VPC: $VPC_ID"

  for nat in $(aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" --query "NatGateways[].NatGatewayId" --output text 2>/dev/null); do
    aws ec2 delete-nat-gateway --nat-gateway-id "$nat" --region "$REGION" 2>/dev/null && log "  NAT: $nat"
  done

  NAT_COUNT=$(aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=deleting" --query "length(NatGateways)" --output text 2>/dev/null)
  if [ "${NAT_COUNT:-0}" -gt 0 ]; then
    wait_for "  Esperando NAT Gateways deletarem" \
      "[ \$(aws ec2 describe-nat-gateways --region $REGION --filter 'Name=vpc-id,Values=$VPC_ID' 'Name=state,Values=deleting' --query 'length(NatGateways)' --output text 2>/dev/null) -gt 0 ]" 180
  fi

  for eni in $(aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkInterfaces[].NetworkInterfaceId" --output text 2>/dev/null); do
    ATTACH_ID=$(aws ec2 describe-network-interfaces --region "$REGION" --network-interface-ids "$eni" --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null)
    if [ "$ATTACH_ID" != "None" ] && [ -n "$ATTACH_ID" ]; then
      aws ec2 detach-network-interface --attachment-id "$ATTACH_ID" --force --region "$REGION" 2>/dev/null
      sleep 5
    fi
    aws ec2 delete-network-interface --network-interface-id "$eni" --region "$REGION" 2>/dev/null && log "  ENI: $eni" || warn "  ENI: $eni (pode ser gerenciada)"
  done

  for eip in $(aws ec2 describe-addresses --region "$REGION" --filters "Name=domain,Values=vpc" --query "Addresses[].AllocationId" --output text 2>/dev/null); do
    aws ec2 disassociate-address --allocation-id "$eip" --region "$REGION" 2>/dev/null
    aws ec2 release-address --allocation-id "$eip" --region "$REGION" 2>/dev/null && log "  EIP: $eip" || warn "  EIP: $eip"
  done

  for sg in $(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null); do
    aws ec2 describe-security-groups --region "$REGION" --group-ids "$sg" --query "SecurityGroups[0].IpPermissions" --output json 2>/dev/null | \
      aws ec2 revoke-security-group-ingress --group-id "$sg" --ip-permissions file:///dev/stdin --region "$REGION" 2>/dev/null || true
    aws ec2 describe-security-groups --region "$REGION" --group-ids "$sg" --query "SecurityGroups[0].IpPermissionsEgress" --output json 2>/dev/null | \
      aws ec2 revoke-security-group-egress --group-id "$sg" --ip-permissions file:///dev/stdin --region "$REGION" 2>/dev/null || true
  done
  for attempt in 1 2; do
    for sg in $(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null); do
      aws ec2 delete-security-group --group-id "$sg" --region "$REGION" 2>/dev/null && log "  SG: $sg" || true
    done
  done

  for rt in $(aws ec2 describe-route-tables --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null); do
    for assoc in $(aws ec2 describe-route-tables --region "$REGION" --route-table-ids "$rt" --query 'RouteTables[0].Associations[?Main!=`true`].RouteTableAssociationId' --output text 2>/dev/null); do
      aws ec2 disassociate-route-table --association-id "$assoc" --region "$REGION" 2>/dev/null && log "  RT Disassoc: $assoc"
    done
    aws ec2 delete-route-table --route-table-id "$rt" --region "$REGION" 2>/dev/null && log "  RT: $rt" || warn "  RT: $rt"
  done

  for subnet in $(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text 2>/dev/null); do
    aws ec2 delete-subnet --subnet-id "$subnet" --region "$REGION" 2>/dev/null && log "  Subnet: $subnet" || warn "  Subnet: $subnet"
  done

  for igw in $(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null); do
    aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$VPC_ID" --region "$REGION" 2>/dev/null
    aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region "$REGION" 2>/dev/null && log "  IGW: $igw" || warn "  IGW: $igw"
  done

  aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION" 2>/dev/null && log "  VPC: $VPC_ID deletada!" || err "  VPC: $VPC_ID (ainda tem dependências)"
done

step "10/11 — Elastic IPs soltas"
for eip in $(aws ec2 describe-addresses --region "$REGION" --query "Addresses[?AssociationId==null].AllocationId" --output text 2>/dev/null); do
  aws ec2 release-address --allocation-id "$eip" --region "$REGION" 2>/dev/null && log "EIP solta: $eip"
done

step "11/11 — Terraform State (S3)"
BUCKET="${PROJECT}-terraform-state"
if aws s3 ls "s3://$BUCKET" --region "$REGION" 2>/dev/null; then
  warn "Bucket S3 '$BUCKET' existe. Para deletar rode:"
  warn "  aws s3 rb s3://$BUCKET --force --region $REGION"
else
  log "Bucket S3 '$BUCKET' não encontrado (já deletado ou nunca criado)"
fi

echo ""
echo -e "${GREEN}========== Limpeza concluída! ==========${NC}"
echo "Se algum recurso falhou, rode o script novamente após alguns minutos."
echo "Alguns recursos (EKS, RDS) podem levar até 10min pra desaparecer."
