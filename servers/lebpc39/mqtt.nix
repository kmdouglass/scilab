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
    };
  };
}
