{ config, pkgs, lib, user, ... }:

let

  consts = import ../../common/consts.nix;
  inherit (consts.ssh) authorizedKeys;

  custom-obs = with pkgs;
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-gstreamer
        obs-move-transition
        obs-multi-rtmp
        obs-source-switcher
        obs-teleport
      ];
    });

in
{
  imports = [
    ./hardware-configuration.nix
    ../../common/mitigations/configuration.nix
    ../../common/i915/configuration.nix
    ../../common/nix/configuration.nix
    ../../common/locale/configuration.nix
    ../../common/gnome/configuration.nix
    ../../common/mpv/configuration.nix
    ../../common/autologin/configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "streampc";
  networking.networkmanager.enable = true;

  # ssh mainly to be able to build the system from tanuki or other pc's
  # don't wanna set up all the dev tools here when it's mainly for streaming
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    pulseaudio # pactl to control pipewire
    firefox
    carla
    barrier
    custom-obs
    armcord
    chatterino2
    guvcview # NOTE: do NOT use the obs v4l camera, it has all sorts of performance issues. capture this

    (pkgs.writeShellScriptBin "mus" ''
      mpv --ao=jack --jack-name=mpv-music --no-video --ytdl-format=bestaudio --loop-playlist "$@"
    '')
  ];

  users.users."${user}" = {
    isNormalUser = true;
    description = "${user}";
    extraGroups = [ "networkmanager" "wheel" "audio" ];
    openssh.authorizedKeys.keys = authorizedKeys;
  };

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [
      22 # ssh
      24800 # barriers
    ];
    allowedUDPPorts = [
      9999 # teleport discovery
    ];
  };

  # loopback device that I use to send music to my visualizer in the browser (appears as a mic)
  services.pipewire.extraConfig.pipewire = {

    "10-loopback"."context.modules" =
      let
        sinkName = x: (builtins.replaceStrings [ " " ] [ "-" ] (lib.toLower x)) + "_sink";
        loopbackD = x: delaySec: {
          name = "libpipewire-module-loopback";
          args = {
            "audio.position" = [ "FL" "FR" ];
            "target.delay.sec" = delaySec;
            "capture.props" = {
              "media.class" = "Audio/Sink";
              "node.name" = sinkName x;
              "node.description" = "${x} Sink (In)";
            };

            # the loopback device already has a built in output.
            # this is more useful if you need to hardwire it to a device with node.target

            "playback.props" = {
              "media.class" = "Audio/Source";
              "node.name" = (sinkName x) + "_out";
              "node.description" = "${x} Sink (Out)";
              "target.object" = "null-sink";
              "node.dont-reconnect" = true;
              "stream.dont-remix" = true;
              "node.passive" = true;
            };
          };
        };
        loopback = x: loopbackD x 0.0;
      in
      [
        (loopback "Music")
        (loopback "Music Delayed") # for the music visualizer to sync with facecam
        (loopback "Quiet Game Compressed")
        (loopback "Other Audio Vod")
        (loopback "Other Audio NoVod")
        (loopback "Compressed Other Audio Vod")
        (loopback "Compressed Other Audio NoVod")
      ];

    # this makes the jack monitors properly restore in carla
    "01-jack-monitor"."jack.properties"."jack.merge-monitor" = true;

    # null audio sink for when I want to default audio output to nothing
    "20-null"."context.objects" = [
      {
        factory = "adapter";
        args = {
          "factory.name" = "support.null-audio-sink";
          "node.name" = "null-sink";
          "node.description" = "sound black hole";
          "media.class" = "Audio/Sink";
          "object.linger" = 1;
          "audio.position" = [ "FL" "FR" ];
        };
      }
    ];
  };

  # barrier server

  environment.etc = {
    "barrier.conf".source = ../../common/barrier/barrier.conf;
    "secrets/barrier/SSL/Fingerprints/TrustedClients.txt".source = ../../common/barrier/TrustedClients.txt;
  };

  systemd.user.services.barriers = {
    enable = true;
    description = "Barrier Server daemon";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    # TODO: don't repeat barrier dir, make it a let
    serviceConfig.ExecStart =
      toString ([ "${pkgs.barrier}/bin/barriers" "-f" "--profile-dir" "/etc/secrets/barrier/" ]);
    };

  # startup apps

  systemd.user.services.startup-apps =
    let
      apps = [
        "chatterino2"
        "armcord"
        "firefox"
      ];
      binary = x: let
        meta = pkgs.${x}.meta;
      in
        with builtins;
        pkgs.${x} + "/bin/" + (if hasAttr "mainProgram" meta then meta.mainProgram else x);
      guvc = binary "guvcview";
    in
    {
      enable = true;
      description = "Various custom start-up apps";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        RemainAfterExit = "yes";
        Type = "oneshot";
      };

      script = ''
        ${guvc} --device=/dev/video0 --resolution=960x540 --fps=60 --profile=/home/${user}/cam.gpfl --render_window=full --audio=none &
        ${guvc} --device=/dev/video2 --resolution=640x480 --fps=60 --audio=none &

        LV2_PATH=${pkgs.bolliedelayxt-lv2}/lib/lv2/ ${binary "carla"} /home/${user}/stream-linux.carxp &
        ${custom-obs}/bin/obs &
      '' + (builtins.concatStringsSep "\n" (map (x: "${binary x} &") apps));
    };

  # secrets

  # by default, agenix does not look in your home dir for keys
  age.identityPaths = [
    "/root/.ssh/id_ed25519"
  ];

  # agenix secrets are owned by root and symlinked from /run/agenix.d .
  # so to have user-owned secrets I have to disable symlinking and make sure the ownership is correct
  # TODO: don't copypaste these helpers everywhere
  age.secrets =
    let

      secretPath = path: "/etc/secrets/${path}";

      mkSecret = { file, path }: {
        inherit file;
        path = secretPath path;
        symlink = false;
        owner = "${user}";
        group = "users";
      };

    in
    {

      barriers-private-key = mkSecret {
        file = ../../secrets/barrier/Barrier.pem.age;
        path = "barrier/SSL/Barrier.pem";
      };

      chatterino-settings = mkSecret {
        file = ../../secrets/chatterino/overlay.json.age;
        path = "/home/${user}/.local/share/chatterino/Settings/settings.json";
      };

    };

  system.stateVersion = "23.05";

}
