#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Whitelisted files and directories to install
FILES=(.zshrc .vimrc .gitconfig)
DIRS=(.copilot)

# Additional source -> destination mappings
VSCODE_SETTINGS_SRC="$REPO_DIR/vscode/settings.json"
VSCODE_SETTINGS_DST="$HOME/Library/Application Support/Code/User/settings.json"
VSCODE_EXTENSIONS_FILE="$REPO_DIR/vscode/extensions.txt"
VSCODE_CLI="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
BREW_PACKAGES_FILE="$REPO_DIR/brew/packages.txt"
BACKUP_DIR="$REPO_DIR/configs.backup"

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────

print_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Options:
  --help      Show this help message and exit
  --install   Create symlinks for all whitelisted files and directories
    --install-vscode-extensions
                            Install VS Code extensions listed in vscode/extensions.txt
    --install-packages
                            Install Homebrew formulae and casks from brew/packages.txt
  --update    Pull the latest changes from the repository (git pull)
  --dryrun    Show what would be installed without creating any symlinks

If no option is given, this help is printed.
EOF
}

info()    { echo "[INFO]  $*"; }
warning() { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; }

backup_item() {
    local target="$1"
    local backup_target="$BACKUP_DIR$target"

    mkdir -p "$(dirname "$backup_target")"

    if [ -e "$backup_target" ] || [ -L "$backup_target" ]; then
        local timestamp
        timestamp="$(date +%Y%m%d%H%M%S)"
        backup_target="${backup_target}.${timestamp}"
    fi

    mv "$target" "$backup_target"
    info "Backed up: $target → $backup_target"
}

# Ask the user what to do when a target path already exists.
# Sets the global variable CONFLICT_ACTION to one of: skip | repo | keep
ask_conflict() {
    local target="$1"
    echo ""
    warning "Already exists: $target"
    echo "  What would you like to do?"
    echo "  [s] Skip  (leave as is)"
    echo "  [r] Repo  (replace with symlink to repo version)"
    echo "  [k] Keep  (keep existing file, do nothing)"
    while true; do
        read -r -p "  Choice [s/r/k]: " choice
        case "$choice" in
            s|S) CONFLICT_ACTION="skip"; return ;;
            r|R) CONFLICT_ACTION="repo"; return ;;
            k|K) CONFLICT_ACTION="keep"; return ;;
            *) echo "  Please enter s, r, or k." ;;
        esac
    done
}

# Create a single symlink, handling conflicts
link_item() {
    local src="$1"        # full path inside the repo
    local dst="$2"        # full path in $HOME

    if [ ! -e "$src" ] && [ ! -d "$src" ]; then
        warning "Source not found, skipping: $src"
        return
    fi

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        info "Already linked: $dst → $src"
        return
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        ask_conflict "$dst"
        case "$CONFLICT_ACTION" in
            skip|keep)
                info "Skipping: $dst"
                return
                ;;
            repo)
                info "Backing up existing: $dst"
                backup_item "$dst"
                ;;
        esac
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    info "Linked: $dst → $src"
}

# ──────────────────────────────────────────────
# Commands
# ──────────────────────────────────────────────

cmd_dryrun() {
    echo ""
    echo "Dry run — the following symlinks would be created:"
    echo ""
    printf "  %-6s | %-50s | %s\n" "TYPE" "TARGET" "SOURCE"
    printf "  %-6s-+-%-50s-+-%s\n" "------" "--------------------------------------------------" "------------------------------"
    for f in "${FILES[@]}"; do
        printf "  %-6s | %-50s | %s\n" "file" "$HOME/$f" "$REPO_DIR/$f"
    done
    for d in "${DIRS[@]}"; do
        printf "  %-6s | %-50s | %s\n" "dir" "$HOME/$d" "$REPO_DIR/$d"
    done
    printf "  %-6s | %-50s | %s\n" "file" "$VSCODE_SETTINGS_DST" "$VSCODE_SETTINGS_SRC"
    echo ""
}

cmd_install() {
    info "Installing config symlinks from $REPO_DIR to $HOME ..."
    echo ""
    for f in "${FILES[@]}"; do
        link_item "$REPO_DIR/$f" "$HOME/$f"
    done
    for d in "${DIRS[@]}"; do
        link_item "$REPO_DIR/$d" "$HOME/$d"
    done
    link_item "$VSCODE_SETTINGS_SRC" "$VSCODE_SETTINGS_DST"
    echo ""
    info "Done."
}

cmd_update() {
    info "Pulling latest changes in $REPO_DIR ..."
    git -C "$REPO_DIR" pull
    info "Done. All symlinked files are now up to date."
}

cmd_install_vscode_extensions() {
    info "Installing VS Code extensions from $VSCODE_EXTENSIONS_FILE ..."

    if [ ! -f "$VSCODE_EXTENSIONS_FILE" ]; then
        error "Extensions file not found: $VSCODE_EXTENSIONS_FILE"
        exit 1
    fi

    if [ ! -x "$VSCODE_CLI" ]; then
        error "VS Code CLI not found or not executable: $VSCODE_CLI"
        exit 1
    fi

    while IFS= read -r ext || [ -n "$ext" ]; do
        if [ -z "$ext" ] || [[ "$ext" == \#* ]]; then
            continue
        fi

        info "Installing extension: $ext"
        "$VSCODE_CLI" --install-extension "$ext"
    done < "$VSCODE_EXTENSIONS_FILE"

    info "Done installing VS Code extensions."
}

cmd_install_packages() {
    local package
    local cask

    info "Installing Homebrew packages from $BREW_PACKAGES_FILE ..."

    if [ ! -f "$BREW_PACKAGES_FILE" ]; then
        error "Packages file not found: $BREW_PACKAGES_FILE"
        exit 1
    fi

    if ! command -v brew >/dev/null 2>&1; then
        error "Homebrew 'brew' command not found in PATH."
        exit 1
    fi

    BREW_PACKAGES=()
    BREW_CASKS=()
    # shellcheck source=/dev/null
    source "$BREW_PACKAGES_FILE"

    info "Updating Homebrew..."
    brew update
    info "Upgrading installed Homebrew packages..."
    brew upgrade

    for package in "${BREW_PACKAGES[@]}"; do
        if brew list --formula "$package" >/dev/null 2>&1; then
            info "Already installed formula: $package"
            continue
        fi
        info "Installing formula: $package"
        brew install "$package"
    done

    for cask in "${BREW_CASKS[@]}"; do
        if brew list --cask "$cask" >/dev/null 2>&1; then
            info "Already installed cask: $cask"
            continue
        fi
        info "Installing cask: $cask"
        brew install --cask "$cask"
    done

    info "Done installing Homebrew packages."
}

# ──────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────

if [ $# -eq 0 ]; then
    print_help
    exit 0
fi

case "$1" in
    --help)    print_help ;;
    --install) cmd_install ;;
    --install-vscode-extensions) cmd_install_vscode_extensions ;;
    --install-packages|--install--packages) cmd_install_packages ;;
    --update)  cmd_update ;;
    --dryrun)  cmd_dryrun ;;
    *)
        error "Unknown option: $1"
        echo ""
        print_help
        exit 1
        ;;
esac
