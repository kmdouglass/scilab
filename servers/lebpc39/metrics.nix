{ config, lib, pkgs, ... }:

{
    networking.firewall.allowedTCPPorts = [ 8086 ];

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
    };
}
