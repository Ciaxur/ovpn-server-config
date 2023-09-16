#!/usr/bin/env bash

# Exit script on failure.
set -e

# Variables used throughout the script.
## CSRs
CSR_DIR="secrets-csr-configs"
ROOT_CSR_CONFIG_PATH="$CSR_DIR/ca_csr.config"
SVR_CSR_CONFIG_PATH="$CSR_DIR/server_csr.config"

## Secrets
ROOT_PKEY_PATH="rootCA.crt"
ROOT_SKEY_PATH="rootCA.key"
ROOT_CSR_PATH="rootCA.csr"
SVR_CSR_PATH="server.csr"
SVR_PKEY_PATH="server.crt"
SVR_SKEY_PATH="server.key"

## OpenSSL options
CERT_EXPIRE_DAYS=1825

# Verify CSR configs are present.
[ ! -f $ROOT_CSR_CONFIG_PATH ] && { echo "CA CSR Config not found. Create one as '$ROOT_CSR'"; exit 1; }
[ ! -f $SVR_CSR_CONFIG_PATH ] && { echo "Server CSR Config not found. Create one as '$SERVER_CSR'"; exit 1; }

echo "Generating Certificates (CA & Server)..."
# Generate Root CA.
echo "Generating an ED25519 RootCA key '$ROOT_SKEY_PATH' and csr config '$ROOT_CSR_CONFIG_PATH'..."
openssl genpkey -algorithm ed25519 -out "$ROOT_SKEY_PATH"
openssl req \
  -new \
  -batch \
  -key "$ROOT_SKEY_PATH" \
  -out "$ROOT_CSR_PATH" \
  -config "$ROOT_CSR_CONFIG_PATH"

# Self-sign Root CA.
echo "Generating a self-signed root certificate '$ROOT_PKEY_PATH'"
openssl x509 \
  -signkey "$ROOT_SKEY_PATH" \
  -in "$ROOT_CSR_PATH" \
  -req \
  -days $CERT_EXPIRE_DAYS \
  -out "$ROOT_PKEY_PATH"

# Generate Server Certificate.
echo "Generating an ED25519 Server key '$SVR_SKEY_PATH' using csr config '$SVR_CSR_CONFIG_PATH'"
openssl genpkey -algorithm ed25519 -out "$SVR_SKEY_PATH"
openssl req \
  -new \
  -batch \
  -key "$SVR_SKEY_PATH" \
  -out "$SVR_CSR_PATH" \
  -config "$SVR_CSR_CONFIG_PATH"

# Sign server certificate with the trusted CA.
echo "Signing server certificate csr '$SVR_CSR_PATH' using trusted CA '$ROOT_SKEY_PATH'..."
openssl x509 -req \
  -batch \
  -days "$CERT_EXPIRE_DAYS" \
  -in "$SVR_CSR_PATH" \
  -CA "$ROOT_PKEY_PATH" \
  -CAkey "$ROOT_SKEY_PATH" \
  -CAcreateserial \
  -out "$SVR_PKEY_PATH" \
  -sha256

# Verify generated server cert is trusted.
echo "Verifying generated certs..."
openssl verify \
  -CAfile "$ROOT_PKEY_PATH" \
  "$SVR_PKEY_PATH"


# Generate DH Params file.
echo "Generating DH params, dh.pem. This could take a while..."
openssl dhparam -out dh.pem 4096

# Generate elliptic curve (HMAC) with DH params in mind (tls-auth).
echo "Generating elliptic curve(HMAC), ta.key, from DH params, dh.pem"
openvpn --genkey tls-auth ta.key

