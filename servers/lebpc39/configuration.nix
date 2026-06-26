{ config, lib, pkgs, ... }:

let
  network = import ./network-local.nix;
in {
  imports = [
    ./hardware-configuration.nix
     inputs.sops-nix.nixosModules.sops
    ./mqtt.nix
  ];

  # Nix Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # SOPS
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nvidia-x11"
    "nvidia-settings"
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
