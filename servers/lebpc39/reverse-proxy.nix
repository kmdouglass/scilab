{ config, lib, pkgs, ... }:

let
  # Apps listed on the /streamlit landing page. Each app also needs its own
  # `handle` block below (reverse-proxying to its own port/subpath) and, for
  # Streamlit apps, STREAMLIT_SERVER_BASE_URL_PATH set to match.
  apps = [
    { name = "Focus Field Viewer"; path = "/ffv/"; }
  ];

  landingPage = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>lebpc39 apps</title>
    </head>
    <body>
      <h1>lebpc39 apps</h1>
      <ul>
        ${lib.concatMapStringsSep "\n        " (a: ''<li><a href="${a.path}">${a.name}</a></li>'') apps}
      </ul>
    </body>
    </html>
  '';
in
{
  networking.firewall.allowedTCPPorts = [ 80 ];

  services.caddy = {
    enable = true;
    # No TLS cert on this LAN-only server
    globalConfig = "auto_https off";
    virtualHosts."http://lebpc39.epfl.ch, http://lebpc39" = {
      extraConfig = ''
        redir /streamlit /streamlit/ 308

        handle_path /streamlit/* {
          root * ${landingPage}
          file_server
        }

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
