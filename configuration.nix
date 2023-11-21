# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, lib, pkgs, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-23.05.tar.gz";
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
  username = "koneko";
  createCifsMount = where: what: {
    device = what;
    fsType = "cifs";
    options = [
      "_netdev"
      "credentials=/etc/nixos/smb-secrets"
      "iocharset=utf8"
      "file_mode=0777"
      "dir_mode=0777"
      "soft"
      "noatime"
      "noperm"
      "x-gvfs-hide"
    ];
  };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (import "${home-manager}/nixos")
      "${impermanence}/nixos.nix"
    ];
 
  programs.fuse.userAllowOther = true;

  nixpkgs.config.allowUnfree = true;

  hardware = {
    enableAllFirmware = true;
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
#    nvidia = {
#      modesetting.enable = true;
#      powerManagement.enable = false;
#      powerManagement.finegrained = false;
#      open = true;
#      nvidiaSettings = true;
#      package = config.boot.kernelPackages.nvidiaPackages.stable;
#    };
    pulseaudio.enable = true;
  };

  boot = {
    supportedFilesystems = [ "btrfs" ];
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 3;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  sound.enable = true;

  networking.hostName = "NixNeko"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  services = {
    gvfs.enable = true;
    xserver = {
      # Enable the X11 windowing system.
      enable = true;
      layout = "us";
     # videoDrivers = ["nvidia"];

      # Enable the GNOME Desktop Environment.
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };
    printing.enable = true;
  };

  fileSystems."/mnt/scratch" = createCifsMount "/mnt/scratch" "//192.168.1.254/Scratch";
  fileSystems."/home/${username}/Documents" = createCifsMount "/home/${username}/Documents" "//192.168.1.254/documents";
  fileSystems."/home/${username}/Music" = createCifsMount "/home/${username}/Music" "//192.168.1.254/music";
  fileSystems."/home/${username}/Pictures" = createCifsMount "/home/${username}/Pictures" "//192.168.1.254/photo";
  fileSystems."/home/${username}/Videos" = createCifsMount "/home/${username}/Videos" "//192.168.1.254/homes/plex";

  users = {
    mutableUsers = false;
    users.root.initialPassword = "";
    users.${username} = {
      isNormalUser = true;
      # mkpasswd -m SHA-512 -s
      initialHashedPassword = "";
      extraGroups = [ "wheel" "video" "audio" "networkmanager" "lp" ]; # Enable ‘sudo’ for the user.
      packages = with pkgs; [
        firefox
        vmware-workstation
        brave
        libreoffice-fresh
        tauon
        sublime
        discord
        variety
        synergy
        dropbox
        firefox
        gimp-with-plugins
        makemkv
        mkvtoolnix
        rawtherapee
        zoom
        steam
        asunder
        transmission
      ];
    };
  };

  home-manager.users.${username} = {
    home.homeDirectory = "/home/${username}";
    imports = [ "${impermanence}/home-manager.nix" ];

    programs = {
      home-manager.enable = true;
  #    git = {   # can use home-manager normally as well as with persistence
  #      enable = true;
  #      userName  = "Example";
  #      userEmail = "Example@example.com";
  #    };
    };

    home.persistence."/nix/persist/homefiles" = {
        removePrefixDirectory = true;   # for GNU Stow styled dotfile folders
        allowOther = true;
        directories = [
          "autostart"   
          "variety"
    #      "Clementine/.config/Clementine"
    #        # fuse mounted from /nix/dotfiles/Firefox/.mozilla to /home/$USERNAME/.mozilla
    #      "Firefox/.mozilla"
        ];
    #    files = [
    #      "Atom/.atom/config.cson"
    #      "Atom/.atom/github.cson"
    #    ];
      };
      home.stateVersion = "23.05";
    };

  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-23.05";

  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    # machine-id is used by systemd for the journal, if you don't
    # persist this file you won't be able to easily use journalctl to
    # look at journals for previous boots.
    etc."machine-id".source = "/nix/persist/machine-id";
    systemPackages = with pkgs; [
      nano # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      wget
      open-vm-tools
      git
      cifs-utils
      wine
      winetricks
    ];
    persistence."/nix/persist/system" = { 
      directories = [
        "/etc/nixos"    # bind mounted from /nix/persist/system/etc/nixos to /etc/nixos
        "/etc/NetworkManager"
        "/var/log"
        "/var/lib"
      ];
      files = [
        #  NOTE: if you persist /var/log directory,  you should persist /etc/machine-id as well
        #  otherwise it will affect disk usage of log service
        #"/etc/nix/id_rsa"
      ];
    };
  };

  nix = {
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    package = pkgs.nixFlakes;
    extraOptions = "experimental-features = nix-command flakes";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Enable VMWare tools
  virtualisation.vmware.guest.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
