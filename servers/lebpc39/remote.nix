{ config, lib, pkgs, ... }:

let
  # Headless Xorg server bound to the GPU (display :0). VirtualGL renders
  # here; there is no monitor attached, so the nvidia driver is told to
  # start anyway.
  gpuXorgConf = pkgs.writeText "gpu-xorg.conf" ''
    Section "Module"
      Load "glx"
    EndSection

    Section "Device"
      Identifier "Device0"
      Driver "nvidia"
    EndSection

    Section "Screen"
      Identifier "Screen0"
      Device "Device0"
      Option "AllowEmptyInitialConfiguration" "true"
      Option "UseDisplayDevice" "none"
    EndSection

    Section "ServerLayout"
      Identifier "Layout0"
      Screen 0 "Screen0"
    EndSection
  '';

  # Starts the VNC session (display :1) that you actually connect to, with
  # icewm as the window manager, then vglrun bridges rendering from :1 to
  # the real GPU X server on :0.
  vncSessionStart = pkgs.writeShellScript "vnc-session-start" ''
    set -eu
    ${pkgs.tigervnc}/bin/Xvnc :1 \
      -localhost 1 \
      -SecurityTypes VncAuth \
      -PasswordFile /etc/tigervnc/secrets/douglass.password \
      -geometry 1920x1080 \
      -depth 24 &
    xvnc_pid=$!

    for _ in $(seq 1 20); do
      [ -S /tmp/.X11-unix/X1 ] && break
      sleep 0.5
    done

    DISPLAY=:1 ${pkgs.icewm}/bin/icewm-session &

    wait "$xvnc_pid"
  '';
in
{
  # No firewall port opened for VNC on purpose: the session is reached
  # only via `ssh -L 5901:localhost:5901 douglass@lebpc39` plus a local VNC
  # client pointed at localhost:5901 (Xvnc itself is also bound with
  # -localhost above).

  environment.systemPackages = [
    pkgs.virtualgl
    pkgs.tigervnc
    pkgs.icewm
  ];

  # Members can vglrun against the headless GPU X server on :0.
  users.groups.vglusers.members = [ "douglass" ];
  users.users.douglass.extraGroups = [ "video" "render" ];

  systemd.services.gpu-xorg = {
    description = "Headless X server bound to the NVIDIA GPU for VirtualGL";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.xorg-server}/bin/Xorg :0 -config ${gpuXorgConf} -nolisten tcp -ac -noreset";
      Restart = "always";
      RestartSec = 2;
    };
  };

  # Started on demand: `systemctl --user start tigervnc`. Run
  # `loginctl enable-linger douglass` once so it survives you closing the
  # SSH session that started it.
  systemd.user.services.tigervnc = {
    description = "TigerVNC remote desktop (icewm) for GPU-accelerated development";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${vncSessionStart}";
    };
  };
}
