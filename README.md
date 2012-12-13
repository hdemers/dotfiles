My dotfiles
===========

Yes, they are.

#### Why another symlinker script

I simply wanted to symlink a deeply buried directory. For example, the
_applications_ directory resides in _.local/share/_. I wanted _applications_ to
be a symlink, but not its two parents.

Installation instructions
-------------------------

You need fabric to run the symlinker script. In the _dotfile_ directory do: 

    fab symlink
    
Nothing will be overwritten without permission. You will be asked:

    What do you want to do? [s]kip, [S]kip all, [o]verwrite, [O]verwrite all.

On a brand new machine, one without `pip`, `virtualenv`, `virtualenvwrapper`
and `fabric` installed in the `default` virtualenv, simply do:

    sudo apt-get install python-pip python-dev
    sudo pip install virtualenvwrapper
    export WORKON_HOME=$HOME/.virtualenvs
    mkdir $HOME/.virtualenvs
    source /usr/local/bin/virtualenvwrapper.sh
    mkvirtualenv default
    pip install fabric
    fab symlink

Why all this? I like having a default virtualenv to play around with and a
minimal system python installation. Thus, I install `fabric` in the _default_
virtualenv.

Adding a new vim plugin
-----------------------

Instructions to add a new vim plugin:

    cd .dotfiles
    git submodule add git://github.com/tpope/vim-fugitive.git .vim.symlink/bundle/fugitive
    git submodule init && git submodule update

To remove a plugin that was added as a git submodule, see this StackOverflow
[answer](http://stackoverflow.com/a/1260982).
