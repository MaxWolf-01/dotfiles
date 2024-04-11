# Linux Dotfiles

I use these dotfiles for my daily driver Ubuntu and Android setup, as well as proxmox and LXCs.i

### Overview

If you plan on cloning / forking this repo, **make sure to change the github user information in gitconfig**.  
But if you're starting from scratch anyway (_which I recommend_, in order to become fammiliar with the functionality bit
by bit).
Since these dotfiles are tailored specifically to me, your needs and preferences will be different and I would recommend you just copy the bits and pieces you need.

```bash
dotfiles
├── bin  # custom scripts
├── desktop # ubuntu specifc: desktop shortcuts, icons
├── [dotbot](https://github.com/anishathalye/dotbot)
├── git  # git config maps to ~/.gitconig, ...
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

### Setup (Regular)

Get pre-requisites:

```bash
sudo apt-get update && sudo apt-get install -y git
```

```bash
cd ~ && git clone git@github.com:MaxWolf-01/dotfiles.git
# or
cd ~ && git clone --depth 1 git@github.com:MaxWolf-01/dotfiles.git
```

```bash
mv dotfiles .dotfiles && cd ~/.dotfiles && ./install
```

*open new shell* (or reboot when in doubt)

Optional next steps:

Run ``./setup all`` to install packages, plugins, themes, ...
Works on Ubuntu.
Run ``./setup minimal`` for an unbloated setup with essential cli tools and a minimal zsh setup on any system.
For more/specific setups, check out `setup`.

```./install``` is idempotent, so you can run it multiple times without breaking anything, i.e. after pulling new
changes, which will update the symlinks etc.
But make sure to export your gnome keyboard shortcuts via `./bin/keybindings.pl` before you execute the script,
otherwise they
get overwritten by mine.

### Setup (Android)

Download and install [termux](https://github.com/termux/termux-app#github)
apk [from f-droid](https://f-droid.org/en/packages/com.termux/).
Don't worry about warnings from `termux-setup-storage` about deleting all your data. *Should* be fine.  
``~/storage/shared`` in your termux home
directory [is symlinked](https://android.stackexchange.com/a/185949) ``/storage/emulated/0`` (where downloads folder
etc. are on Android)

```bash
export DEBIAN_FRONTEND=noninteractive
termux-setup-storage
pkg update && pkg upgrade && pkg install git
cd /data/data/com.termux/files/home && git clone --depth 1 https://github.com/MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles && cd ~/.dotfiles && ./install
./setup android
```

``./setup android`` will install essential packages and setup up [**Obsidian**](https://obsidian.md/).
An "obsidian" folder will be created in the android home directory.  
To automatically commit, pull and push, run ``sync``.
Aliases for android specifically are in [zsh/android](https://github.com/MaxWolf-01/dotfiles/tree/master/zsh/android).
Make sure to always sync before and after you work on one of them, or you'll need to deal with merge conflicts.
Scripts for pushing conflicts to deal with them in an IDE and fixing occasional corrupt git objects are in `bin`.

### What's in it?

**Functions**

- ``o`` (open file explorer)
- ``mcd`` (make directory and cd into it)
- ``targz`` (create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression)
- ``extract`` (extracts archived files / mounts disk images)
- ``fs`` (determine size of a file or total size of a directory)
- ``lsfs`` (list n largest files and folder in a directory, recursively; smallest if n is negative; n defaults to 10)
- ``gz`` (compare original and gzipped file size)
- ``tre`` (`tre` is a shorthand for `tree` with hidden files and color enabled, ignoring the `.git` directory, listing
  directories first.)
- ``newsshpwd`` (change the ssh passphrase of given key)
- ``numel`` (number of elements in folder)
  using `\conda` / `\pip` )
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
<br>
<img src="https://github.com/MaxWolf-01/dotfiles/assets/69987866/54ade9f2-239f-427a-9888-d8469d0e3134" width="250">
