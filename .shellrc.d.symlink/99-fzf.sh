# Setup fzf
# ---------

if [[ ! "$PATH" == *$HOME/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}$HOME/.fzf/bin"
fi

# Auto-completion
[[ $- == *i* ]] && source "~/.fzf/shell/completion.$CURRENT_SHELL" 2> /dev/null

# Key bindings
bindings_file=~/.fzf/shell/key-bindings.$CURRENT_SHELL
[[ -f "${bindings_file}" ]] && source "${bindings_file}"

export FZF_DEFAULT_OPTS=" \
--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"


export FZF_CTRL_T_OPTS="
--height 60%
--preview 'bat --style=full --color=always {}'
--preview-window up,75%
"

# Set the default command to use ripgrep, as it's faster than find.
export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --hidden'
