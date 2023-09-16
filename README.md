# OpenVPN Server Configuration
Generic OpenVPN server configuration for which to be supported in dockerized and
bare metal environments.

# Usage
## Requirements
- `OpenVPN` - For use on bare-metal
- `ovpngen` - For generating OpenVPN client configs
  - https://github.com/graysky2/ovpngen
- `docker compose` - For running the OpenVPN server instance in docker

## Generate Secrets
### Generate Root and Server secrets
If this is the first time generating secrets for the OpenVPN server, run the following
to generate server secrets:
```sh
# Change working directory into one which has the CRS configs.
$ cd secrets-csr-configs

# Generate RootCA and a server identity certs issued by that RootCA.
# Generates DH parameters and elliptic curve (HMAC) for security.
$ ..scripts/init_secrets.sh
```

This generates all secrets within the local directory.

Now we need to copy and use those within the mounted OpenVPN data(`openvpn-data`), for which to be used
by OpenVPN.
```sh
# NOTE: Make sure certs are present within the current working directory.
# Create CA and Server certs directory within the ovpn data directory.
$ mkdir ./openvpn-data/ca
$ mkdir ./openvpn-data/server

# Copy generated CAs.
$ cp rootCA.* ./openvpn-data/ca/

# Copy server identity certs.
$ cp server.crt server.key ./openvpn-data/server/
```

### Generate Client secrets
These secrets are to be used in generating an ovpn client configuration for which
includes the client's secrets to connect with the ovpn server.

Run the following to:
- Generate client secrets and
```sh
# Expects the following args:
# [ca_pkey_path] [ca_skey_path] [ta_path] [client_cert_name] [client_csr_conf_path] [server_name]
#
# Example generating a test client cert.
$ ./gen_client.sh ./openvpn-data/ca/rootCA.crt openvpn-data/ca/rootCA.key openvpn-data/server/ta.key test ./secrets-csr-configs/client_csr.conf some.server.com
```

### IP Tables Setup
There is a helper script for setting everything up called `setup_iptables.sh`. Simply invoke using `sudo`.

#### Why do we need to configure iptables?
iptables rules must be configured to allow forwarding of packets through the created VPN tunnel.

To enable the FORWARD chain wthin iptables, the kernel parameter `net.ipv4.ip_forward` enables that chain.

Can check the state of that parameter by running:
```sh
$ sysctl net.ipv4.ip_forward

# Enabled
net.ipv4.ip_forward = 1

# Disabled
net.ipv4.ip_forward = 0
```

To enable it, run:
```sh
# Under sudo, since it needs elevated permission.
$ sysctl -w net.ipv4.ip_forward=1
```

To do so, check which interface on the local device is used to route traffic to the open internet.
In this example, `end0` is that interface.
```sh
$ ip a
...
2: end0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether dc:a6:32:6a:9e:ad brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.96/24 metric 1024 brd 192.168.0.255 scope global end0
       valid_lft forever preferred_lft forever
    inet6 fe80::dea6:32ff:fe6a:9ead/64 scope link proto kernel_ll
       valid_lft forever preferred_lft forever
```

Invoke the [setup_iptables.sh](./scripts/setup_iptables.sh) script with that interface name:
```sh
# Applies iptable rules to forward and NAT traffic from tun0 to end0 interface.
$ setup_iptables.sh end0 tun0
```

## Running the OpenVPN server
To modify the OpenVPN config, that is present within `openvpn-data/openvpn.conf`.

This project is configured to use docker compose. Make sure that's installed and then simply
run the following:
```sh
# This'll attach the current terminal session to the container.
$ docker compose up

# This'll daemonize it.
$ docker compose up -d
```

### Run
#### Running the OpenVPN server within Docker
Docker uses the OpenVPN config that is present within `openvpn-data/openvpn.conf`.

This project is configured to use docker compose. Make sure that's installed and then simply
run the following:
```sh
# This'll attach the current terminal session to the container.
$ docker compose up

# This'll daemonize it.
$ docker compose up -d
```

#### Running on bare-metal
TODO:
