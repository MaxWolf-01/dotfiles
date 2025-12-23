# Linux Dotfiles

Dotfiles for Ubuntu desktop, servers/containers, and Android. → [Setup instructions](#setup-desktop)

### Overview

If you plan on cloning / forking this repo, be aware that all config is tailored to me (e.g. paths, usernames, ...) and make sure to change .gitconfig to your name and email.
But if you're starting from scratch anyway (_which I recommend_, in order to become fammiliar with the functionality bit by bit).
Since these dotfiles are tailored specifically to me, your needs and preferences will be different and I would recommend you just copy the bits and pieces you need.

```bash
dotfiles
├── bin           # custom scripts
├── desktop       # ubuntu: desktop shortcuts, icons
├── git           # git config -> ~/.gitconfig, ...
├── nix           # home-manager modules
│   └── home
│       ├── common.nix   # CLI tools (all hosts)
│       ├── desktop.nix  # GUI apps
│       ├── gnome.nix    # GNOME-specific
│       ├── x11.nix      # X11: xclip
│       ├── wayland.nix  # Wayland: wl-clipboard
│       └── hosts/       # per-machine configs
├── vim           # vim/neovim config
├── secrets       # private encrypted repo (see setup secrets)
├── zsh
│   ├── plugin-files  # plugin/theme scripts
│   ├── aliases       # shell aliases
│   ├── exports       # env vars, PATH
│   ├── functions     # custom functions
│   └── zshrc         # main config
├── flake.nix     # nix flake (home-manager hosts)
└── setup         # symlinks, package installers, platform setups
```

### Setup (Desktop)

<details>
  <summary>Post (distro-) installation steps</summary>

  ```bash
sudo apt update && sudo apt full-upgrade
sudo apt autoremove && sudo apt clean
  ```
</details>

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup minimal
```

**Restart shell**, then set host and run Home Manager:

Hosts: `zephyrus` (X11), `xmg19` (Wayland), `minimal` (CLI), `minimal-root` (CLI as root)
```bash
echo 'export NIX_HOST="zephyrus"' >> ~/.local_exports
source ~/.local_exports
nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST
gh auth login -w -s admin:public_key
```

After first run, use `hmswitch` to apply changes.

Additional setup:
```bash
./setup cli
./setup ubuntu
./setup secrets
```

`./setup` functions are idempotent. Export your gnome keyboard shortcuts via `./bin/keybindings.pl` before `./setup ubuntu` to avoid overwriting them.

<details>
<summary>Setup (Server/Container)</summary>

```bash
apt-get update && apt-get install -y git
git clone --depth 1 https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup minimal
```

**Restart shell**, then:

```bash
# use minimal-root if running as root, minimal otherwise
echo 'export NIX_HOST="minimal-root"' >> ~/.local_exports && source ~/.local_exports
nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST
gh auth login -w -s admin:public_key
```
</details>

<details>
<summary>GitHub SSH key setup (optional)</summary>

```bash
./setup sshkeys
gh ssh-key add ~/.ssh/id_ed25519.pub -t "$(hostname)-dotfiles-$(date +%F)"
ssh -T git@github.com || true
git -C ~/.dotfiles remote set-url origin git@github.com:MaxWolf-01/dotfiles.git
```
</details>

### Setup (Android)

Download and install [termux](https://github.com/termux/termux-app)
apk [from f-droid](https://f-droid.org/en/packages/com.termux/), then:
```bash
export DEBIAN_FRONTEND=noninteractive
termux-setup-storage
pkg update && pkg upgrade && pkg install git gh python && gh auth login
cd /data/data/com.termux/files/home && git clone --depth 1 https://github.com/MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles && cd ~/.dotfiles && ./install && ./setup android
```
Don't worry about warnings from `termux-setup-storage` about deleting all your data. *Should* be fine.  
`~/storage/shared` in your termux home directory [is symlinked](https://android.stackexchange.com/a/185949) `/storage/emulated/0` (where downloads folder etc. are on Android).

`./setup android` will install essential packages and sets up [**Obsidian**](https://obsidian.md/):
An "obsidian" folder will be created in the android home directory.  
To automatically commit, pull and push, run `sync`.
Other aliases for android specifically are in [zsh/android](https://github.com/MaxWolf-01/dotfiles/tree/master/zsh/android).
Scripts for pushing conflicts to deal with them in an IDE and fixing occasional corrupt git objects are in `bin`.

### What's in it?

**Functions**

- `o` (open file explorer or the file given as argument)
- `mcd` (make directory and cd into it)
- `targz` (create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression)
- `extract` (extracts archived files / mounts disk images)
- `fs` (determine size of a file or total size of a directory)
- `lsfs` (list n largest files and folder in a directory, recursively; smallest if n is negative; n defaults to 10)
- `gz` (compare original and gzipped file size)
- `tre` (`tre` is a shorthand for `tree` with hidden files and color enabled, ignoring the `.git` directory, listing
  directories first.)
- `newsshpwd`` (change the ssh passphrase of given key)
- `numel`` (number of elements in folder)
- `archive_md` (archive websites as markdown using [dhravya/markdowner](https://github.com/dhravya/markdowner)
- and many more ... (see functions / aliases in [zsh folder](https://github.com/MaxWolf-01/dotfiles/tree/master/zsh))

Various **scripts**, such as gnome keyboard shortcut backup/restore, laptop battery limiter, backup scripts, nightlight
toggle shortcuts, ...

**Plugins**

- [fzf](https://github.com/junegunn/fzf) - fuzzy finder for commands (Ctrl + R) and files (Ctrl + T), (Alt + C) to cd
  into selected dir. Examples:
    - ``vim <Ctrl + T>`` OR ``vim **<tab>`` (trigger `**` can be changed
      in [exports](https://github.com/MaxWolf-01/dotfiles/blob/master/zsh/exports))
    - ``git switch $(git branch -a | fzf)``
- [Zap](https://github.com/zap-zsh/zap) plugin manger
- [Zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [Zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [Zoxide](https://github.com/ajeetdsouza/zoxide) with custom autocd integration - just type directory names to jump (e.g. `Dow` -> `~/Downloads`, from *anywhere*)
- ...

### Credits

- [Jovial Theme](https://github.com/zthxxx/jovial)
- [Zsh](https://www.zsh.org/)
- [Nix/Home Manager](https://github.com/nix-community/home-manager)
- Various functions, aliases and scripts from other great dotfiles repos (see top
  of [functions](https://github.com/MaxWolf-01/dotfiles/blob/master/zsh/functions) / the respective scripts)
- More resources on dotfiles:
    - [dotfiles.github.io](https://dotfiles.github.io/)

### Visuals

<img src="https://github-production-user-asset-6210df.s3.amazonaws.com/69987866/281566583-dbcb2895-8ae7-4ed0-9a7a-b31ae9e71a26.png" width="350">
<img src="https://user-images.githubusercontent.com/69987866/222906712-a760aab9-39dc-40aa-91e2-dd5e89290749.png" width="350">
<img src="https://github.com/MaxWolf-01/dotfiles/assets/69987866/54ade9f2-239f-427a-9888-d8469d0e3134" width="250">
