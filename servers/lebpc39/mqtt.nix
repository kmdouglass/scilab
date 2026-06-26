{ config, lib, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 1883 ];

  sops.secrets.mosquitto_username = { owner = "mosquitto"; group = "mosquitto"; };
  sops.secrets.mosquitto_password = { owner = "mosquitto"; group = "mosquitto"; };

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = 1883;
        users.douglass = {
          passwordFile = "/etc/mosquitto/secrets/douglass.password";
          acl = [ "readwrite #" ];
        };
      }
    ];
  };

  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs.mqtt_consumer = {
        servers = [ "tcp://localhost:1883" ];
        topics = [ "bsp125/#/SENSOR" ];
        data_format = "json";
        username = "";
        password = "";
      };

      outputs.file = {
        files = [ "stdout" ];
      };
    };
  };
}
