# LXC Dotfiles

Minimal setup for LXC containers.

### Installation

```bash
apt-get update && apt-get install -y git
cd ~ && git clone -b lxc --single-branch https://github.com/MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```

*reboot*

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
