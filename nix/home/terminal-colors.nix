# The terminal's colours: one palette, which ghostty draws as its 16 slots and
# LS_COLORS shades per file type. Everything else that colours text (the zsh
# prompt, Claude Code's dark-ansi theme, the status line) names a slot and
# follows whatever this palette puts there.
{ lib, ... }:
let
  palette = {
    background = "#1f1914";
    foreground = "#ede2c3";
    cursor = "#b89d65";
    colors = [
      "#1f1914" # 0
      "#8c5a3c" # 1
      "#6b8e50" # 2
      "#d4b77a" # 3
      "#4a90a0" # 4
      "#a08a55" # 5
      "#7ca3a8" # 6
      "#e8dfc8" # 7
      "#4a3f32" # 8
      "#a67c52" # 9
      "#7fa05a" # 10
      "#e6d4a3" # 11
      "#5ba5b7" # 12
      "#c89a6f" # 13
      "#8fbcc2" # 14
      "#f8f5e6" # 15
    ];
  };
  color = builtins.elemAt palette.colors;

  # "#4a90a0" -> [ 74 144 160 ]
  channels = hex: map (i: lib.fromHexString (builtins.substring i 2 hex)) [ 1 3 5 ];

  # Round half to even, as printf does, then clamp to a channel's range.
  round = x:
    let
      f = builtins.floor x;
      d = x - f;
    in
    lib.min 255 (if d > 0.5 || (d == 0.5 && lib.mod f 2 == 1) then f + 1 else f);

  rgb = cs: "38;2;${lib.concatMapStringsSep ";" toString cs}";
  fg = n: rgb (channels (color n));
  # The same slot scaled in brightness: 1.3 is 30% brighter, 0.7 30% darker.
  shade = n: factor: rgb (map (c: round (c * factor)) (channels (color n)));

  dir = fg 4;
  special = "${fg 7};2"; # dim

  # Later entries win, so the order is part of the scheme.
  lsColors = [
    [ "rs" "0" ]
    [ "di" dir ]
    [ "ln" (fg 6) ]
    [ "or" "48;5;196;38;5;232;1" ]
    [ "mi" "38;5;196" ]
    # Python / data science
    [ [ "*.py" "*.ipynb" "*.pyx" "*.pyi" ] (shade 4 1.4) ]
    # Web
    [ [ "*.js" "*.mjs" "*.cjs" ] (fg 11) ]
    [ "*.ts" (fg 4) ]
    [ "*.tsx" (shade 4 1.3) ]
    [ "*.jsx" (shade 11 1.3) ]
    [ "*.vue" (fg 4) ]
    [ [ "*.css" "*.scss" "*.sass" "*.less" ] (fg 14) ]
    [ [ "*.html" "*.htm" ] (fg 7) ]
    # Systems
    [ [ "*.rs" "*.go" ] (fg 12) ]
    [ [ "*.c" "*.cpp" "*.cc" ] (fg 5) ]
    [ [ "*.h" "*.hpp" ] (shade 5 1.3) ]
    [ "*.cmake" (fg 3) ]
    [ [ "*Makefile" "*.mk" ] "${fg 9};1" ]
    # JVM
    [ [ "*.java" "*.kt" "*.scala" ] (fg 12) ]
    [ "*.gradle" (fg 3) ]
    # Shell
    [ [ "*.sh" "*.bash" "*.zsh" "*.fish" ] (fg 5) ]
    # Config and data
    [ "*.json" (fg 6) ]
    [ [ "*.yaml" "*.yml" ] (fg 3) ]
    [ "*.toml" (fg 1) ]
    [ [ "*.ini" "*.conf" "*.config" ] (fg 3) ]
    [ "*.env" "${fg 10};3" ]
    [ "*.cfg" (fg 3) ]
    [ "*.sql" (fg 13) ]
    [ [ "*.csv" "*.db" "*.sqlite" ] (fg 11) ]
    # Docker
    [ [ "*Dockerfile" "*docker-compose.yml" ] (fg 3) ]
    [ "*.dockerignore" special ]
    # Documents
    [ "*.md" "${fg 7};1" ]
    [ "*.rst" (fg 7) ]
    [ "*.txt" (fg 15) ]
    [ "*README" "${fg 7};1" ]
    [ "*LICENSE" (fg 7) ]
    [ "*.pdf" (fg 1) ]
    [ [ "*.docx" "*.doc" "*.odt" ] (fg 4) ]
    [ [ "*.excalidraw" "*.canvas" ] (fg 7) ]
    # Archives
    [ [ "*.zip" "*.tar" "*.gz" "*.bz2" "*.7z" "*.rar" ] (fg 5) ]
    # Images, videos, audio: one hue each, told apart by brightness
    [ [ "*.jpg" "*.jpeg" ] (shade 11 0.7) ]
    [ "*.png" (fg 11) ]
    [ "*.gif" "${fg 11};3" ]
    [ "*.svg" (fg 11) ]
    [ "*.webp" (shade 11 1.3) ]
    [ [ "*.bmp" "*.ico" ] (fg 11) ]
    [ "*.mp4" (fg 9) ]
    [ "*.mkv" (shade 9 0.6) ]
    [ "*.avi" (shade 9 1.3) ]
    [ [ "*.mov" "*.wmv" "*.flv" "*.webm" ] (fg 9) ]
    [ "*.mp3" (fg 14) ]
    [ "*.wav" "${fg 14};1" ]
    [ "*.flac" (shade 14 1.4) ]
    [ [ "*.aac" "*.ogg" "*.m4a" ] (fg 14) ]
    # Git
    [ [ "*.gitignore" "*.gitmodules" "*.gitattributes" ] special ]
    # XML and IDE config
    [ [ "*.xml" "*.iml" ] (fg 8) ]
    # Secrets
    [ [ "*.enc" "*.gpg" "*.pem" "*.key" ] "${fg 1};4" ]
    # Build artefacts and temp files, muted
    [ "*.log" "${fg 15};2" ]
    [ [ "*.bak" "*.tmp" "*.swp" "*.swo" ] special ]
    [ "*.lock" "${fg 8};2" ]
    [ "*.cache" special ]
    [ [ "*.pyc" "*.pyo" ] "${fg 8};2" ]
    [ [ "*.so" "*.map" ] special ]
    # Other-writable directory
    [ "ow" "1;${dir}" ]
  ];
  lsColorsString = lib.concatMapStringsSep ":" (
    entry:
    let
      keys = lib.toList (builtins.elemAt entry 0);
      style = builtins.elemAt entry 1;
    in
    lib.concatMapStringsSep ":" (k: "${k}=${style}") keys
  ) lsColors;
in
{
  programs.ghostty.themes.ghibli-dark = {
    inherit (palette) background foreground;
    cursor-color = palette.cursor;
    palette = lib.imap0 (i: hex: "${toString i}=${hex}") palette.colors;
  };
  programs.ghostty.settings.theme = "ghibli-dark";

  # After zshrc, so no plugin it sources overwrites it.
  programs.zsh.initContent = lib.mkAfter ''
    export LS_COLORS="${lsColorsString}"
  '';
}
