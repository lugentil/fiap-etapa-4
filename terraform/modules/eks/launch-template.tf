resource "aws_launch_template" "nodes" {
  name        = "${var.project_name}-node-lt"
  description = "Launch template para EKS nodes com kubelet cert auto-assinado contendo IP SAN (workaround AWS Academy / EKS managed nao assina kubelet-serving CSR)"

  instance_type = var.node_instance_type

  user_data = base64encode(<<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="//"

    --//
    Content-Type: text/x-shellscript

    #!/bin/bash
    set +e
    exec > >(tee /var/log/kubelet-cert-bootstrap.log) 2>&1

    echo "[kubelet-cert-bootstrap] discovering node IP via IMDS..."
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
    PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
    HOSTNAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-hostname)
    echo "[kubelet-cert-bootstrap] PRIVATE_IP=$PRIVATE_IP HOSTNAME=$HOSTNAME"

    mkdir -p /var/lib/kubelet/pki
    cd /var/lib/kubelet/pki

    cat > /tmp/kubelet-cert.cnf <<CNF
    [req]
    distinguished_name = dn
    req_extensions = ext
    prompt = no
    [dn]
    CN = $HOSTNAME
    [ext]
    subjectAltName = @alt
    extendedKeyUsage = serverAuth
    [alt]
    DNS.1 = $HOSTNAME
    DNS.2 = localhost
    IP.1 = $PRIVATE_IP
    IP.2 = 127.0.0.1
    CNF

    openssl genrsa -out kubelet-server.key 2048
    openssl req -new -x509 -key kubelet-server.key -out kubelet-server.crt -days 3650 \
      -config /tmp/kubelet-cert.cnf -extensions ext

    chmod 600 kubelet-server.key
    chmod 644 kubelet-server.crt
    echo "[kubelet-cert-bootstrap] generated cert with SAN IP=$PRIVATE_IP DNS=$HOSTNAME"
    openssl x509 -in kubelet-server.crt -noout -text | grep -A 2 "Subject Alternative Name"

    --//
    Content-Type: application/node.eks.aws

    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      kubelet:
        config:
          tlsCertFile: /var/lib/kubelet/pki/kubelet-server.crt
          tlsPrivateKeyFile: /var/lib/kubelet/pki/kubelet-server.key
          serverTLSBootstrap: false
    --//--
  EOT
  )

  lifecycle {
    create_before_destroy = true
  }
}
