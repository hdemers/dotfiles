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
else
    alias more=bat
fi

# Mount my S3 bucket
alias mounts3="s3fs ca-hdemers /home/hdemers/S3/ca-hdemers/ -o profile=s3-access"

# Pip related
alias lspip="pip list --disable-pip-version-check | fzf"
