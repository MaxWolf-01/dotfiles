# Proxmox dotfiles

Less bloat here.

### Installation

Setup ssh for private github repos:
```bash
# use your github email to generate a new ssh key
ssh-keygen -t ed25519 -C "69987866+MaxWolf-01@users.noreply.github.com"
# change permissions of .ssh folder and keys
find ~/.ssh/ -type f -exec chmod 600 {} \; && find ~/.ssh/ -type d -exec chmod 700 {} \; && find ~/.ssh/ -type f -name "*.pub" -exec chmod 644 {} \;
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
echo "Put your public key on github -> settings -> SSH and GPG keys"
```

```bash
apt update && apt-get install -y git
git clone -b proxmox --single-branch git@github.com:MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```

*reboot*

### Helpful ...

**Functions**

- ``o`` (open file explorer)
- ``mcd`` (make directory and cd into it)
- ``targz`` (create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression)
- ``extract`` (extracts archived files / mounts disk images)
- ``fs`` (determine size of a file or total size of a directory)
- ``gz`` (compare original and gzipped file size)
- ``tre`` (`tre` is a shorthand for `tree` with hidden files and color enabled, ignoring the `.git` directory, listing directories first.)
- ``newsshpwd`` (change the ssh passphrase of given key)
- pip / conda installs in base env throw an error
- and more ... (see functions)

**Scripts**

- ``sshperm`` (change permissions of .ssh folder and keys)

### Credits
- [Dotbot](https://github.com/anishathalye/dotbot/tree/da928a4c6b65148bfda3138674da1730c143f396)
- [Jovial Theme](https://github.com/zthxxx/jovial)
- Zsh
- Various functions and aliases from other great dotfiles repos (see top of functions / aliases)
- More resources on dotfiles:
  - [dotfiles.github.io](https://dotfiles.github.io/)

### Visuals
![proxmox-screenshot](https://user-images.githubusercontent.com/69987866/222906712-a760aab9-39dc-40aa-91e2-dd5e89290749.png)