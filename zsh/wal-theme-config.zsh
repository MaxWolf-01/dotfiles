#!/usr/bin/env zsh
# WAL Theme Configuration
# This file handles all pywal theme setup and LS_COLORS customization

# Available themes (uncomment one)

# Generate a theme from an image
# WAL_THEME_IMAGE="$HOME/Pictures/cli-themes/andromeda"
# WAL_THEME_IMAGE="$HOME/Pictures/cli-themes/kanagawa"
# WAL_THEME_IMAGE="$HOME/Pictures/cli-themes/vaporwave-kanagawa"
# WAL_THEME_IMAGE="$HOME/Pictures/cli-themes/black-hole"
# Or use a custom JSON theme
WAL_THEME_FILE="$HOME/.dotfiles/zsh/wal-themes/ghibli-dark.json"
# WAL_THEME_FILE="$HOME/.dotfiles/zsh/wal-themes/ghibli-dark-original.json"
# Or use a built-in theme instead
# WAL_THEME_NAME="base16-atelier-cave"

# Function to convert hex to RGB for LS_COLORS
_wal_hex_to_rgb() {
    local hex="${1#\#}"
    printf "%d;%d;%d" 0x${hex:0:2} 0x${hex:2:2} 0x${hex:4:2}
}

# Function to adjust RGB brightness
_wal_adjust_brightness() {
    local hex="${1#\#}"
    local factor="$2"  # e.g., 1.2 for 20% brighter, 0.8 for 20% darker
    
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    
    # Adjust and clamp to 0-255
    r=$(awk "BEGIN {printf \"%.0f\", $r * $factor}")
    g=$(awk "BEGIN {printf \"%.0f\", $g * $factor}")
    b=$(awk "BEGIN {printf \"%.0f\", $b * $factor}")
    
    [[ $r -gt 255 ]] && r=255
    [[ $g -gt 255 ]] && g=255
    [[ $b -gt 255 ]] && b=255
    
    printf "%d;%d;%d" "$r" "$g" "$b"
}

# Apply the theme
_apply_wal_theme() {
    if [[ -n "$WAL_THEME_NAME" ]]; then
        wal --theme "$WAL_THEME_NAME" &> /dev/null
    elif [[ -n "$WAL_THEME_FILE" ]]; then
        wal -f "$WAL_THEME_FILE" &> /dev/null
    elif [[ -n "$WAL_THEME_IMAGE" ]]; then
        wal -i "$WAL_THEME_IMAGE" &> /dev/null
    fi
}

