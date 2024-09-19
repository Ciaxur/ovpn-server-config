#!/usr/bin/env sh
set -xe

# Install socat, to relay to adjacent container within the deployment.
# This is used for proxying ssh to a local server.
apk add socat

# Grab the subnet that belongs to the bridged network interface attached
# to the container.
CONTAINER_BRIDGE_IP=$(ifconfig eth0 | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
CONTAINER_BRIDGE_SUBNET=$(ifconfig eth0 | sed -n 's/.*inet addr:\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
HOST_BRIDGE_IP="$CONTAINER_BRIDGE_SUBNET.1"

echo "Resolved host bridged ip: $HOST_BRIDGE_IP"

# Listen and forward ssh to the other container for which has network host
# access.
socat -ddd TCP-LISTEN:22,fork TCP:$HOST_BRIDGE_IP:22&

