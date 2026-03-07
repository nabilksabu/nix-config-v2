# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:



{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

#fonts{
/*	fonts.packages=[
		pkgs.nerd-fonts.jetbrains-mono
	];
	fonts.fontconfig.defaultFonts={
	monospace=[
	"JetBrainsMono Nerd Font"
	];
	};

*/

#enable android compatibility layer (Waydroid)
virtualisation.waydroid.enable = true;
networking.nftables.enable = true;
  boot.kernelModules = [
    "binder_linux"
  ];



#enable flatpak support 
services.flatpak.enable = true;
xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;


#lock stuff for freq and cores for battery

boot.kernelParams = [
  "amd_pstate=active"
  "binder.devices=binder,hwbinder,vndbinder"
];
  powerManagement.enable = true;

  # Use EPP-aware governor
  powerManagement.cpuFreqGovernor = "powersave";

  systemd.services.amd-pstate-epp = {
    description = "Set AMD P-state EPP for battery efficiency";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        /bin/sh -c '
          for c in /sys/devices/system/cpu/cpu*/cpufreq; do
            if [ -f $c/energy_performance_preference ]; then
              echo power > $c/energy_performance_preference
            fi
          done
        '
      '';
    };
  };


#nvidia driver + OpenGL

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # hardware.opengl has beed changed to hardware.graphics

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia.modesetting.enable = true;
hardware.nvidia = {
  # Required for drivers >= 560
  open = true; # Set to false if you have an older card
  package = config.boot.kernelPackages.nvidiaPackages.latest;
};



#enable offload
hardware.nvidia.prime = {
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };

    # integrated
    amdgpuBusId = "PCI:5:0:0";
    
    # dedicated
    nvidiaBusId = "PCI:1:0:0";
  };


#turn off gpu
services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
  '';



#uninstall packages

environment.gnome.excludePackages = with pkgs; [
  epiphany
  gnome-tour
  gnome-contacts
  gnome-maps
  simple-scan
  totem    
  gnome-characters
  gnome-font-viewer
  gnome-connections
  eog              
  evince             
  gnome-music        
  geary               
  gnome-calculator
  gnome-weather
  gnome-calendar
  gnome-clocks
  snapshot            
  gnome-text-editor   
  pulseaudio 
  gnome-software     
  seahorse         
];

#remove cancer xterm
services.xserver.excludePackages = with pkgs; [
  xterm
];




  # Set your time zone.
  time.timeZone = "Asia/Kolkata";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_IN";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.ly.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome.core-apps.enable = false;
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nabil = {
    isNormalUser = true;
    description = "Nabil K Sabu";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  # programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
	wget
	fastfetch
	powertop
	git
	gh
	vscodium
	python315
	onlyoffice-desktopeditors
	discord
	pciutils
	pavucontrol
	htop
	librewolf
	kitty 
	gnome-terminal
	nautilus
(pkgs.callPackage (fetchTarball "https://github.com/nabilksabu/vantage-nix/archive/main.tar.gz") {})
  ];


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
