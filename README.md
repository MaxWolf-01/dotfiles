# Dotfiles

All the common config is in the [master](https://github.com/MaxWolf-01/dotfiles/tree/master) branch.  
As of now I also have os specific configs for 
[ubuntu](https://github.com/MaxWolf-01/dotfiles/tree/ubuntu),
[proxmox](https://github.com/MaxWolf-01/dotfiles/tree/proxmox) and 
[android](https://github.com/MaxWolf-01/dotfiles/tree/android) with specific installation instructions.  
Master is mostly identical to ubuntu for now.

If you plan on cloning / forking this repo, **make sure to change the github user information in gitconfig**.  
But if you're starting from scratch anyway, I would recommend you don't fork the repo but just copy the bits and pieces you need.

### Installation

Setup ssh for private github repos (optional):
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
cd ~
git clone git@github.com:MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```

*reboot*

Optional next steps:
- Use Makefile to install miniconda, docker, ...

```./install``` is idempotent, so you can run it multiple times without breaking anything, i.e. after pulling new changes, which will update the symlinks etc.

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
- ``numel`` (number of elements in folder)
- ``conda`` / ``pip`` (aliases prevent accidentally installing packages in the base env. Skip the alias by using `\conda` / `\pip` )
- and more ... (see functions / aliases in [zsh folder](https://github.com/MaxWolf-01/dotfiles/tree/master/zsh))

**Scripts**

- ``sshperm`` (change permissions of .ssh folder and keys)

**Plugins**

- [fzf](https://github.com/junegunn/fzf) - fuzzy finder for commands (Ctrl + R) and files (Ctrl + T), (Alt + C) to cd into selected dir. Examples:
  - ``vim <Ctrl + T>`` OR ``vim **<tab>`` (trigger `**` can be changed in [exports](https://github.com/MaxWolf-01/dotfiles/blob/master/zsh/exports))
  - ``git switch $(git branch -a | fzf)``
- [Zap](https://github.com/zap-zsh/zap) plugin manger
- [Zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [Zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- ...


### Credits
- [Dotbot](https://github.com/anishathalye/dotbot/tree/da928a4c6b65148bfda3138674da1730c143f396)
- [Jovial Theme](https://github.com/zthxxx/jovial)
- [Zsh](https://www.zsh.org/)
- Various functions and aliases from other great dotfiles repos (see top of [functions](https://github.com/MaxWolf-01/dotfiles/blob/master/zsh/functions))
- More resources on dotfiles:
  - [dotfiles.github.io](https://dotfiles.github.io/)

### Visuals
![screenshot-ubuntu](https://user-images.githubusercontent.com/69987866/222907218-967d172c-b294-4389-9afb-3134bc815ea8.png)  
![screenshot-proxmox](https://user-images.githubusercontent.com/69987866/222906712-a760aab9-39dc-40aa-91e2-dd5e89290749.png)  
![screenshot-android](https://github.com/MaxWolf-01/dotfiles/assets/69987866/bab21cc9-6d40-4a7b-a021-feccf843d290)

