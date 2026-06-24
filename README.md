# configs

Personal configuration files (dotfiles) for a new machine setup.

## Contents

| Path | Description |
|------|-------------|
| `.zshrc` | Zsh shell configuration |
| `.vimrc` | Vim editor configuration |
| `.copilot/` | GitHub Copilot configuration |

## Install

Clone the repository to a permanent location (the symlinks will point here):

```sh
git clone https://github.com/fmacherey/configs.git ~/configs
cd ~/configs
```

Then run the install script:

```sh
./install.sh --install
```

This creates symlinks from `$HOME` to the files in this repository, e.g.:

```
~/.zshrc     →  ~/configs/.zshrc
~/.vimrc     →  ~/configs/.vimrc
~/.copilot   →  ~/configs/.copilot
```

Because the files are symlinked, any future `git pull` immediately takes effect everywhere.

## Usage

```
./install.sh [OPTION]

Options:
  --help      Show this help message and exit
  --install   Create symlinks for all whitelisted files and directories
  --update    Pull the latest changes from the repository (git pull)
  --dryrun    Show what would be installed without creating any symlinks
```

### `--dryrun`

Preview what would be linked without touching anything:

```sh
./install.sh --dryrun
```

### `--install`

Create all symlinks. If a file already exists at the target location you will be prompted:

```
[WARN]  Already exists: /home/user/.zshrc
  What would you like to do?
  [s] Skip  (leave as is)
  [r] Repo  (replace with symlink to repo version)
  [k] Keep  (keep existing file, do nothing)
  Choice [s/r/k]:
```

### `--update`

Pull the latest changes. Since the home directory files are symlinks, this is all that is needed to update them:

```sh
./install.sh --update
```

## Adding new files

To add a new config file to the install script, open `install.sh` and add the file name to the `FILES` array (or the directory name to the `DIRS` array):

```sh
FILES=(.zshrc .vimrc .your_new_file)
DIRS=(.copilot .your_new_dir)
```

## License

[MIT](LICENSE)
