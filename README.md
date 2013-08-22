My dotfiles
===========

Yes, they are.

#### Why another symlinker script

I simply wanted to symlink a deeply buried directory. For example, the
_applications_ directory resides in _.local/share/_. I wanted _applications_ to
be a symlink, but not its two parents.

Installation instructions
-------------------------

In the _dotfile_ directory do: 

    ./symlink
    
Nothing will be overwritten without permission. You will be asked:

    What do you want to do? [s]kip, [S]kip all, [o]verwrite, [O]verwrite all.

On a brand new Ubuntu machine, simply source *install.sh* like so:

    wget https://raw.github.com/hdemers/dotfiles/master/install.sh ; source install.sh

The install script will install git, clone this repository and run `symlink` with
*overwrite-all* and *create-paths* options.

Adding a new vim plugin
-----------------------

Instructions to add a new vim plugin:

    cd .dotfiles
    git submodule add git://github.com/tpope/vim-fugitive.git .vim.symlink/bundle/fugitive
    git submodule init && git submodule update

To remove a plugin that was added as a git submodule, see this StackOverflow
[answer](http://stackoverflow.com/a/1260982).
