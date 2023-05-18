
# Android dotfiles

If you plan on cloning / forking this repo, **make sure to change the github user information in gitconfig**.    
But if you're starting from scratch anyway, I would recommend you don't fork the repo but just copy the bits and pieces you need.

### Pre-requisites
Download and install [termux](https://github.com/termux/termux-app#github) apk [from f-droid](https://f-droid.org/en/packages/com.termux/).

### Installation

Don't worry about warnings from `termux-setup-storage` about deleting all your data. *Should* be fine.  
``~/storage/shared`` in your termux home directory [is symlinked](https://android.stackexchange.com/a/185949) ``/storage/emulated/0`` (where downloads folder etc. are on Android)

```bash
export DEBIAN_FRONTEND=noninteractive
termux-setup-storage
pkg update && pkg upgrade
pkg install gh git
gh auth login
cd /data/data/com.termux/files/home  # == ~
git clone -b android --single-branch https://github.com/MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```

*open new shell*

Optional next steps:
- Use Makefile to set up ssh, obsidian, ...

#### Obsidian

Use ``make obsidian-vaults`` to clone obsidian vault. 
An "obsidian" folder will be created in your home directory.

[//]: # (TODO sync.sh script, aliases etc.)
[//]: # (TODO script / alias for updating vault configs)

### Credits
- [Dotbot](https://github.com/anishathalye/dotbot/tree/da928a4c6b65148bfda3138674da1730c143f396)
- [Jovial Theme](https://github.com/zthxxx/jovial)
- [Zsh](https://www.zsh.org/)
- Various functions and aliases from other great dotfiles repos (see top of [functions](https://github.com/MaxWolf-01/dotfiles/blob/master/zsh/functions))
- More resources on dotfiles:
  - [dotfiles.github.io](https://dotfiles.github.io/)

### Visuals
![screenshot-android](https://github.com/MaxWolf-01/dotfiles/assets/69987866/a6469cd2-c2ab-42f5-a212-f62e367b4fad)  
