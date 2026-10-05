{ config, lib, pkgs, ... }:

let
  # Apps listed on the /streamlit landing page. Each app also needs its own
  # `handle` block below (reverse-proxying to its own port/subpath) and, for
  # Streamlit apps, STREAMLIT_SERVER_BASE_URL_PATH set to match.
  apps = [
    { name = "Focus Field Viewer"; path = "/ffv/"; }
    { name = "PhD Goals"; path = "/goals/"; }
  ];

  # PhD goal tracker Gantt chart (github:LEB-EPFL/phd_goal_tracker). Its
  # `tracker.py publish` copies the page here over SSH as douglass.
  goalsDir = "/var/lib/phd-goals";

  # Fallback for GOALS_AUTH_HASH: the bcrypt hash of a random password that
  # was thrown away. If /etc/caddy/secrets.env is missing, /goals/ stays
  # locked instead of Caddy failing to start and taking every app down.
  goalsLockedHash = "$2a$14$i0EolGttc9aw//ScxMz/zecD7I.aJHAuAhrrSHjIsIey2yxn79E/O";

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

        redir /goals /goals/ 308

        # Password-protected: the page includes full SMART goal text. This is
        # plain HTTP, so the password only keeps casual visitors out.
        handle_path /goals/* {
          basic_auth {
            leb {$GOALS_AUTH_HASH:${goalsLockedHash}}
          }
          root * ${goalsDir}
          file_server
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
  systemd.tmpfiles.rules = [ "d ${goalsDir} 0755 douglass users -" ];

  # Supplies GOALS_AUTH_HASH; see README.md. The leading "-" lets Caddy start
  # without it (the goals page then stays locked).
  systemd.services.caddy.serviceConfig.EnvironmentFile = "-/etc/caddy/secrets.env";

  systemd.services.focus-field-viewer.environment.STREAMLIT_SERVER_BASE_URL_PATH = "ffv";
}
