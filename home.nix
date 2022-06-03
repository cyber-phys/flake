{ config, pkgs, user, ... }:

let
  pythonPackages = pkgs.python39Packages; # adjust python version here as needed
  emacs-custom = (
    let
      emacsBuild = (pkgs.emacs.override {
        withGTK3 = true;
        withGTK2 = false;
      });
      emacsCustom = (pkgs.emacsPackagesFor emacsBuild).emacsWithPackages;
    in
      emacsCustom (epkgs: with epkgs; [
        org org-superstar
        undo-tree
        sudo-edit
        nix-mode
        go-mode
        magit
        smex # ido-like completion for M-x
        which-key # display all possible command completions
        ido-vertical-mode # makes ido fuzzy search display results vertically
        nlinum-relative # relative line number
        company lsp-mode lsp-jedi ccls # auto complete
        evil # vim-like keybindings
        evil-collection # pre-configured evil keybinds for things not covered by core evil
        general # makes it easier to customize keybindings
        hydra # creates a prompt with timeout with its own keybinds
        tree-sitter tree-sitter-langs # way faster syntax gl than emacs' built in
        direnv # integrate nix-direnv into emacs
      ])
  );
  menuProg = "dmenu";
in with config; {
  home.username = "${user}";
  home.homeDirectory = "/home/${user}";
  home.stateVersion = "22.05";
  home.packages = with pkgs; with pythonPackages; [
    curl
    wget
    htop
    bpytop
    tokei
    pass
    git
    fusee-launcher
    mpv
    dmenu
    v4l-utils
    gh2md

    pxplus-ibm-vga8-bin
    unifont

    pinentry-gnome
    gnome3.gnome-tweaks
    gnome3.gnome-settings-daemon
    gnomeExtensions.appindicator
    gnomeExtensions.color-picker

    barrier
    alacritty
    librewolf
    tdesktop
    chatterino7
    emacs-custom
    obs-studio
    simplescreenrecorder
    screenkey

    # TODO: would be nice to find a way to have these isolated in the custom
    # emacs instead of home-wide
    jedi-language-server
    gopls
    ccls
    rnix-lsp
  ];
  home.sessionVariables = {
    EDITOR="vim";
  };
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.bash = {
    enable = true;
    shellAliases = {
      xb="pushd ~/flake && sudo nixos-rebuild switch --flake .?submodules=1#; popd";
      xu="pushd ~/flake && nix flake update; popd";
      xub="xu && xb";
      xq="nix search nixpkgs";
      cam="mpv --profile=low-latency --untimed $(ls /dev/video* | ${menuProg})";
      eq="nix-env -f '<nixpkgs>' -qaP -A pkgs.emacsPackages | grep";
    };
    bashrcExtra = ''
      set -o vi
    '';
  };
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

  services.emacs.package = emacs-custom;
  services.emacs.enable = true;

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
  xsession.initExtra = ''
    barrier &
    chatterino7 &
    tdesktop &
    librewolf &
  '';
  xresources.properties = {
    "*xterm*faceName" = "PxPlus IBM VGA8";
    "*xterm*faceNameDoublesize" = "Unifont";
    "*xterm*faceSize" = 12;
    "*xterm*allowBoldFonts" =  false;
    "*xterm*background" = "black";
    "*xterm*foreground" = "grey";
    "*xterm*reverseVideo" = false;
    "*xterm*termName" = "xterm-256color";
    "*xterm*VT100.Translations" = ''#override \
      Shift <Key>Insert: insert-selection(CLIPBOARD) \n\
      Ctrl Shift <Key>V: insert-selection(CLIPBOARD) \n\
      Ctrl Shift <Key>C: copy-selection(CLIPBOARD)
    '';
  };

  # NOTE: private config files. comment out or provide your own
  xdg.configFile."gh2md/token".source = ./private-flake/gh2md/token;
}
