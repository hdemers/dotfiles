# vim: filetype=bash

# Activate startship. In case starship is not available, the previous prompt
# setting code will be used instead.
if command -v starship &> /dev/null; then
    eval "$(starship init $CURRENT_SHELL)"
else
    # Configure colors, if available.
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        c_reset='\[\e[0m\]'
        c_user='\[\e[0;34m\]'
        c_path='\[\e[0;93m\]'
        c_git_clean='\[\e[0;36m\]'
        c_git_dirty='\[\e[0;35m\]'
        c_git_master_clean='\[\e[0;33m\]'
        c_git_master_dirty='\[\e[0;31m\]'
        c_virtualenv='\[\e[0;95m\]'
    else
        c_reset=
        c_user=
        c_path=
        c_git_clean=
        c_git_dirty=
    fi

    # Function to assemble the Git part of our prompt. cf.
    # http://vvv.tobiassjosten.net/git/add-current-git-branch-to-your-bash-prompt
    git_prompt ()
    {
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            return 0
        fi

        local git_branch="`git branch 2>/dev/null | egrep '^\*' | sed 's/^\* //'`"

        if [ "$git_branch" = "master" ]; then
            if git diff --quiet 2>/dev/null >&2; then
                git_color="$c_git_master_clean"
            else
                git_color="$c_git_master_dirty"
            fi
        elif [ "$git_branch" = "(no branch)" ]; then
            git_color="$c_git_master_dirty"
        elif git diff --quiet 2>/dev/null >&2; then
            git_color="$c_git_clean"
        else
            git_color="$c_git_dirty"
        fi

        echo "$git_color$git_branch${c_reset} "
    }

    # Function to assemble the virtualenv part of our prompt.
    virtualenv_prompt ()
    {
        if [ x$VIRTUAL_ENV != x ]; then
            # Using color codes directly here messes-up the line when its too long.
            echo "$c_virtualenv`basename "${VIRTUAL_ENV}"`$c_reset "
        fi
    }

    # Set-up the prompt.
    if [[ $CURRENT_SHELL = "bash" ]]; then
        if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
            # Inspired from: http://vvv.tobiassjosten.net/bash/dynamic-prompt-with-git-and-ansi-colors
            #PROMPT_COMMAND='PS1="$(virtualenv_prompt)${c_user}\u@\h${c_reset}:${c_path}\w${c_reset}$(git_prompt)\$ "'
            PROMPT_COMMAND='PS1="$(virtualenv_prompt)$(git_prompt)${c_user}\h${c_reset}:${c_path}\w${c_reset}\$ "'
        fi
    fi
fi
