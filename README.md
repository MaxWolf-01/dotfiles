# Dotfiles

Ubuntu configs.

If you plan on cloning / forking this repo, **make sure to change the github user information in gitconfig**.  
But if you're starting from scratch anyway, I would recommend you don't fork the repo but just copy the bits and pieces you need.

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
sudo apt-get update && sudo apt-get install -y git
git clone -b ubuntu --single-branch git@github.com:MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```

*reboot*

Optional next steps:
- Use Makefile to install miniconda, docker, ...

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
![screenshot](https://user-images.githubusercontent.com/69987866/222907218-967d172c-b294-4389-9afb-3134bc815ea8.png)
