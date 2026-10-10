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

Zsh / Zellij command-block browsing
-----------------------------------

The bindings live in `.zshrc.symlink` and
`.config/zellij.symlink/config.kdl`; no separate home-directory script is needed.
Start a new Zsh shell after updating. Zellij reloads its configuration automatically.

At a Zsh prompt inside Zellij:

1. Press `Esc` to enter Zsh vi-command mode.
2. Press `K` or `J` to enter Zellij scroll mode (this first press does not navigate).
3. Press `K` / `J` to highlight older / newer command blocks.
4. Press `y` to copy the selection and return to the prompt, or `q` to cancel.

The pending command line and Zsh vi mode are preserved; `i` resumes editing.
Outside browsing, `y` retains its usual Zsh behavior. Shells outside Zellij keep
ordinary `J` / `K` bindings. Browsing requires OSC 133 shell integration and retained
scrollback: navigation is relative to the top of the viewport, not the shell cursor.
The selection uses Zellij's command-block boundaries, not an output-only filter.

To copy only the latest command's output directly, press `Alt+y` in Zellij's
locked or normal mode. No browsing or Zsh vi-mode switch is required.
