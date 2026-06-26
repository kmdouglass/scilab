#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS="$REPO_ROOT/.private/lebpc39.secrets"
CONFIG_SRC="$REPO_ROOT/configs/configuration.nix.lebpc39"
MOSQUITTO_SRC="$REPO_ROOT/configs/mosquitto.nix.lebpc39"
REMOTE="douglass@lebpc39"
MQTT_PASSWORD_PATH="/etc/mosquitto/secrets/douglass.password"

if [[ ! -f "$SECRETS" ]]; then
    echo "Error: secrets file not found: $SECRETS" >&2
    exit 1
fi

source "$SECRETS"

: "${IP_ADDRESS:?IP_ADDRESS not set in $SECRETS}"
: "${DEFAULT_GATEWAY:?DEFAULT_GATEWAY not set in $SECRETS}"
: "${NAMESERVER_1:?NAMESERVER_1 not set in $SECRETS}"
: "${NAMESERVER_2:?NAMESERVER_2 not set in $SECRETS}"
: "${MQTT_PASSWORD:?MQTT_PASSWORD not set in $SECRETS}"

TMP=$(mktemp)
TMP_PASSWORD=$(mktemp)
trap 'rm -f "$TMP" "$TMP_PASSWORD"' EXIT

sed \
    -e "s/w\.w\.w\.w/$IP_ADDRESS/g" \
    -e "s/x\.x\.x\.x/$DEFAULT_GATEWAY/g" \
    -e "s/y\.y\.y\.y/$NAMESERVER_1/g" \
    -e "s/z\.z\.z\.z/$NAMESERVER_2/g" \
    "$CONFIG_SRC" > "$TMP"

printf '%s' "$MQTT_PASSWORD" > "$TMP_PASSWORD"

scp "$TMP" "$REMOTE":/tmp/configuration.nix
scp "$MOSQUITTO_SRC" "$REMOTE":/tmp/mosquitto.nix
scp "$TMP_PASSWORD" "$REMOTE":/tmp/mosquitto.password

# The MQTT password file is kept out of the Nix store: it's written to
# /etc directly and only chowned to the mosquitto user/group after
# nixos-rebuild switch has created that account.
ssh -t "$REMOTE" "
    set -euo pipefail
    sudo mv /tmp/configuration.nix /etc/nixos/configuration.nix
    sudo mv /tmp/mosquitto.nix /etc/nixos/mosquitto.nix
    sudo install -D -m 600 -o root -g root /tmp/mosquitto.password '$MQTT_PASSWORD_PATH'
    rm -f /tmp/mosquitto.password
    sudo nixos-rebuild switch
    sudo chown mosquitto:mosquitto '$MQTT_PASSWORD_PATH'
    sudo systemctl restart mosquitto
"
