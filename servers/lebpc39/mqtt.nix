{ config, lib, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 1883 ];

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = 1883;
        users.laboleb = {
          passwordFile = "/etc/mosquitto/secrets/laboleb.password";
          acl = [ "readwrite #" ];
        };
      }
    ];
  };

  services.telegraf = {
    enable = true;
    environmentFiles = [ "/etc/telegraf/secrets.env" ];
    extraConfig = {
      inputs.mqtt_consumer = {
        servers = [ "tcp://localhost:1883" ];
        topics = [ "bsp125/+/SENSOR" ];
        data_format = "json";
        username = "$MQTT_USERNAME";
        password = "$MQTT_PASSWORD";
      };

      outputs.file = {
        files = [ "stdout" ];
      };

      outputs.influxdb_v2 = {
        urls = [ "http://localhost:8086" ];
        token = "$INFLUX_TOKEN";
        organization = "LEB";
        bucket = "leb_time_series_data";
      };
    };
  };

  systemd.services.telegraf.after = [ "influxdb2.service" ];
  systemd.services.telegraf.wants = [ "influxdb2.service" ];
}
