{ config, lib, pkgs, scilab-private, ... }:

let
  network = import "${scilab-private}/servers/lebpc39/network-local.nix";
in {
  imports = [
    ./hardware-configuration.nix
    ./bash-aliases.nix
    ./metrics.nix
    ./mqtt.nix
    ./probe-rs.nix
    ./remote.nix
    ./reverse-proxy.nix
  ];

  # Nix Flakes and CUDA cache
  # https://nixos.wiki/wiki/CUDA
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };

  # Enable nix-ld for remote VS Code development
  # https://nixos.wiki/wiki/Visual_Studio_Code#Remote_SSH
  programs.nix-ld.enable = true;

  # Misc. modules
  programs.direnv.enable = true;
  programs.ssh.startAgent = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-kernel-modules"
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hardware
  hardware.graphics.enable = true;
  hardware.nvidia.open = false;

  # Networking
  networking.hostName = "lebpc39";
  networking.useDHCP = false;
  networking.interfaces.enp0s25 = {
    ipv4.addresses = [{
      address = network.address;
      prefixLength = network.prefixLength;
    }];
  };
  networking.defaultGateway = network.gateway;
  networking.nameservers = network.nameservers;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Locale
  time.timeZone = "Europe/Amsterdam";

  # Users
  users.users.douglass = {
    isNormalUser = true;
    description = "Kyle Douglass";
    extraGroups = [ "wheel" ];
    shell = pkgs.bash;
    home = "/home/douglass";
    packages = with pkgs; [ tree ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBh9P2MQKwWvIupNMe29nyy/PknODm/Ydm4KH/LE3hk6"
    ];
  };

  # Packages
  environment.systemPackages = with pkgs; [
    git
    wget
  ];

  # Services
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # Storage
  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  # Do NOT change this value after the initial install. It maintains
  # compatibility with application data created on older NixOS versions.
  system.stateVersion = "25.11";
}
