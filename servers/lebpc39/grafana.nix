{ config, lib, pkgs, ... }:

# Grafana, for dashboards over the environmental sensor data in InfluxDB2
# (mqtt.nix, metrics.nix).
#
# Secrets are read from out-of-band files (see README.md) and handed to the
# service as systemd credentials, so the files themselves can stay readable
# by root only. Grafana reads them through its $__file{} provider.
let
  credentials = "/run/credentials/grafana.service";
in
{
  services.grafana = {
    enable = true;

    # Empty, read-only plugin directory: plugins can't be installed from the
    # UI, and Grafana doesn't try to download any at startup. The InfluxDB
    # datasource is built in.
    declarativePlugins = [ ];

    settings = {
      server = {
        # Loopback only.
        http_addr = "127.0.0.1";
        http_port = 3000;
      };

      security = {
        admin_user = "admin";
        admin_password = "$__file{${credentials}/admin-password}";
        # Encrypts datasource secrets in Grafana's database. Changing it
        # later makes the stored secrets unreadable.
        secret_key = "$__file{${credentials}/secret-key}";
      };
    };
  };

  systemd.services.grafana.serviceConfig = {
    LoadCredential = [
      "admin-password:/etc/grafana/secrets/admin.password"
      "secret-key:/etc/grafana/secrets/secret.key"
    ];

    # Network: only talk to localhost (Caddy, InfluxDB2). Grafana has no
    # need to reach the internet with plugins and update checks off.
    IPAddressDeny = "any";
    IPAddressAllow = "localhost";
  };
}
