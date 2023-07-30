
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
pkg install gh git python
gh auth login
cd /data/data/com.termux/files/home  # == ~
git clone -b android --single-branch https://github.com/MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles
cd ~/.dotfiles
./install
```

*open new shell*

Optional next steps:
- Use Makefile to set up miniconda, ...

```./install``` is idempotent, so you can run it multiple times without breaking anything, i.e. after pulling new changes, which will update the symlinks etc.

#### Obsidian

Use the script ``obsidian_clone_vault`` to clone the obsidian vault. 
An "obsidian" folder will be created in the android home directory.  
To automatically commit, pull and push, run ``obsidian_sync``. Make sure to aalways sync before and after you work on one of them, or you'll need to deal with merge conflicts (``obsidian_push_branch_with_conflicts`` to reset master to origin, then you can merge the branch via pc).

[//]: # (TODO sync.sh script, aliases etc.)
[//]: # (TODO script / alias for updating vault configs)


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
![screenshot-android](https://github.com/MaxWolf-01/dotfiles/assets/69987866/54ade9f2-239f-427a-9888-d8469d0e3134)
 
