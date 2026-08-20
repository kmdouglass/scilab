{ config, lib, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 80 ];

  services.caddy = {
    enable = true;
    # No TLS cert on this LAN-only server
    globalConfig = "auto_https off";
    virtualHosts."http://lebpc39.epfl.ch, http://lebpc39" = {
      extraConfig = ''
        redir /ffv /ffv/ 308

        handle /ffv/* {
          reverse_proxy localhost:8501
        }

        handle {
          respond "404 Not Found" 404
        }
      '';
    };
  };

  # focus-field-viewer's module (github:LEB-EPFL/focus-field-viewer,
  # nix/module.nix) has no subpath option, but Streamlit itself does:
  # server.baseUrlPath, settable via STREAMLIT_SERVER_BASE_URL_PATH. This
  # must match the path proxied above.
  systemd.services.focus-field-viewer.environment.STREAMLIT_SERVER_BASE_URL_PATH = "ffv";
}
