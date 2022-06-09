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
  menuProg = "dmenu";
in with config; {
  home.username = "${user}";
  home.homeDirectory = "/home/${user}";
  home.stateVersion = "22.05";
  home.packages = (with pkgs; [
    curl
    wget
    htop
    bpytop
    tokei
    pass
    xclip # required for pass show -c, also useful in general
    git
    fusee-launcher
    mpv
    dmenu
    v4l-utils
    gh2md
    autorandr # save and detect xrandr configurations automatically

    pxplus-ibm-vga8-bin
    unifont
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    noto-fonts-extra
    emacs-all-the-icons-fonts

    pinentry-gnome
    gcr # required for pinentry-gnome?
    polkit_gnome
    gnome3.nautilus

    alacritty
    librewolf
    tdesktop
    chatterino7
    emacs-custom
    obs-studio
    simplescreenrecorder
    screenkey
    pavucontrol

    # TODO: would be nice to find a way to have these isolated in the custom
    # emacs instead of home-wide
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

      ;; polkit agent
      (setq loli/polkit-agent-command "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
    '';

    "git/config".source = ./git/gitconfig;
  };

  services.emacs.package = emacs-custom;

  services.barrier.client = {
    enable = true;
    server = "192.168.1.202";
    enableDragDrop = true;
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
  xsession = {
    enable = true;
    windowManager.command = ''
      exec ${emacs-custom}/bin/emacs --debug-init -mm
    '';
  };
  xsession.scriptPath = ".hm-xsession";
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

  programs.gpg = {
    enable = true;
    homedir = "${xdg.dataHome}/gnupg";
    settings.use-agent = true;
  };

  home.file."${programs.gpg.homedir}/.keep".text = "";

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
    pinentryFlavor = "gnome3";
  };

  services.gnome-keyring.enable = true;

  # NOTE: private config files. comment out or provide your own
  xdg.configFile."gh2md/token".source = ./private-flake/gh2md/token;
}
