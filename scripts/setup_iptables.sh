#!/usr/bin/env bash
# Forked from: https://gist.github.com/mattbell87/ec1c1fa974fa989249a4bd0fbc8b8857
set -ex

# Applies iptables rules to forward traffic from the tunneled interface onto
# the open internet.

# Grab cli args.
INTERNET_INTERFACE_NAME="$1"; shift
TUN_INTERFACE_NAME="$1"; shift

if [[ "$INTERNET_INTERFACE_NAME" = "" ]]; then
  echo -e "ERROR: Expected an interface name to forward traffic to.\n"
  exit 1
elif [[ "$TUN_INTERFACE_NAME" = "" ]]; then
  echo -e "ERROR: Expected the interface name of the tunnel to forward traffic from.\n"
  exit 1
fi

# Verify that ipv4 forwarding is enabled.
IPV4_FORWARDING_ENABLED=$(sysctl net.ipv4.ip_forward | grep -Eo '[0-9]+$')
if [[ $IPV4_FORWARDING_ENABLED != 1 ]]; then
  echo "ipv4 forwarding is not enabled"
  echo "Attempting to enable..."
  sysctl -w net.ipv4.ip_forward=1 || exit 1
fi

# Setup iptables
internet_eth="$INTERNET_INTERFACE_NAME"
tun_eth="$TUN_INTERFACE_NAME"
tun_subnet="10.8.0.0/24"

proto=udp
port=1194

# Logs
echo "Applying iptables rules on $internet_eth for $proto protocol on port $port."
echo "This allows forwarding of traffic from $tun_eth($tun_subnet) -> $internet_eth"

# OpenVPN
iptables -A INPUT -i "$internet_eth" -m state --state NEW -p "$proto" --dport "$port" -j ACCEPT

# Allow TUN interface connections to OpenVPN server
iptables -A INPUT -i "$tun_eth" -j ACCEPT

# Allow TUN interface connections to be forwarded through other interfaces
iptables -A FORWARD -i "$tun_eth" -j ACCEPT
iptables -A FORWARD -i "$tun_eth" -o "$internet_eth" -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i "$internet_eth" -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

# NAT the VPN client traffic to the internet
iptables -t nat -A POSTROUTING -s "$tun_subnet" -o "$internet_eth" -j MASQUERADE

