# Dotfiles

If you plan on cloning / forking this repo, **make sure to change the github user information in gitconfig**.  
But if you're starting from scratch anyway, I would recommend you don't fork the repo but just copy the bits and pieces you need.

### Installation

```commandline
sudo apt-get install -y gh git
gh auth login
git clone https://github.com/MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```
*reboot*

Optional next steps:
- Use Makefile to install miniconda, docker, ...


### Credits
- [Dotbot](https://github.com/anishathalye/dotbot/tree/da928a4c6b65148bfda3138674da1730c143f396)
- [Jovial Theme](https://github.com/zthxxx/jovial)
- Zsh
- Various .functions (and .aliases) from other great dotfiles repos
- More resources on dotfiles:
  - [dotfiles.github.io](https://dotfiles.github.io/)

[//]: # (TODO example image with theme, ls colors, ...)
