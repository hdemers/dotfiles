# vim: filetype=bash

# Support of ls and also add handy aliases
# Dircolors from https://github.com/seebi/dircolors-solarized
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval \
        "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"

    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Some more ls aliases
alias ll='ls -alFrth'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send -i \
    "$([ $? = 0 ] && echo terminal || echo error)" \
    "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias ncal="ncal -My"
alias cal="ncal -Myb"

# Coding related aliases
alias pytest="pytest --tb=short"
alias pupytest="pytest --pdbcls pudb.debugger:Debugger --pdb --capture=no"
alias gentags="ctags --exclude=build -R"
alias docker_cleanup='docker rm $(docker ps -qa -f status=exited)'

# SSH aliases
alias ssh_socks="ssh -D 8157"
alias sshnohost="ssh -A -o StrictHostKeyChecking=no"

# Jupyter aliases
alias themejupyter="jt -t gruvboxl -vim -dfs 10 -fs 10"
alias colab="jupyter notebook \
    --NotebookApp.allow_origin='https://colab.research.google.com' \
    --port=8888 \
    --NotebookApp.port_retries=0"

# Time a bash command
alias statit="/usr/bin/time -f \
    '\n%M max rss\n%K avg total\n%E real\n%U user\n%S sys' $2"

# Alias batcat to more and bat.
if command -v batcat &> /dev/null
then
    alias bat=batcat
    alias more=batcat
elif command -v bat &> /dev/null
then
    alias more=bat
fi

# Mount my S3 bucket
alias mounts3="s3fs ca-hdemers /home/hdemers/S3/ca-hdemers/ -o profile=s3-access"

# Pip related
alias lspip="pip list --disable-pip-version-check | fzf"

alias statit="/usr/bin/time -f '\n%M max rss\n%K avg total\n%E real\n%U user\n%S sys' $2"

# List all YARN nodes on a cluster.
alias nodes="yarn node -list -all |
    grep RUNNING |
    cut -d ' ' -f 1 |
    tr - . |
    grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'"

# Create temporary virtualenvs.
alias te7="mktmpenv --no-cd --python=python3.7"
alias te8="mktmpenv --no-cd --python=python3.8"
alias te9="mktmpenv --no-cd --python=python3.9"
alias te10="mktmpenv --no-cd --python=python3.10"

# Alias fdfind to fd
alias fd=fdfind

# Git + Jira + fzf = 🚀
FZF_GREP_COMMIT_SHA="grep -oE \"[a-f0-9]+[ ]*$\""
FZF_GIT_LOG_GRAPH="git log \
    --color=always \
    --graph \
    --pretty=format:\"%C(yellow)%d%Creset %s %C(magenta)(%cr) %C(blue)[%an]%Creset %Cgreen%h%Creset\" \
    --abbrev-commit \
    --date=relative"
FZF_GIT_LOG_GRAPH_ALL="$FZF_GIT_LOG_GRAPH --branches --remotes"
FZF_GIT_JIRA_TICKET_NUMBER="git show \
    --quiet \
    --pretty=format:\"%s %b\" \
    \$(echo {} | $FZF_GREP_COMMIT_SHA)"
alias gf="$FZF_GIT_LOG_GRAPH | fzf \
    --ansi \
    --reverse \
    --preview='git show --stat --color=always \$(echo {} | $FZF_GREP_COMMIT_SHA)' \
    --preview-window=wrap \
    --bind='enter:execute(echo {} | $FZF_GREP_COMMIT_SHA)+abort' \
    --bind='ctrl-p:preview(git show --color=always \$(echo {} | $FZF_GREP_COMMIT_SHA))' \
    --bind='ctrl-o:preview(git show --stat --color=always \$(echo {} | $FZF_GREP_COMMIT_SHA))' \
    --bind='ctrl-i:reload($FZF_GIT_LOG_GRAPH_ALL)' \
    --bind='ctrl-u:reload($FZF_GIT_LOG_GRAPH)' \
    --bind='ctrl-s:preview($FZF_GIT_JIRA_TICKET_NUMBER \
        | grep -oE \"[A-Z]+-[0-9]+\" \
        | xargs -I % jira issue view --comments 100 %)'"

# Git branches + FZF = 🚀
alias gb="git rb \
    | fzf --ansi --header-lines=1 \
      --bind 'enter:execute(echo {1})+abort' \
      --bind 'ctrl-e:execute-silent(git br -D {1})+reload(git rb)' \
      --bind 'ctrl-r:reload(git rba)' \
      --preview='GH_FORCE_TTY=\"100%\" gh pr view --comments \$(echo {1} | tr -d \"*\") || \
          git show --stat --color=always \$(echo {1} | tr -d \"*\")' \
      --preview-window=top,75% \
    | tr -d '*' \
    | xargs --no-run-if-empty git sw"


