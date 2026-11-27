{ config, lib, pkgs, ... }:

# Grafana, for dashboards over, for example, the environmental sensor data in InfluxDB2
# (mqtt.nix, metrics.nix).
#
# Secrets are read from out-of-band files (see README.md) and handed to the
# service as systemd credentials, so the files themselves can stay readable
# by root only. Grafana reads them through its $__file{} provider.
let
  credentials = "/run/credentials/grafana.service";

  # Dashboards are defined in ./dashboards and provisioned read-only: change
  # them here, not in the UI.
  dashboards = pkgs.writeTextDir "environment.json"
    (builtins.toJSON (import ./dashboards/environment.nix { inherit lib; }));
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

        # Reached through Caddy at /grafana/ (reverse-proxy.nix). Grafana
        # builds its links and redirects from root_url, and with
        # serve_from_sub_path expects requests to keep the /grafana prefix.
        domain = "lebpc39.epfl.ch";
        root_url = "http://%(domain)s/grafana/";
        serve_from_sub_path = true;
      };

      security = {
        admin_user = "admin";
        admin_password = "$__file{${credentials}/admin-password}";
        # Encrypts datasource secrets in Grafana's database. Changing it
        # later makes the stored secrets unreadable.
        secret_key = "$__file{${credentials}/secret-key}";
      };

      # Visitors to /grafana/ land on the lab environment dashboard.
      dashboards.default_home_dashboard_path = "${dashboards}/environment.json";

      # Anyone on the LAN can view dashboards without logging in; editing
      # needs a login. "Main Org." is Grafana's default organization, which
      # must exist under this name. This is plain HTTP, so login passwords
      # cross the network unencrypted.
      "auth.anonymous" = {
        enabled = true;
        org_name = "Main Org.";
        org_role = "Viewer";
        hide_version = true;
      };
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [{
          name = "InfluxDB";
          uid = "influxdb";
          type = "influxdb";
          access = "proxy";
          url = "http://localhost:8086";
          isDefault = true;
          jsonData = {
            version = "Flux";
            organization = "LEB";
            defaultBucket = "leb_time_series_data";
          };
          # Read-only token for leb_time_series_data (metrics.nix).
          secureJsonData.token = "$__file{${credentials}/influxdb-token}";
        }];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [{
          name = "scilab";
          type = "file";
          allowUiUpdates = false;
          options.path = dashboards;
        }];
      };
    };
  };

  systemd.services.grafana.serviceConfig = {
    LoadCredential = [
      "admin-password:/etc/grafana/secrets/admin.password"
      "secret-key:/etc/grafana/secrets/secret.key"
      "influxdb-token:/etc/influxdb2/secrets/grafana.token"
    ];

    # Network: only talk to localhost (Caddy, InfluxDB2). Grafana has no
    # need to reach the internet with plugins and update checks off.
    IPAddressDeny = "any";
    IPAddressAllow = "localhost";
  };
}
