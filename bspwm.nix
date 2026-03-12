# =============================================================
#  gh0stzk BSPWM rice for NixOS
#
#  HOW TO INSTALL:
#  1. Copy this file to /etc/nixos/bspwm.nix
#  2. Add ONE line to your configuration.nix imports block:
#
#       imports = [
#         ./hardware-configuration.nix
#         ./bspwm.nix          # <-- add this
#       ];
#
#  3. sudo nixos-rebuild switch
#  4. Log out → select BSPWM in ly → log in
#     A terminal opens. Setup clones dotfiles in the background.
#     When done: Alt+Space to switch themes, Super+Enter for terminal.
#
#  After that:
#  - Edit ~/.config/bspwm/ freely — survives every nixos-rebuild
#  - To reset to upstream defaults: run  reset-dotfiles
# =============================================================

{ config, pkgs, lib, ... }:

let
  user = "nabil";

  # Full PATH for systemd user services (they get a bare env by default)
  servicePath = lib.concatStringsSep ":" [
    "${pkgs.git}/bin"
    "${pkgs.curl}/bin"
    "${pkgs.zstd}/bin"
    "${pkgs.gnutar}/bin"
    "${pkgs.coreutils}/bin"
    "${pkgs.findutils}/bin"
    "${pkgs.gnused}/bin"
    "${pkgs.bash}/bin"
    "${pkgs.nix}/bin"
    "${pkgs.systemd}/bin"
    "${pkgs.xdg-user-dirs}/bin"
    "${pkgs.fontconfig.bin}/bin"
    "/run/current-system/sw/bin"
  ];

  # ── setup-dotfiles ────────────────────────────────────────────────────────
  setupScript = pkgs.writeShellScriptBin "setup-dotfiles" ''
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="${servicePath}"

    DONE_FLAG="$HOME/.config/bspwm/.nixos-setup-done"
    [ -f "$DONE_FLAG" ] && exit 0

    REPO="https://github.com/gh0stzk/dotfiles"
    CLONE_DIR="$HOME/.local/share/gh0stzk"
    LOG="$HOME/.local/share/gh0stzk-setup.log"
    mkdir -p "$(dirname "$LOG")"
    exec > >(tee -a "$LOG") 2>&1
    echo "[$(date)] Starting gh0stzk BSPWM setup..."

    # 1. Clone
    if [ -d "$CLONE_DIR/.git" ]; then
      git -C "$CLONE_DIR" pull --ff-only || true
    else
      git clone --depth=1 "$REPO" "$CLONE_DIR"
    fi

    safe_copy() {
      local src="$1" dst="$2"
      if [ -e "$dst" ] || [ -L "$dst" ]; then
        echo "  skip: $dst"
      else
        mkdir -p "$(dirname "$dst")"
        cp -R "$src" "$dst"
        echo "  copied: $dst"
      fi
    }

    # 2. Config dirs
    for dir in alacritty bspwm clipcat geany gtk-3.0 kitty mpd ncmpcpp yazi zsh nvim; do
      safe_copy "$CLONE_DIR/config/$dir" "$HOME/.config/$dir"
    done

    # 3. Permissions
    find "$HOME/.config/bspwm/bin"   -type f -exec chmod +x {} \;
    find "$HOME/.config/bspwm/rices" -name "*.bash" -exec chmod +x {} \;
    find "$HOME/.config/bspwm/eww/profilecard/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
    find "$HOME/.config/bspwm/rices" -path "*/bar/scripts/*" -type f -exec chmod +x {} \; 2>/dev/null || true

    # 4. Shared resources
    for item in applications asciiart fonts; do
      safe_copy "$CLONE_DIR/misc/$item" "$HOME/.local/share/$item"
    done

    # 5. Local bin
    mkdir -p "$HOME/.local/bin"
    for f in "$CLONE_DIR/misc/bin/"*; do
      dst="$HOME/.local/bin/$(basename "$f")"
      if [ -e "$dst" ]; then echo "  skip: $dst"
      else cp "$f" "$dst"; chmod +x "$dst"; echo "  installed: $dst"; fi
    done

    # 6. Home files
    safe_copy "$CLONE_DIR/home/.gtkrc-2.0" "$HOME/.gtkrc-2.0"
    safe_copy "$CLONE_DIR/home/.zshrc"     "$HOME/.zshrc"
    safe_copy "$CLONE_DIR/home/.icons"     "$HOME/.icons"

    # 7. Patch .zshrc plugin paths for NixOS
    ZSHRC="$HOME/.zshrc"
    if grep -q '/usr/share/zsh/plugins/' "$ZSHRC" 2>/dev/null; then
      echo "Patching .zshrc..."
      _as=$(nix-build --no-out-link '<nixpkgs>' -A zsh-autosuggestions       2>/dev/null || true)
      _sh=$(nix-build --no-out-link '<nixpkgs>' -A zsh-syntax-highlighting    2>/dev/null || true)
      _hs=$(nix-build --no-out-link '<nixpkgs>' -A zsh-history-substring-search 2>/dev/null || true)
      _ft=$(nix-build --no-out-link '<nixpkgs>' -A zsh-fzf-tab               2>/dev/null || true)
      [ -n "$_ft" ] && sed -i "s|source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.zsh|source ''${_ft}/share/fzf-tab/fzf-tab.zsh|" "$ZSHRC"
      [ -n "$_as" ] && sed -i "s|source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh|source ''${_as}/share/zsh-autosuggestions/zsh-autosuggestions.zsh|" "$ZSHRC"
      [ -n "$_sh" ] && sed -i "s|source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh|source ''${_sh}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh|" "$ZSHRC"
      [ -n "$_hs" ] && sed -i "s|source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh|source ''${_hs}/share/zsh-history-substring-search/zsh-history-substring-search.zsh|" "$ZSHRC"
    fi
    sed -i 's|alias update=.*|alias update="sudo nixos-rebuild switch"|'   "$ZSHRC" 2>/dev/null || true
    sed -i 's|alias mirrors=.*|alias mirrors="sudo nix-channel --update"|' "$ZSHRC" 2>/dev/null || true
    sed -i 's|alias grub-update=.*|# grub-update: not needed on NixOS|'   "$ZSHRC" 2>/dev/null || true

    # 8. GTK themes / icons / cursor from gh0stzk pkg repo
    THEMES_DIR="$HOME/.local/share/themes"
    ICONS_DIR="$HOME/.local/share/icons"
    mkdir -p "$THEMES_DIR" "$ICONS_DIR"

    _get_pkg() {
      local name="$1" tdir="$2" idir="$3"
      local url="https://github.com/gh0stzk/pkgs/raw/main/x86_64/''${name}.pkg.tar.zst"
      local tmp; tmp=$(mktemp -d)
      echo "  Fetching ''${name}..."
      if curl -fsSL "$url" -o "$tmp/p.tar.zst" 2>/dev/null; then
        zstd -d --quiet "$tmp/p.tar.zst" -o "$tmp/p.tar" 2>/dev/null && \
          tar -xf "$tmp/p.tar" -C "$tmp" 2>/dev/null || \
          tar --use-compress-program=unzstd -xf "$tmp/p.tar.zst" -C "$tmp" 2>/dev/null || true
        if [ -d "$tmp/usr/share/themes" ] && [ -n "$tdir" ]; then
          for d in "$tmp/usr/share/themes/"*/; do
            n="$(basename "$d")"
            [ -d "$tdir/$n" ] && echo "  skip: $n" || { cp -R "$d" "$tdir/"; echo "  theme: $n"; }
          done
        fi
        if [ -d "$tmp/usr/share/icons" ] && [ -n "$idir" ]; then
          for d in "$tmp/usr/share/icons/"*/; do
            n="$(basename "$d")"
            [ -d "$idir/$n" ] && echo "  skip: $n" || { cp -R "$d" "$idir/"; echo "  icons: $n"; }
          done
        fi
      else
        echo "  WARN: could not fetch ''${name}"
      fi
      rm -rf "$tmp"
    }

    _get_pkg "gh0stzk-gtk-themes"              "$THEMES_DIR" ""
    _get_pkg "gh0stzk-cursor-qogirr"           ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-beautyline"        ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-candy"             ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-catppuccin-mocha"  ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-dracula"           ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-glassy"            ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-gruvbox-plus-dark" ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-hack"              ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-luv"               ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-sweet-rainbow"     ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-tokyo-night"       ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-vimix-white"       ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-zafiro"            ""            "$ICONS_DIR"
    _get_pkg "gh0stzk-icons-zafiro-purple"     ""            "$ICONS_DIR"

    # 9. Services + caches
    systemctl --user enable --now mpd.service 2>/dev/null || true
    xdg-user-dirs-update 2>/dev/null || true
    fc-cache -r 2>/dev/null || true

    touch "$DONE_FLAG"
    echo "[$(date)] Setup complete!"
    notify-send "BSPWM Setup" "Done! Super+Alt+r to reload bspwm." 2>/dev/null || true
  '';

  # ── reset-dotfiles ────────────────────────────────────────────────────────
  resetScript = pkgs.writeShellScriptBin "reset-dotfiles" ''
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="${servicePath}"

    echo "WARNING: This deletes all gh0stzk dotfiles and re-clones from upstream."
    echo "Your edits will be backed up but overwritten."
    echo ""
    read -rp "Type 'yes' to confirm: " CONFIRM
    [ "$CONFIRM" = "yes" ] || { echo "Aborted."; exit 0; }

    BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    for p in \
      "$HOME/.config/bspwm"   "$HOME/.config/alacritty" "$HOME/.config/kitty" \
      "$HOME/.config/zsh"     "$HOME/.config/nvim"      "$HOME/.config/geany" \
      "$HOME/.config/clipcat" "$HOME/.config/gtk-3.0"   "$HOME/.config/mpd" \
      "$HOME/.config/ncmpcpp" "$HOME/.config/yazi"      "$HOME/.zshrc" \
      "$HOME/.gtkrc-2.0"      "$HOME/.icons"; do
      [ -e "$p" ] && cp -R "$p" "$BACKUP/" && echo "backed up: $p"
    done

    rm -rf \
      "$HOME/.config/bspwm"   "$HOME/.config/alacritty" "$HOME/.config/kitty" \
      "$HOME/.config/zsh"     "$HOME/.config/nvim"      "$HOME/.config/geany" \
      "$HOME/.config/clipcat" "$HOME/.config/gtk-3.0"   "$HOME/.config/mpd" \
      "$HOME/.config/ncmpcpp" "$HOME/.config/yazi"      "$HOME/.zshrc" \
      "$HOME/.gtkrc-2.0"      "$HOME/.icons" \
      "$HOME/.local/bin/colorscript" "$HOME/.local/bin/sysfetch" \
      "$HOME/.local/share/gh0stzk"   "$HOME/.local/share/asciiart" 2>/dev/null || true

    setup-dotfiles
  '';

  # ── Updates (NixOS replacement for paru + checkupdates) ──────────────────
  updatesScript = pkgs.writeShellScriptBin "Updates" ''
    UPDATE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/Updates.txt"
    check_updates() {
      total=$(nix-store --gc --print-dead 2>/dev/null | wc -l || echo 0)
      echo "$total" > "$UPDATE_FILE"
      if pgrep -x polybar >/dev/null 2>&1; then
        polybar-msg action updates hook 0 >/dev/null 2>&1
      else
        _r=$(cat "$HOME/.config/bspwm/.rice" 2>/dev/null || echo "emilia")
        eww -c "$HOME/.config/bspwm/rices/''${_r}/bar" poll UPDATES 2>/dev/null || true
      fi
    }
    list_updates() {
      check_updates
      printf "\033[1m\033[33mNixOS:\033[0m sudo nixos-rebuild switch\n"
    }
    case "''${1:-}" in
      --sync-polybar)  check_updates ;;
      --print-updates) list_updates  ;;
      *) echo "Updates --sync-polybar | --print-updates"; exit 1 ;;
    esac
  '';

