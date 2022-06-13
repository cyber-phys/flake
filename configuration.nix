{ pkgs, user, ... }:

{
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  nixpkgs.overlays = [
    (self: super: with super; {

      self.maintainers = super.maintainers.override {
        lolisamurai = {
          email = "lolisamurai@animegirls.xyz";
          github = "Francesco149";
          githubId = 973793;
          name = "Francesco Noferi";
        };
      };

      chatterino7 = chatterino2.overrideAttrs (old: rec {
        pname = "chatterino7";
        version = "7.3.5";
        src = fetchFromGitHub {
          owner = "SevenTV";
          repo = pname;
          rev = "v${version}";
          sha256 = "sha256-lFzwKaq44vvkbVNHIe0Tu9ZFXUUDlWVlNXI40kb1GEM=";
          fetchSubmodules = true;
        };
        # required for 7tv emotes to be visible
        # TODO: is this robust? in an actual package definition we wouldn't have qt5,
        #       but just self.qtimageformats doesn't work. what if qt version changes
        buildInputs = old.buildInputs ++ [ self.qt5.qtimageformats ];
        meta.description = old.meta.description + ", with 7tv emotes";
        meta.homepage = "https://github.com/SevenTV/chatterino7";
        meta.changelog = "https://github.com/SevenTV/chatterino7/releases";
      });

      pxplus-ibm-vga8-bin = let
        pname = "pxplus-ibm-vga8-bin";
        bname = "PxPlus_IBM_VGA8";
        ttfname = "${bname}.ttf";
        fname = "${bname}.otf";
      in stdenv.mkDerivation {
        pname = pname;
        version = "2022-06-02-r8";
        src = fetchFromGitHub {
          owner = "pocketfood";
          repo = "Fontpkg-PxPlus_IBM_VGA8";
          rev = "bf08976574bbaf4c9efb208025c71109a07e259f";
          sha256 = "sha256-WMNqehxLBeo4YC8QrH/UFSh3scvs7oAAPenPhyJ+UVA=";
        };
        nativeBuildInputs = [ pkgs.fontforge ];
        buildPhase = ''
          runHook preBuild
          fontforge -lang=py -c "import fontforge; from sys import argv; \
            f = fontforge.open(argv[1]); f.generate(argv[2]);" "${ttfname}" "${fname}"
          runHook postBuild
        '';
        installPhase = ''
          install -Dm 444 "${fname}" "$out/share/fonts/truetype/${pname}.otf"
        '';

        meta = with lib; {
          description = "monospace pixel font";
          homepage = "https://int10h.org/oldschool-pc-fonts/fontlist/font?ibm_vga_8x16";
          license = with licenses; [ cc-by-sa-40 ];
          platforms = platforms.all;
          maintainers = with maintainers; [ lolisamurai ];
        };
      };

    })
  ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";
  boot.kernelParams = [
    "amd_iommu=on"
    "intel_iommu=on"
    "iommu=pt"
    "rd.driver.pre=vfio-pci"
    "pcie_acs_override=downstream,multifunction"
    "usbhid.kbpoll=1"
    "usbhid.mousepoll=1"
    "usbhid.jspoll=1"
    "noibrs"
    "noibpb"
    "nopti"
    "nospectre_v2"
    "nospectre_v1"
    "l1tf=off"
    "nospec_store_bypass_disable"
    "no_stf_barrier"
    "mds=off"
    "mitigations=off"
    "zfs.zfs_arc_max=2147483648"
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "nixos";
    domain = "localhost";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = false;
    nameservers = [ "8.8.8.8" ];
    resolvconf.enable = false;
  };

  # bridge + tap setup for qemu
  networking.bridges.br0 = {
    rstp = false;
    interfaces = [ "eth0" ];
  };

  networking.interfaces.br0.virtual = true;

  environment.etc."qemu/bridge.conf".text = "allow br0";

  networking.interfaces.tap0 = {
    virtualOwner = "${user}";
    virtual = true;
    virtualType = "tap";
    useDHCP = true;
  };

  networking.defaultGateway = {
    interface = "br0";
    address = "192.168.1.1";
  };

  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "en_US.UTF-8";

  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # bluetooth
  hardware.bluetooth = {
    enable = true;

    # TODO: is this still doing anything?
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };

  services.blueman.enable = true;

  # TODO: check if this is actually required for bluetooth
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  services.gvfs.enable = true; # for nautilus
  services.udisks2.enable = true; # to mount removable devices more easily

  services.xserver = {
    enable = true;
    layout = "us";
    displayManager.gdm.enable = true;
    displayManager.gdm.wayland = false;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "${user}";
  };

  services.xserver.desktopManager.session = [
    {
      name = "home-manager";
      start = ''
        ${pkgs.runtimeShell} $HOME/.hm-xsession &
        waitPID=$!
      '';
    }
  ];

  # workaround for race condition in autologin
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # don't wanna get suck in emergency mode over benign errors
  systemd.enableEmergencyMode = false;

  services.xserver.libinput = {
    enable = true;
    mouse.accelProfile = "flat";
    touchpad.accelProfile = "flat";
  };

  services.xserver.xkbOptions = "caps:escape";

  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  programs.mtr.enable = true;
  services.openssh.enable = true;

  system.stateVersion = "22.05";
}