# Configure LS_COLORS with wal colors
_configure_wal_ls_colors() {
    if [[ ! -f ~/.cache/wal/colors.sh ]]; then
        return
    fi
    
    source ~/.cache/wal/colors.sh
    
    # Build comprehensive LS_COLORS with wal theme
    # Base colors
    local dir_color="38;2;$(_wal_hex_to_rgb $color4)"          # directories
    local exec_color="38;2;$(_wal_hex_to_rgb $color2)"         # executables
    local link_color="38;2;$(_wal_hex_to_rgb $color6)"         # symlinks
    local archive_color="38;2;$(_wal_hex_to_rgb $color5)"      # archives
    local media_color="38;2;$(_wal_hex_to_rgb $color13)"       # media files
    local doc_color="38;2;$(_wal_hex_to_rgb $color7)"          # documents
    local code_color="38;2;$(_wal_hex_to_rgb $color12)"        # source code
    local config_color="38;2;$(_wal_hex_to_rgb $color3)"       # config files
    local data_color="38;2;$(_wal_hex_to_rgb $color11)"        # data files
    
    # Distinct colors for common dev files with variations
    # Python ecosystem (often appear together)
    local python_color="38;2;$(_wal_adjust_brightness $color4 1.4)"  # Brighter blue like audio
    local toml_color="38;2;$(_wal_hex_to_rgb $color1)"
    local yaml_color="38;2;$(_wal_hex_to_rgb $color3)"
    local json_color="38;2;$(_wal_hex_to_rgb $color6)"
    local shell_color="38;2;$(_wal_hex_to_rgb $color5)"
    local sql_color="38;2;$(_wal_hex_to_rgb $color13)"
    local makefile_color="38;2;$(_wal_hex_to_rgb $color9);1"   # Bold
    
    # Web development (TS/JS ecosystem)
    local typescript_color="38;2;$(_wal_hex_to_rgb $color4)"
    local tsx_color="38;2;$(_wal_adjust_brightness $color4 1.3)"  # 30% brighter
    local javascript_color="38;2;$(_wal_hex_to_rgb $color11)"
    local jsx_color="38;2;$(_wal_adjust_brightness $color11 1.3)"  # 30% brighter
    local css_color="38;2;$(_wal_hex_to_rgb $color14)"
    
    # Documentation & config
    local markdown_color="38;2;$(_wal_hex_to_rgb $color7);1"   # Bold
    local pdf_color="38;2;$(_wal_hex_to_rgb $color1)"           # Red-ish
    local txt_color="38;2;$(_wal_hex_to_rgb $color15)"          # Bright
    local docx_color="38;2;$(_wal_hex_to_rgb $color4)"          # Blue-ish
    local env_color="38;2;$(_wal_hex_to_rgb $color10);3"        # Italic
    local xml_color="38;2;$(_wal_hex_to_rgb $color8)"           # Dimmed
    
    # C/C++ ecosystem
    local cpp_color="38;2;$(_wal_hex_to_rgb $color5)"
    local header_color="38;2;$(_wal_adjust_brightness $color5 1.3)"  # 30% brighter
    
    # Media variations with MORE distinct brightness adjustments
    local image_png="38;2;$(_wal_hex_to_rgb $color11)"              # PNG base
    local image_jpg="38;2;$(_wal_adjust_brightness $color11 0.7)"   # JPG 30% darker
    local image_webp="38;2;$(_wal_adjust_brightness $color11 1.3)"  # WebP 30% brighter
    local image_gif="38;2;$(_wal_hex_to_rgb $color11);3"            # GIF italic
    local video_mp4="38;2;$(_wal_hex_to_rgb $color9)"               # MP4 base
    local video_mkv="38;2;$(_wal_adjust_brightness $color9 0.6)"    # MKV 40% darker
    local video_avi="38;2;$(_wal_adjust_brightness $color9 1.3)"    # AVI 30% brighter
    local audio_mp3="38;2;$(_wal_hex_to_rgb $color14)"              # MP3 base
    local audio_flac="38;2;$(_wal_adjust_brightness $color14 1.4)"  # FLAC 40% brighter
    local audio_wav="38;2;$(_wal_hex_to_rgb $color14);1"            # WAV bold
    
    # Special files
    local lock_color="38;2;$(_wal_hex_to_rgb $color8);2"       # Dimmed
    local encrypted_color="38;2;$(_wal_hex_to_rgb $color1);4"  # Underlined
    
    # Build LS_COLORS from scratch with only common development files
    # Basic file types (required)
    # File attributes (ex=executable, di=directory, ln=link)
    # We don't set ex here to let file extensions take precedence
    export LS_COLORS="rs=0:di=${dir_color}:ln=${link_color}:or=48;5;196;38;5;232;1:mi=38;5;196"
    
    # Development files
    # Python/Data Science
    export LS_COLORS="${LS_COLORS}:*.py=${python_color}:*.ipynb=${python_color}:*.pyx=${python_color}:*.pyi=${python_color}"
    
    # Web Development
    export LS_COLORS="${LS_COLORS}:*.js=${javascript_color}:*.mjs=${javascript_color}:*.cjs=${javascript_color}:*.ts=${typescript_color}:*.tsx=${tsx_color}:*.jsx=${jsx_color}:*.vue=${typescript_color}:*.css=${css_color}:*.scss=${css_color}:*.sass=${css_color}:*.less=${css_color}:*.html=${doc_color}:*.htm=${doc_color}"
    
    # Systems Programming
    export LS_COLORS="${LS_COLORS}:*.rs=${code_color}:*.go=${code_color}:*.c=${cpp_color}:*.cpp=${cpp_color}:*.cc=${cpp_color}:*.h=${header_color}:*.hpp=${header_color}:*.cmake=${config_color}:*Makefile=${makefile_color}:*.mk=${makefile_color}"
    
    # JVM Languages
    export LS_COLORS="${LS_COLORS}:*.java=${code_color}:*.kt=${code_color}:*.scala=${code_color}:*.gradle=${config_color}"
    
    # Shell Scripts (use distinct shell color)
    export LS_COLORS="${LS_COLORS}:*.sh=${shell_color}:*.bash=${shell_color}:*.zsh=${shell_color}:*.fish=${shell_color}"
    
    # Config/Data files
    export LS_COLORS="${LS_COLORS}:*.json=${json_color}:*.yaml=${yaml_color}:*.yml=${yaml_color}:*.toml=${toml_color}:*.ini=${config_color}:*.conf=${config_color}:*.config=${config_color}:*.env=${env_color}:*.cfg=${config_color}:*.sql=${sql_color}:*.csv=${data_color}:*.db=${data_color}:*.sqlite=${data_color}"
    
    # Docker/K8s
    export LS_COLORS="${LS_COLORS}:*Dockerfile=${config_color}:*docker-compose.yml=${config_color}:*.dockerignore=${special_color}"
    
    # Documentation
    export LS_COLORS="${LS_COLORS}:*.md=${markdown_color}:*.rst=${doc_color}:*.txt=${txt_color}:*README=${markdown_color}:*LICENSE=${doc_color}:*.pdf=${pdf_color}:*.docx=${docx_color}:*.doc=${docx_color}:*.odt=${docx_color}:*.excalidraw=${doc_color}:*.canvas=${doc_color}"
    
    # Archives (only common ones)
    export LS_COLORS="${LS_COLORS}:*.zip=${archive_color}:*.tar=${archive_color}:*.gz=${archive_color}:*.bz2=${archive_color}:*.7z=${archive_color}:*.rar=${archive_color}"
    
    # Media files with brightness variations
    # Images
    export LS_COLORS="${LS_COLORS}:*.jpg=${image_jpg}:*.jpeg=${image_jpg}:*.png=${image_png}:*.gif=${image_gif}:*.svg=${image_png}:*.webp=${image_webp}:*.bmp=${image_png}:*.ico=${image_png}"
    # Videos  
    export LS_COLORS="${LS_COLORS}:*.mp4=${video_mp4}:*.mkv=${video_mkv}:*.avi=${video_avi}:*.mov=${video_mp4}:*.wmv=${video_mp4}:*.flv=${video_mp4}:*.webm=${video_mp4}"
    # Audio
    export LS_COLORS="${LS_COLORS}:*.mp3=${audio_mp3}:*.wav=${audio_wav}:*.flac=${audio_flac}:*.aac=${audio_mp3}:*.ogg=${audio_mp3}:*.m4a=${audio_mp3}"
    
    # Git files
    export LS_COLORS="${LS_COLORS}:*.gitignore=${special_color}:*.gitmodules=${special_color}:*.gitattributes=${special_color}"
    
    # XML/IDE configs
    export LS_COLORS="${LS_COLORS}:*.xml=${xml_color}:*.iml=${xml_color}"
    
    # Security/Encrypted files
    export LS_COLORS="${LS_COLORS}:*.enc=${encrypted_color}:*.gpg=${encrypted_color}:*.pem=${encrypted_color}:*.key=${encrypted_color}"
    
    # Build artifacts/temp files (muted)
    local log_color="38;2;$(_wal_hex_to_rgb $color15);2"
    local special_color="38;2;$(_wal_hex_to_rgb $color7);2"
    export LS_COLORS="${LS_COLORS}:*.log=${log_color}:*.bak=${special_color}:*.tmp=${special_color}:*.swp=${special_color}:*.swo=${special_color}:*.lock=${lock_color}:*.cache=${special_color}:*.pyc=${lock_color}:*.pyo=${lock_color}:*.so=${special_color}:*.map=${special_color}"
    
    # Other-writable directory (keep the fix)
    export LS_COLORS="${LS_COLORS}:ow=1;${dir_color}"
}

# Configure git colors for better diff visibility
_configure_git_colors() {
    if [[ ! -f ~/.cache/wal/colors.sh ]]; then
        return
    fi
    
    # # Use high-contrast colors for git diff
    # # These work well regardless of the wal theme
    # git config --global color.diff.old "red bold"
    # git config --global color.diff.new "green bold"
    # git config --global color.diff.meta "yellow bold"
    # git config --global color.diff.frag "magenta bold"
    # git config --global color.diff.commit "cyan bold"
    # git config --global color.diff.whitespace "red reverse"
    #
    # # Better colors for git status
    # git config --global color.status.added "green bold"
    # git config --global color.status.changed "yellow bold"
    # git config --global color.status.untracked "cyan"
    # git config --global color.status.deleted "red bold"

}

# Initialize wal theme (non-blocking - runs in background)
(_apply_wal_theme && _configure_wal_ls_colors && _configure_git_colors &)