in
{
  # ── BSPWM session alongside GNOME ─────────────────────────────────────────
  services.xserver.windowManager.bspwm.enable = true;

  security.polkit.enable         = true;
  hardware.bluetooth.enable      = lib.mkDefault true;
  hardware.bluetooth.powerOnBoot = lib.mkDefault true;
  services.blueman.enable        = lib.mkDefault true;
  hardware.acpilight.enable      = true;
  services.gvfs.enable           = lib.mkDefault true;
  services.tumbler.enable        = lib.mkDefault true;
  programs.dconf.enable          = lib.mkDefault true;
  programs.zsh.enable            = true;
  users.users.${user}.shell      = pkgs.zsh;

  programs.thunar = {
    enable  = true;
    plugins = with pkgs.xfce; [ thunar-archive-plugin thunar-volman ];
  };

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      ubuntu-classic
      font-awesome
      material-design-icons
    ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      serif     = [ "Noto Serif" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };

  # ── Fallback bspwmrc — written only if none exists yet ────────────────────
  # Prevents black screen on first login before dotfiles are cloned.
  # Opens alacritty and auto-runs setup-dotfiles immediately.
  system.activationScripts.bspwm-fallback-config = {
    text = ''
      BSPWMRC="/home/${user}/.config/bspwm/bspwmrc"
      if [ ! -f "$BSPWMRC" ]; then
        mkdir -p "/home/${user}/.config/bspwm"
        cat > "$BSPWMRC" << 'EOF'
#!/bin/sh
bspc monitor -d 1 2 3 4 5
bspc config border_width        2
bspc config window_gap          12
bspc config split_ratio         0.52
bspc config focus_follows_pointer true
alacritty &
setup-dotfiles &
EOF
        chmod +x "$BSPWMRC"
        chown ${user}:users "$BSPWMRC" 2>/dev/null || true
      fi
    '';
    deps = [];
  };

  # ── Auto-run setup on first login ─────────────────────────────────────────
  systemd.user.services.bspwm-dotfiles-setup = {
    description = "gh0stzk BSPWM dotfiles first-login setup";
    wantedBy    = [ "default.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart       = "${setupScript}/bin/setup-dotfiles";
      TimeoutStartSec = "600";
      Environment     = [ "PATH=${servicePath}" ];
    };
  };

  # ── Packages ──────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    bspwm sxhkd picom polybar eww dunst jgmenu rofi xsettingsd lxsession
    kitty
    zsh zsh-autosuggestions zsh-syntax-highlighting
    zsh-history-substring-search zsh-fzf-tab
    fzf bat eza fd ripgrep xclip xdo xdotool
    imagemagick jq bc xxHash ffmpeg
    xorg.xrandr xorg.xsetroot xorg.xprop xorg.xkill
    xorg.xdpyinfo xorg.xrdb xorg.xwininfo
    mpd mpc ncmpcpp mpv playerctl pamixer pavucontrol
    feh brightnessctl redshift maim xcolor xwinwrap
    i3lock-color clipcat
    geany yazi neovim nodejs python3 python3Packages.pygobject3
    papirus-icon-theme libwebp webp-pixbuf-loader
    xdg-utils xdg-user-dirs networkmanagerapplet simple-mtpfs
    setupScript    # setup-dotfiles  — auto-runs on first BSPWM login
    resetScript    # reset-dotfiles  — run manually to wipe + re-clone
    updatesScript  # Updates         — NixOS-safe polybar updates script
  ];
}
