#!/usr/bin/env zsh
# Enter rewrites a line that is only a target into the command for it:
#   a path to a file that is not executable  ->  o <path>  (opens it in its default app)
#   a word zoxide knows as a directory        ->  z <word>
# A directory path needs no rewrite: autocd (zsh_config) already cds into it.
# The history keeps the rewritten line.

# Sets REPLY to the file the line names, if it names one to open. The line may
# be quoted or escaped the way a pasted path often is; a line whose first word
# is a command stays a command.
function _accept_line_file() {
    local -a words=(${(z)1})
    (( $#words )) || return 1
    whence -- "$words[1]" &>/dev/null && return 1
    REPLY=${(Q)1}
    REPLY=${REPLY/#\~/$HOME}
    [[ -f $REPLY && ! -x $REPLY ]]
}

function _accept_line_rewrite() {
    if _accept_line_file "$BUFFER"; then
        BUFFER="o ${(q)REPLY}"
    elif [[ $BUFFER =~ ^[[:alnum:]_-]+$ ]] && (( $+commands[zoxide] )) \
        && ! whence -- "$BUFFER" &>/dev/null && zoxide query "$BUFFER" &>/dev/null; then
        BUFFER="z $BUFFER"
    fi
    zle .accept-line
}

zle -N accept-line _accept_line_rewrite
