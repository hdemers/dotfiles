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

On a brand new Ubuntu machine, simply execute *install.sh* like so:

    curl -LsS https://raw.github.com/hdemers/dotfiles/master/install.sh | bash

The install script will install git, clone this repository and run `symlink` with
*overwrite-all* and *create-paths* options.

Adding a new vim plugin
-----------------------

Instructions to add a new vim plugin:

    cd .dotfiles
    git submodule add git://github.com/tpope/vim-fugitive.git .vim.symlink/bundle/fugitive
    git submodule init && git submodule update

To remove a plugin that was added as a git submodule (cf. this StackOverflow
[answer](http://stackoverflow.com/a/1260982)):

1. Delete the relevant section from the `.gitmodules` file.
2. Stage the .gitmodules changes `git add .gitmodules`
3. Delete the relevant section from `.git/config`.
4. Run `git rm --cached path_to_submodule` (no trailing slash).
5. Run `rm -rf .git/modules/path_to_submodule`
6. Commit `git commit -m "Removed submodule <name>"`
7. Delete the now untracked submodule files `rm -rf path_to_submodule`


Updating all vim plugins
------------------------

To update all vim plugins to their latest version, do 

    git submodule foreach git co master
    git submodule foreach git pull

then `git add` and `git commit` all submodules that were updated.
