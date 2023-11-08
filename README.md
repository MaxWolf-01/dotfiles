# Ubuntu Dotfiles

### Overview

All the common config is in the [master](https://github.com/MaxWolf-01/dotfiles/tree/master) branch.  
As of now I also have os specific configs for 
[ubuntu](https://github.com/MaxWolf-01/dotfiles/tree/ubuntu),
[proxmox](https://github.com/MaxWolf-01/dotfiles/tree/proxmox),
[lxc(minimal)](https://github.com/MaxWolf-01/dotfiles/tree/lxc) and
[android](https://github.com/MaxWolf-01/dotfiles/tree/android) with specific installation instructions and dotfiles tailored for the platform (e.g.: android, an unbloated bootstrap script for small containers, ...).  
The master branch only serves as a base / for structure and the public Readme.  
**For the latest, fully fledged config, take a look at the this branch, since this is the one I use on a daily basis.**

If you plan on cloning / forking this repo, **make sure to change the github user information in gitconfig**.  
But if you're starting from scratch anyway (_which I recommend_, in order to become fammiliar with the functionality bit by bit and since these dotfiles are tailored specifically to me, your needs will be different), I would recommend you don't fork the repo but just copy the bits and pieces you need.

##### Structure

```bash
dotfiles
├── bin  # custom scripts
├── desktop # ubuntu specifc: desktop shortcuts, icons
├── [dotbot](https://github.com/anishathalye/dotbot)
├── git  # git config mapt to ~/.gitconig, ...
├── ssh  # ssh config maps to ~/.ssh
├── vim  # vim config
├── zsh
│   ├── plugin-files # place for plugin / theme scripts
│   ├── aliases # aliases for zsh, git, ...
│   ├── colors # colors for filetypes in shell
│   ├── exports # env vars and path configs
│   ├── functions # custom functions see below
│   ├── plugins # sourcing plugins
│   ├── zsh_config # zsh specific settings
│   └── zshrc  # putting it all together
├── .gitmodules # for dotbot
├── bootstrap # installing packages, plugins, theme, ...
├── install # idempotent main script
├── install.conf.yaml # setup dirs, symlinks, ...
└── Makefile # targets for installing various apps
```

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
cd ~
git clone -b ubuntu --single-branch git@github.com:MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```

*open new shell* (or reboot when in doubt)

Optional next steps:
- Use Makefile to install miniconda, docker, ...

```./install``` is idempotent, so you can run it multiple times without breaking anything, i.e. after pulling new changes, which will update the symlinks etc.
But make sure to export your keyboard shortcuts via ./bin/keybindings.pl before you execute the script, otherwise they get overwritten by mine.

### Helpful ...

**Functions**

- ``o`` (open file explorer)
- ``mcd`` (make directory and cd into it)
- ``targz`` (create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression)
- ``extract`` (extracts archived files / mounts disk images)
- ``fs`` (determine size of a file or total size of a directory)
- ``lsfs`` (list n largest files in a directory; smallest if n is negative; n defaults to 10)
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
![screenshot](https://github-production-user-asset-6210df.s3.amazonaws.com/69987866/281566583-dbcb2895-8ae7-4ed0-9a7a-b31ae9e71a26.png)
