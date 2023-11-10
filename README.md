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
