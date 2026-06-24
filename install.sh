#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Whitelisted files and directories to install
FILES=(.zshrc .vimrc)
DIRS=(.copilot)

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────

print_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Options:
  --help      Show this help message and exit
  --install   Create symlinks for all whitelisted files and directories
  --update    Pull the latest changes from the repository (git pull)
  --dryrun    Show what would be installed without creating any symlinks

If no option is given, this help is printed.
EOF
}

info()    { echo "[INFO]  $*"; }
warning() { echo "[WARN]  $*"; }
error()   { echo "[ERROR] $*" >&2; }

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
                info "Removing existing: $dst"
                rm -rf "$dst"
                ;;
        esac
    fi

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
    for f in "${FILES[@]}"; do
        echo "  $HOME/$f  →  $REPO_DIR/$f"
    done
    for d in "${DIRS[@]}"; do
        echo "  $HOME/$d  →  $REPO_DIR/$d"
    done
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
    echo ""
    info "Done."
}

cmd_update() {
    info "Pulling latest changes in $REPO_DIR ..."
    git -C "$REPO_DIR" pull
    info "Done. All symlinked files are now up to date."
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
    --update)  cmd_update ;;
    --dryrun)  cmd_dryrun ;;
    *)
        error "Unknown option: $1"
        echo ""
        print_help
        exit 1
        ;;
esac
