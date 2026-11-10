{ ... }:

{
  # Weekly unattended upgrade to whatever is on main. The lock file is bumped
  # by .github/workflows/update-nixpkgs.yml, so this only ever picks up a
  # nixpkgs revision that has already built in CI.
  system.autoUpgrade = {
    enable = true;
    flake = "github:kmdouglass/scilab?dir=servers/lebpc39#lebpc39";
    # scilab-private is locked to a path that only exists on the deploying
    # machine, so the host keeps its own copy out-of-band (see README.md).
    flags = [
      "--override-input" "scilab-private" "path:/etc/scilab-private"
      "-L"
    ];
    upgrade = false;  # The flake lock pins nixpkgs; there is no channel to update.
    dates = "Thu 04:00";
    randomizedDelaySec = "45min";
    # Reboots only if the kernel, kernel modules, or initrd changed.
    allowReboot = true;
    rebootWindow = { lower = "03:00"; upper = "06:00"; };
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # /boot is 500 MB and each distinct kernel + initrd takes about 47 MB.
  boot.loader.systemd-boot.configurationLimit = 6;
}
