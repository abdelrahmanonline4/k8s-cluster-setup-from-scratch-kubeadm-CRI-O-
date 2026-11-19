
#!/bin/bash
set -euo pipefail

# Step 1: Install dependencies
apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gpg \
  apt-transport-https \
  containernetworking-plugins \
  bash-completion

# Step 2: Disable swap
swapoff -a
sed -i '/\sswap\s/s/^/#/' /etc/fstab

# Step 3: Configure kernel modules
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Step 4: Configure sysctl
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Step 5: Configure repositories
K8S_VERSION="v1.32"
CRIO_VERSION="v1.32"

install -d -m 0755 /etc/apt/keyrings

# Kubernetes repository
curl -fsSL \
  https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

# CRI-O repository
curl -fsSL \
  https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_VERSION}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/cri-o.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/cri-o.list

# Step 6: Install CRI-O and Kubernetes
apt-get update

apt-get install -y \
  cri-o \
  kubelet \
  kubeadm \
  kubectl \
  cri-tools

apt-mark hold kubelet kubeadm kubectl

# Step 7: Start services
systemctl daemon-reload
systemctl enable --now crio
systemctl enable kubelet

# Step 8: Configure crictl
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/crio/crio.sock
image-endpoint: unix:///var/run/crio/crio.sock
timeout: 10
debug: false
EOF

# Step 9: Verify installation
echo "Checking CRI-O..."
systemctl status crio --no-pager

echo "Checking Kubernetes..."
kubeadm version -o short
kubectl version --client
crictl version

echo "Installation completed successfully."
