# Proxmox dotfiles

Less bloat here.

### Installation

```bash
apt update
apt-get install -y git
ssh-keygen -t ed25519 -C "69987866+MaxWolf-01@users.noreply.github.com"
ssh-add ~/.ssh/id_ed25519
echo "Put your public key on github -> settings -> SSH and GPG keys"
```
```bash
git clone -b proxmox --single-branch git@github.com:MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```
*reboot*

### Credits
- [Dotbot](https://github.com/anishathalye/dotbot/tree/da928a4c6b65148bfda3138674da1730c143f396)
- [Jovial Theme](https://github.com/zthxxx/jovial)
- Zsh
- Various .functions (and .aliases) from other great dotfiles repos
- More resources on dotfiles:
  - [dotfiles.github.io](https://dotfiles.github.io/)

### Visuals
![screenshot](https://user-images.githubusercontent.com/69987866/222906712-a760aab9-39dc-40aa-91e2-dd5e89290749.png)