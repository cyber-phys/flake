{ config, pkgs, user, configName, ... }:

let
  pythonPackages = pkgs.python39Packages; # adjust python version here as needed

  emacs-custom = (
    let
      emacsCustom = (pkgs.emacsPackagesFor pkgs.emacsPgtkNativeComp).emacsWithPackages;
    in
      emacsCustom (epkgs: with epkgs; [
        org org-superstar
        undo-tree
        sudo-edit
        nix-mode
        go-mode
        magit
        dired-single # single buffer for dired
        all-the-icons-dired
        dired-hide-dotfiles
        vertico # fancy fuzzy completion everywhere
        embark # quick actions on current completion selection
        ace-window # window management utils, also integrates with embark
        marginalia # extra info in vertico
        which-key # display all possible command completions
        nlinum-relative # relative line number
        company lsp-mode lsp-jedi ccls # auto complete
        evil # vim-like keybindings
        evil-collection # pre-configured evil keybinds for things not covered by core evil
        general # makes it easier to customize keybindings
        hydra # creates a prompt with timeout with its own keybinds
        tree-sitter tree-sitter-langs # way faster syntax gl than emacs' built in
        direnv # integrate nix-direnv into emacs
        exwm # emacs as a window manager
        consult # fancy buffer switching
        avy # fancy jump to char
      ])
  );

in with config; {

  caches.cachix = [
    { name = "nix-community"; sha256 = "1955r436fs102ny80wfzy99d4253bh2i1vv1x4d4sh0zx2ssmhrk"; }
  ];

  home.username = "${user}";
  home.homeDirectory = "/home/${user}";
  home.stateVersion = "22.05";

  # thanks to nix's import system, the machine-specific config is merged with this base config.
  # so, for example I can define home.packages again in a machine-specific config and it will concatenate
  # it to this list automatically in the import process

  home.packages = (with pkgs; [

    curl
    wget
    htop
    bpytop
    tokei
    git
    ffmpeg
    yt-dlp
    aria

    xclip # required for pass show -c, also useful in general
    mpv
    libnotify # notify-send

    man-pages
    man-pages-posix

    pxplus-ibm-vga8-bin
    unifont
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    noto-fonts-extra

    emacs-custom
    emacs-all-the-icons-fonts
    gopls
    ccls
    rnix-lsp

  ]) ++ (with pythonPackages; [

    jedi-language-server

  ]);

  home.sessionVariables = {
    EDITOR="vim";
  };

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  programs.bash = {
    enable = true;
    shellAliases = {
      xb="pushd ~/flake && nixos-rebuild switch --use-remote-sudo --flake .#${configName}; popd";
      xt="pushd ~/flake && nixos-rebuild test --use-remote-sudo --flake .#${configName}; popd";
      xu="pushd ~/flake && nix flake update; popd";
      xub="xu && xb";
      xq="nix search nixpkgs";
      eq="nix-env -f '<nixpkgs>' -qaP -A pkgs.emacsPackages | grep";
    };
    bashrcExtra = ''
      set -o vi
    '';
  };

  programs.alacritty.enable = true;

  xdg.dataFile = {
    "vim/swap/.keep".text = "";
    "vim/backup/.keep".text = "";
    "vim/undo/.keep".text = "";
    "emacs/backup/.keep".text = "";
    "emacs/undo/.keep".text = "";
  };

  xdg.configFile = {
    "emacs/init.el".source = ./emacs/init.el;
    "emacs/xterm-theme.el".source = ./emacs/xterm-theme.el;

    # extra elisp that needs to include strings generated by nix
    "emacs/generated.el".text = ''
      ;; don't clutter my fs with backup/undo files
      (setq backup-directory-alist
        `((".*" . "${xdg.dataHome}/emacs/backup//")))
      (setq auto-save-file-name-transforms
        `((".*" "${xdg.dataHome}/emacs/backup//" t)))
      (setq undo-tree-history-directory-alist '(("." . "${xdg.dataHome}/emacs/undo")))
    '';

    "git/config".source = ./git/gitconfig;
  };

  services.dunst.enable = true;

  services.dunst.settings = {

    global = {
      font = "Noto Sans Bold";
      background = "#000";
      foreground = "#bebebe";
      corner_radius = 20;
      frame_color = "#bebebe";
      frame_width = 2;
      padding = 16;
      horizontal_padding = 16;
    };

    urgency_low.timeout = 5;
    urgency_normal.timeout = 10;
    urgency_critical.timeout = 0;

    urgency_critical = {
      foreground = "#fff";
      background = "#900000";
      frame_color = "#ff0000";
    };

    fullscreen_show_critical = {
      msg_urgency = "critical";
      fullscreen = "show";
    };

  };

  programs.vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [ vim-nix ];
    settings = {
      directory = [ "${xdg.dataHome}/vim/swap//" ];
      backupdir = [ "${xdg.dataHome}/vim/backup//" ];
      undofile = true;
      undodir = [ "${xdg.dataHome}/vim/undo//" ];
      shiftwidth = 2;
      tabstop = 2;
      relativenumber = true;
    };
    extraConfig = builtins.readFile ./vim/init.vim;
  };

  gtk.enable = true;
  gtk.theme.name = "Adwaita-dark";
  gtk.theme.package = pkgs.gnome.gnome-themes-extra;

  xdg.configFile."yt-dlp/config".source = ./yt-dlp/config;

}
