#!/bin/bash

set -e

CONTROL_PLANE_IP=(
    "192.168.100.10"
    "192.168.100.11"
    "192.168.100.12"
)

WORKER_IP=()

K8S_API_IP="192.168.100.100"

CLUSTER_NAME="talos"

talosctl gen secrets -o secrets.yaml

echo "Generating Talos config for cluster: $CLUSTER_NAME"
talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$K8S_API_IP:6443

echo "Patching node configs"
talosctl machineconfig patch controlplane.yaml --patch @controlplane-patch.yaml --output controlplane.yaml
talosctl machineconfig patch worker.yaml --patch @worker-patch.yaml --output worker.yaml

for ip in "${CONTROL_PLANE_IP[@]}"; do
  echo "=== Applying configuration to controlplane node $ip ==="
  talosctl apply-config --insecure \
    --nodes $ip \
    --file controlplane.yaml
  echo "Configuration applied to $ip"
  echo ""
done

for ip in "${WORKER_IP[@]}"; do
  echo "=== Applying configuration to worker node $ip ==="
  talosctl apply-config --insecure \
    --nodes $ip \
    --file worker.yaml
  echo "Configuration applied to $ip"
  echo ""
done

echo "Wait for nodes to become ready. Press any key to continue..."
read


echo "Merge with default talosconfig"
talosctl config merge ./talosconfig
mkdir -p ~/.talos
cp ./talosconfig ~/.talos/config
export TALOSCONFIG=~/.talos/config

talosctl config endpoint ${CONTROL_PLANE_IP[1]} ${CONTROL_PLANE_IP[2]} ${CONTROL_PLANE_IP[3]}

echo "Bootstrapping the first control plane node (${CONTROL_PLANE_IP[1]})"
talosctl bootstrap --nodes ${CONTROL_PLANE_IP[1]}

echo "Fetching kubeconfig from the cluster"
talosctl kubeconfig ./kubeconfig --nodes ${CONTROL_PLANE_IP[1]}
export KUBECONFIG=./kubeconfig
