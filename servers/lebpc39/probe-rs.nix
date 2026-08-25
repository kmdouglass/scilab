{ pkgs, ... }:

{
  # For probe-rs-tools to access USB debug probes without root privileges
  users.groups.plugdev = { };
  users.users.douglass.extraGroups = [ "plugdev" ];

  services.udev.packages = [ pkgs.probe-rs-tools ];
}
