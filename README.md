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

### OpenVPN Server Environment Setup
Within [openvpn-data/ovpn_env.sh](openvpn-data/ovpn_env.sh), modify the environment variables to satisfy
your OpenVPN Server needs. Within the mentioned script, here are the values needed
to populate:
> NOTE: These can be bypassed, since already being configured by [openvpn.conf](./openvpn.conf) file.

```sh
# Set your public facing IPv4 address or domain as a URL.
declare -x OVPN_SERVER_URL=udp://<IP/Domain>

# Set the OpenVPN Server subut to provide clients with.
declare -x OVPN_SERVER=10.8.0.0/24

# Set DNS servers to push to the client. Example:
declare -x OVPN_DNS_SERVERS=([0]="192.168.0.96")

# Set the server's Common Name. This can be the public facing IPv4 address or
# the domain name of the sever.
declare -x OVPN_CN=<IP/Domain>
```

### OpenVPN Client Setup
Using the [docker-compose-client.yaml](./docker-compose-client.yaml) file, the user can spin up a small container that establishing
a tunnel with a given server, provided under [openvpn-data/server.ovpn](./openvpn-data/server.ovpn), for which to be contained
within that container. This is to enable the user to build on top of an openvpn client.

The OpenVPN Client allows invoking a `background_task.sh`(*./openvpn-data/background_task.sh*) script as part of staring up
the container. This allows for extensive use of the client container.

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

### Run

#### Running an OpenVPN client within Docker
After going through the setup steps above, run the following:
```sh
$ docker compose -f docker-compose-client.yaml up
```

#### Running the OpenVPN server within Docker
Docker uses the OpenVPN config that is present within `openvpn-data/openvpn.conf`.
**NOTE:** Move [openvpn.conf](./openvpn.conf) into [openvpn-data](./openvpn-data).

> The current [docker-compose](./docker-compose.yaml) file assumes an `arm` architecture.
> For different architectures, modify the file's `dockerfile:` tag to point to the following
> for your respective architecture.

- `x86`: [Dockerfile](./docker-openvpn/Dockerfile)
- `armv7`: [Dockerfile.arm](./docker-openvpn/Dockerfile.arm)
- `armv8`: [Dockerfile.aarch64](./docker-openvpn/Dockerfile.aarch64)


This project is configured to use docker compose. Make sure that's installed and then simply
run the following:
```sh
# This'll attach the current terminal session to the container.
$ docker compose up

# This'll daemonize it.
$ docker compose up -d
```

#### Running on bare-metal
With `openvpn` installed, run the following command:
```sh
$ sudo openvpn --config ./openvpn.conf
```

# DNS
## Updating DNS on a Linux client
Pushing DNS routes through dhcp-options from the server doesn't seem to play well with
NetworkManager/resolvd. There is a workaround which requires updating the client's ovpn config.

This workaround is documented & tracked on: https://github.com/alfredopalhares/openvpn-update-resolv-conf.


After grabbing the [update-resolv-conf script][update-resolv-conf] ([update-resolve-conf.sh](./scripts/update-resolv-conf.sh)), all that's required is to add
the following to the client's ovpn config, given the script lives in the user's working directory
when invoking openvpn:
```sh
script-security 2
up update-resolv-conf.sh
down update-resolv-conf.sh
```

# License
Licensed under the [GNU Public License V3.0](./LICENSE).


[update-resolv-conf]: https://github.com/alfredopalhares/openvpn-update-resolv-conf/blob/master/update-resolv-conf.sh

