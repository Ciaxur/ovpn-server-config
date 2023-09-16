#!/usr/bin/env bash

# Exit script on failure.
set -e

# Grab cli args.
TRUSTED_CA_PKEY_PATH="$1"; shift
TRUSTED_CA_SKEY_PATH="$1"; shift
TA_PATH="$1"; shift
CLIENT_CERT_NAME="$1"; shift
CLIENT_CSR_CONF_PATH="$1"; shift
SERVER_NAME="$1"; shift

# Function for printing help menu.
function print_help() {
  echo "Usage:"
  echo "  gen_client.sh [ca_pkey_path] [ca_skey_path] [ta_path] [client_cert_name] [client_csr_conf_path] [server_name]"
  echo "    ca_pkey_path          Path to the CA certificate"
  echo "    ca_skey_path          Path to the CA key"
  echo "    ta_path               Path to the elliptic curve(HMAC) file"
  echo "    client_cert_name      Name of the generated client secrets"
  echo "    client_csr_conf_path  Path to the client's csr config"
  echo "    server_name           Domain name of the OpenVPN server"
}

# Verify required params are passed in.
if [[ "$TRUSTED_CA_PKEY_PATH" = "" ]]; then
  echo -e "ERROR: Expected CA certificate filepath.\n"
  print_help
  exit 1
elif [[ "$TRUSTED_CA_SKEY_PATH" = "" ]]; then
  echo -e "ERROR: Expected CA key filepath.\n"
  print_help
  exit 1
elif [[ "$TA_PATH" = "" ]]; then
  echo -e "ERROR: Expected elliptic curve(HMAC) filepath.\n"
  print_help
  exit 1
elif [[ "$CLIENT_CERT_NAME" = "" ]]; then
  echo -e "ERROR: Expected client certificate name.\n"
  print_help
  exit 1
elif [[ "$CLIENT_CSR_CONF_PATH" = "" ]]; then
  echo -e "ERROR: Expected client CSR configuration filepath.\n"
  print_help
  exit 1
elif [[ "$SERVER_NAME" = "" ]]; then
  echo -e "ERROR: Expected server hostname.\n"
  print_help
  exit 1
fi


# Variables used throughout the script.
CLIENT_SKEY_FILENAME="$CLIENT_CERT_NAME.key"
CLIENT_PKEY_FILENAME="$CLIENT_CERT_NAME.crt"
CLIENT_CSR_FILENAME="$CLIENT_CERT_NAME.csr"
CLIENT_OVPN_FILENAME="$CLIENT_CERT_NAME.ovpn"
CERT_DAYS_TILL_EXPIRE="1825"

# Generate client key.
echo "Generating an ED25519 client key to '$CLIENT_SKEY_FILENAME'."
openssl genpkey \
  -algorithm ed25519 \
  -out "$CLIENT_SKEY_FILENAME"

# Generate client csr.
echo "Generating client csr to be signed by CA '$CLIENT_CSR_FILENAME'"
openssl req \
  -new \
  -batch \
  -key "$CLIENT_SKEY_FILENAME" \
  -out "$CLIENT_CSR_FILENAME" \
  -config "$CLIENT_CSR_CONF_PATH"

# Sign client certificate with a trusted CA
echo "Signing client csr '$CLIENT_CSR_FILENAME' using CA '$TRUSTED_CA_PKEY_PATH'. Expires in $CERT_DAYS_TILL_EXPIRE days."
openssl x509 -req \
      -days "$CERT_DAYS_TILL_EXPIRE" \
      -in "$CLIENT_CSR_FILENAME" \
      -CA "$TRUSTED_CA_PKEY_PATH" \
      -CAkey "$TRUSTED_CA_SKEY_PATH" \
      -CAcreateserial \
      -out "$CLIENT_PKEY_FILENAME" \
      -sha256

# Verify
openssl verify -CAfile "$TRUSTED_CA_PKEY_PATH" "$CLIENT_PKEY_FILENAME"

# Generate ovpn client config.
echo "Generating ovpn configuration for client under '$CLIENT_OVPN_FILENAME' for server name '$SERVER_NAME'"
ovpngen \
  "$SERVER_NAME" \
  "$TRUSTED_CA_PKEY_PATH" \
  "$CLIENT_PKEY_FILENAME" \
  "$CLIENT_CSR_FILENAME" \
  "$TA_PATH" > "$CLIENT_OVPN_FILENAME"

echo -e "Removing remote-cert-tls option from generated ovpn config."
sed -i 's/remote-cert-tls.*$//' "$CLIENT_OVPN_FILENAME"
