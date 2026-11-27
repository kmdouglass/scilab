{ config, lib, pkgs, ... }:

{
    # Not exposed on the firewall or proxied through Caddy: InfluxDB2's UI
    # hardcodes absolute paths and has no subpath/base-URL config, so it
    # can't be reverse-proxied cleanly. Access it via SSH tunnel instead
    # -- see README.md.

    services.influxdb2 = {
        enable = true;
        provision.enable = true;
        provision.initialSetup = {
            bucket = "leb_time_series_data";
            organization = "LEB";
            passwordFile = "/etc/influxdb2/secrets/laboleb.password";
            tokenFile = "/etc/influxdb2/secrets/laboleb.token";
            username = "laboleb";
        };

        # The org and bucket created by initialSetup, declared again because
        # an auth's readBuckets may only name buckets declared here. The
        # provisioner updates existing ones in place; retention 0 (keep
        # forever) matches initialSetup.
        provision.organizations.LEB = {
            buckets.leb_time_series_data = { };

            # Read-only token for Grafana's datasource (grafana.nix).
            auths.grafana = {
                description = "Grafana (read-only)";
                readBuckets = [ "leb_time_series_data" ];
                tokenFile = "/etc/influxdb2/secrets/grafana.token";
            };
        };
    };
}
