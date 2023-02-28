source ~/.aliases
source ~/.functions
source ~/.colors

export EDITOR='vim';

HISTFILE=~/.histfile
HISTSIZE=1000000
SAVEHIST=1000000
export HISTCONTROL='ignoreboth';  # Omit duplicates and commands that begin with a space from history.

setopt autocd notify appendhistory complete_aliases hist_ignore_all_dups # https://zsh.sourceforge.io/Doc/Release/Options.html
unsetopt beep caseglob

export PATH=~/.dotfiles/bin:${PATH}
export PATH=~/minconda/bin:${PATH}

export PYTHONIOENCODING='UTF-8'; # Make Python use UTF-8 encoding for output to stdin, stdout, and stderr.

# Plugins #  TODO just replace with my own custom function for that?
# More plugins: https://github.com/unixorn/awesome-zsh-plugins
# More completions: https://github.com/zsh-users/zsh-completions
plug "zsh-users/zsh-syntax-highlighting"
plug "zsh-users/zsh-autosuggestions"
# plug "esc/conda-zsh-completion"

# fuzzy search with Ctrl + R TODO broken?
- [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Theme #
source ~/.dotfiles/jovial.zsh-theme
