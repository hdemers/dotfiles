# Setup fzf
# ---------

if [[ ! "$PATH" == */home/hdemers/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/hdemers/.fzf/bin"
fi

# Auto-completion
[[ $- == *i* ]] && source "~/.fzf/shell/completion.$CURRENT_SHELL" 2> /dev/null

# Key bindings
bindings_file=~/.fzf/shell/key-bindings.$CURRENT_SHELL
[[ -f "${bindings_file}" ]] && source "${bindings_file}"

export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color=fg:#839496,bg:#002b36,hl:#b58900
--color=fg+:#d33682,bg+:#073642,hl+:#DC322F
--color=info:#2aa198,prompt:#dc322f,pointer:#d33682
--color=marker:#859900,spinner:#cb4b16,header:#268bd2
'

export FZF_CTRL_T_OPTS="
--height 60%
--preview 'batcat --style=full --color=always {}'
--preview-window up,75%
"
