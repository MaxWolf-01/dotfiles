# Linux Dotfiles

I use these dotfiles for my daily driver Ubuntu and Android setup, as well as proxmox and LXCs.

<details>
<summary>Quick setup (Desktop)</summary>

```bash
sudo apt-get update && sudo apt-get install -y git gh openssh-client
gh auth login -w -s admin:public_key
git clone --depth 1 https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install && ./setup minimal
# Restart shell, set NIX_HOST in ~/.local_exports, then:
# nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST
./setup cli && ./setup ubuntu && ./setup secrets
```
</details>

<details>
<summary>Quick setup (Pods)</summary>

```bash
apt-get update && apt-get install -y git gh openssh-client
gh auth login -w -s admin:public_key
git clone --depth 1 https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install && ./setup minimal && ./setup cli
```

</details>

### Overview

If you plan on cloning / forking this repo, be aware that all config is tailored to me (e.g. paths, usernames, ...) and make sure to change .gitconfig to your name and email.
But if you're starting from scratch anyway (_which I recommend_, in order to become fammiliar with the functionality bit by bit).
Since these dotfiles are tailored specifically to me, your needs and preferences will be different and I would recommend you just copy the bits and pieces you need.

```bash
dotfiles
├── bin  # custom scripts
├── desktop # ubuntu specifc: desktop shortcuts, icons
├── [dotbot](https://github.com/anishathalye/dotbot)
├── git  # git config maps to ~/.gitconig, ...
├── nix  # nix/home-manager configs (flake.nix in root)
├── ssh  # ssh config maps to ~/.ssh
├── vim  # vim config
├── secrets # priv. & encrypted repo (see git/hooks & setup secrets)
├── zsh
│   ├── plugin-files # place for plugin / theme scripts
│   ├── aliases # aliases for zsh, git, ...
│   ├── colors # colors for filetypes in shell
│   ├── exports # env vars and path configs
│   ├── functions # custom functions
│   ├── plugins # sourcing plugins
│   ├── zsh_config # zsh specific settings
│   └── zshrc  # putting it all together
├── .gitmodules # for dotbot
├── setup # installing packages, plugins, theme, platform specific setups, ...
├── install # idempotent main install script (basic & quick setup)
├── install.conf.yaml # setup dir structure, symlinks, ...
```

### Setup (Desktop)

<details>
  <summary>Post (distro-) installation steps</summary>
  
  ```bash
sudo apt update && sudo apt full-upgrade
sudo apt autoremove && sudo apt clean
  ```
</details>

Pre-requisites and install flow:
```bash
sudo apt-get update && sudo apt-get install -y git gh openssh-client
gh auth login -w -s admin:public_key

# Clone via HTTPS (no SSH required yet)
git clone --depth 1 https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Base install (installs Nix)
./install && ./setup minimal
# Restart shell, then:
echo 'export NIX_HOST="zephyrus"' >> ~/.local_exports && source ~/.local_exports
nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST  # first time
# hmswitch  # after first run

# Optional
./setup cli
./setup ubuntu
./setup secrets

# SSH for pushing (optional, gh auth works for cloning)
./setup sshkeys
gh ssh-key add ~/.ssh/id_ed25519.pub -t "$(hostname)-dotfiles-$(date +%F)"
ssh -T git@github.com || true
git -C ~/.dotfiles remote set-url origin git@github.com:MaxWolf-01/dotfiles.git
```

`./install` and most functions in `setup` are idempotent, so you can run it multiple times without breaking anything, i.e. after pulling new changes, which will update the symlinks etc.
But make sure to export your gnome keyboard shortcuts via `./bin/keybindings.pl` before you execute `./setup ubuntu`, otherwise they get overwritten by mine.

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

- [Dotbot](https://github.com/anishathalye/dotbot/tree/da928a4c6b65148bfda3138674da1730c143f396)
- [Jovial Theme](https://github.com/zthxxx/jovial)
- [Zsh](https://www.zsh.org/)
- Various functions, aliases and scripts from other great dotfiles repos (see top
  of [functions](https://github.com/MaxWolf-01/dotfiles/blob/master/zsh/functions) / the respective scripts)
- More resources on dotfiles:
    - [dotfiles.github.io](https://dotfiles.github.io/)

### Visuals

<img src="https://github-production-user-asset-6210df.s3.amazonaws.com/69987866/281566583-dbcb2895-8ae7-4ed0-9a7a-b31ae9e71a26.png" width="350">
<img src="https://user-images.githubusercontent.com/69987866/222906712-a760aab9-39dc-40aa-91e2-dd5e89290749.png" width="350">
<img src="https://github.com/MaxWolf-01/dotfiles/assets/69987866/54ade9f2-239f-427a-9888-d8469d0e3134" width="250">
