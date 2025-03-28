# vim: filetype=bash

# Support of ls and also add handy aliases
# Dircolors from https://github.com/seebi/dircolors-solarized
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval \
        "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"

    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'
fi

# ugrep for grep
if [ "$(command -v ug)" ]; then
    alias grep='ug'
    alias egrep='ug -E'
    alias fgrep='ug -F'
    alias xzgrep='ug -z'
    alias xzegrep='ug -zE'
    alias xzfgrep='ug -zF'
fi


# Some more ls aliases
alias ll='ls -alFrth'
alias la='ls -A'
alias l='ls -CF'

# If exa is installed, use it instead of ls
if command -v exa &> /dev/null
then
    alias ls='exa'
    alias ll='exa -l --git -s time'
    alias la='exa -la --git -s time'
    alias l='exa -l --git -s time'
    alias lg='exa -Tl --git --git-ignore -s time'
fi

if [ "$(command -v eza)" ]; then
    alias ll='eza -la --git --icons=auto --sort newest'
    alias l.='eza -d .*'
    alias ls='eza'
    alias l1='eza -1'
    alias lt='eza -lT --git --icons=auto'
fi


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
alias mounts3="s3fs ca-hdemers $HOME/S3/ca-hdemers/ -o profile=s3-access"

# Pip related
alias lspip="uv pip list --disable-pip-version-check | fzf --header-lines=2"

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
    --height 70% \
    --preview='git show --stat --color=always \$(echo {} | $FZF_GREP_COMMIT_SHA)' \
    --preview-window=wrap,top \
    --bind='enter:execute(echo {} | $FZF_GREP_COMMIT_SHA)+abort' \
    --bind='ctrl-p:preview(git show --color=always \$(echo {} | $FZF_GREP_COMMIT_SHA))' \
    --bind='ctrl-o:preview(git show --stat --color=always \$(echo {} | $FZF_GREP_COMMIT_SHA))' \
    --bind='ctrl-i:reload($FZF_GIT_LOG_GRAPH_ALL)' \
    --bind='ctrl-u:reload($FZF_GIT_LOG_GRAPH)' \
    --bind='ctrl-s:preview($FZF_GIT_JIRA_TICKET_NUMBER \
        | grep -oE \"[A-Z]+-[0-9]+\" \
        | xargs -I % jira describe %)'"

alias ghp="gh search prs --state=open --review-requested=@me"

alias ah="atuin history list --reverse false --format '{time} \t {duration} \t {command}' \
      | tspin \
      | fzf -d '|' --bind 'enter:execute(echo {3})+abort' --ansi --delimiter='\t'"

alias et='aws ec2 describe-instance-types --output=json | jq -r ".InstanceTypes[] | [(.InstanceType | tostring), (.ProcessorInfo.SupportedArchitectures | join(\"/\")), (.VCpuInfo.DefaultVCpus | tostring), (.VCpuInfo.DefaultCores | tostring), ((.MemoryInfo.SizeInMiB / 1024) | tostring)] | join(\",\")" | column -t -s, -N InstanceType,Arch,VCpus,Cores,MemoryInGB | fzf --header-lines=1'
