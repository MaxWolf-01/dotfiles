#!/usr/bin/env zsh
# WAL Theme Configuration
# This file handles all pywal theme setup and LS_COLORS customization

# Available themes (uncomment one)

# Generate a theme from an image
# WAL_THEME_IMAGE="/home/max/Pictures/cli-themes/andromeda"
# WAL_THEME_IMAGE="/home/max/Pictures/cli-themes/kanagawa"
# WAL_THEME_IMAGE="/home/max/Pictures/cli-themes/vaporwave-kanagawa"
# WAL_THEME_IMAGE="/home/max/Pictures/cli-themes/black-hole"
# Or use a custom JSON theme
WAL_THEME_FILE="/home/max/.dotfiles/zsh/wal-themes/ghibli-dark.json"
# WAL_THEME_FILE="/home/max/.dotfiles/zsh/wal-themes/ghibli-dark-original.json"
# Or use a built-in theme instead
# WAL_THEME_NAME="base16-atelier-cave"

# Function to convert hex to RGB for LS_COLORS
_wal_hex_to_rgb() {
    local hex="${1#\#}"
    printf "%d;%d;%d" 0x${hex:0:2} 0x${hex:2:2} 0x${hex:4:2}
}

# Apply the theme
_apply_wal_theme() {
    if [[ -n "$WAL_THEME_NAME" ]]; then
        uvx --from pywal wal --theme "$WAL_THEME_NAME" &> /dev/null
    elif [[ -n "$WAL_THEME_FILE" ]]; then
        uvx --from pywal wal -f "$WAL_THEME_FILE" &> /dev/null
    elif [[ -n "$WAL_THEME_IMAGE" ]]; then
        uvx --from pywal wal -i "$WAL_THEME_IMAGE" &> /dev/null
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
    
    # Build LS_COLORS from scratch with only common development files
    # Basic file types (required)
    export LS_COLORS="rs=0:di=${dir_color}:ex=${exec_color}:ln=${link_color}:or=48;5;196;38;5;232;1:mi=38;5;196"
    
    # Development files
    # Python/Data Science
    export LS_COLORS="${LS_COLORS}:*.py=${code_color}:*.ipynb=${code_color}:*.pyx=${code_color}:*.pyi=${code_color}"
    
    # Web Development
    export LS_COLORS="${LS_COLORS}:*.js=${code_color}:*.ts=${code_color}:*.tsx=${code_color}:*.jsx=${code_color}:*.vue=${code_color}:*.css=${code_color}:*.scss=${code_color}:*.sass=${code_color}:*.less=${code_color}:*.html=${doc_color}:*.htm=${doc_color}"
    
    # Systems Programming
    export LS_COLORS="${LS_COLORS}:*.rs=${code_color}:*.go=${code_color}:*.c=${code_color}:*.cpp=${code_color}:*.cc=${code_color}:*.h=${code_color}:*.hpp=${code_color}"
    
    # JVM Languages
    export LS_COLORS="${LS_COLORS}:*.java=${code_color}:*.kt=${code_color}:*.scala=${code_color}:*.gradle=${config_color}"
    
    # Shell Scripts (use exec color since they're executable)
    export LS_COLORS="${LS_COLORS}:*.sh=${exec_color}:*.bash=${exec_color}:*.zsh=${exec_color}:*.fish=${exec_color}"
    
    # Config/Data files
    export LS_COLORS="${LS_COLORS}:*.json=${config_color}:*.yaml=${config_color}:*.yml=${config_color}:*.toml=${config_color}:*.ini=${config_color}:*.conf=${config_color}:*.config=${config_color}:*.env=${config_color}"
    
    # Docker/K8s
    export LS_COLORS="${LS_COLORS}:*Dockerfile=${config_color}:*docker-compose.yml=${config_color}:*.dockerignore=${special_color}"
    
    # Documentation
    export LS_COLORS="${LS_COLORS}:*.md=${doc_color}:*.rst=${doc_color}:*.txt=${doc_color}:*README=${doc_color}:*LICENSE=${doc_color}:*.pdf=${doc_color}"
    
    # Archives (only common ones)
    export LS_COLORS="${LS_COLORS}:*.zip=${archive_color}:*.tar=${archive_color}:*.gz=${archive_color}:*.bz2=${archive_color}:*.7z=${archive_color}:*.rar=${archive_color}"
    
    # Media (only common ones)
    export LS_COLORS="${LS_COLORS}:*.jpg=${media_color}:*.jpeg=${media_color}:*.png=${media_color}:*.gif=${media_color}:*.svg=${media_color}:*.mp4=${media_color}:*.mp3=${media_color}"
    
    # Git files
    export LS_COLORS="${LS_COLORS}:*.gitignore=${special_color}:*.gitmodules=${special_color}:*.gitattributes=${special_color}"
    
    # Build artifacts/temp files (muted)
    local log_color="38;2;$(_wal_hex_to_rgb $color15);2"
    local special_color="38;2;$(_wal_hex_to_rgb $color7);2"
    export LS_COLORS="${LS_COLORS}:*.log=${log_color}:*.bak=${special_color}:*.tmp=${special_color}:*.swp=${special_color}:*.swo=${special_color}:*.lock=${special_color}:*.cache=${special_color}"
    
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

# Initialize wal theme
_apply_wal_theme
_configure_wal_ls_colors
_configure_git_colors

