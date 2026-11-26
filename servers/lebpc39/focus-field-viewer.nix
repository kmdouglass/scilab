{ config, lib, pkgs, focus-field-viewer, ... }:

# Focus Field Viewer (github:LEB-EPFL/focus-field-viewer), a Streamlit app
# reached through Caddy at /ffv/ (reverse-proxy.nix).
#
# The upstream flake also ships a NixOS module, but it's deliberately not
# imported: a module is system configuration evaluated with full authority
# over the machine, so any upstream commit could add a root service, users,
# firewall rules, etc. Only the upstream *package* is taken here, and it runs
# under the sandbox below, so an upstream change can at most affect what the
# app itself does as an unprivileged, throwaway user.
let
  package = focus-field-viewer.packages.${pkgs.stdenv.hostPlatform.system}.default;
  port = 8501;
in
{
  systemd.services.focus-field-viewer = {
    description = "Focus Field Viewer";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      STREAMLIT_BROWSER_GATHER_USAGE_STATS = "false";
      # Must match the path proxied in reverse-proxy.nix, so Streamlit's
      # asset and websocket URLs line up with it.
      STREAMLIT_SERVER_BASE_URL_PATH = "ffv";
      # The DynamicUser has no writable home, so give matplotlib a persistent
      # cache dir (CacheDirectory below) for its font cache.
      MPLCONFIGDIR = "/var/cache/focus-field-viewer/matplotlib";
    };

    serviceConfig = {
      # Bound to loopback only: Caddy is the sole client.
      ExecStart = "${package}/bin/focus-field-viewer --server.address=127.0.0.1 --server.port=${toString port}";
      Restart = "on-failure";
      RestartSec = 5;

      # Unprivileged, transient UID with no capabilities.
      DynamicUser = true;
      # /var/cache/focus-field-viewer, owned by the dynamic user and writable
      # despite ProtectSystem = "strict".
      CacheDirectory = "focus-field-viewer";
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      NoNewPrivileges = true;
      PrivateUsers = true;

      # Filesystem: read-only system, no home dirs, private /tmp and /dev.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      UMask = "0077";

      # Kernel and process visibility.
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      # @resources is not denied: blocking it killed the app at startup
      # (signal SYS), as numerical runtimes (OpenBLAS, XLA thread pools) set
      # CPU affinity, memory policy, and rlimits. Blocked calls fail with
      # EPERM instead of killing the process.
      SystemCallFilter = [ "@system-service" "~@privileged" ];
      SystemCallErrorNumber = "EPERM";
      # Not set: MemoryDenyWriteExecute, since JAX's XLA compiler JITs code
      # into writable+executable memory.

      # Network: only talk to localhost (Caddy). Blocks any outbound
      # connections, e.g. exfiltration from a compromised dependency.
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
    };
  };
}
