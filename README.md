
## Android dotfiles

### Pre-requisites
Download and install [termux](https://github.com/termux/termux-app#github) apk [from f-droid](https://f-droid.org/en/packages/com.termux/)

### Installation

Don't worry about warnings from `termux-setup-storage` about deleting data. Should be fine.

```bash
export DEBIAN_FRONTEND=noninteractive
termux-setup-storate
pkg update && pkg upgrade
pkg install gh git
gh auth login
git clone https://github.com/MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```

[//]: # (TODO sync.sh file; obsidian vault sync aliases, ...)


Optional next steps:
- Use Makefile to set up ssh, clone repos, ...


### Credits
- [Dotbot](https://github.com/anishathalye/dotbot/tree/da928a4c6b65148bfda3138674da1730c143f396)
- [Jovial Theme](https://github.com/zthxxx/jovial)
- Zsh
- Various .functions (and .aliases) from other great dotfiles repos

[//]: # (TODO example image with theme, ls colors, neofetch, ...)
