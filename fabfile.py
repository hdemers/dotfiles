import os
import os.path as path
import shutil

from fabric.api import task
from fabric.operations import prompt
from fabric.utils import error
from fabric.colors import yellow, blue, red
from fabric.contrib.console import confirm

BASE_DIR = "."

def get_symlinks():
    symlinks = []
    for dirpath, dirnames, filenames in os.walk(BASE_DIR):
        link_name = path.normpath(path.expanduser(path.join("~", dirpath)))
        source = path.abspath(dirpath)

        if ".git" in dirnames:
            del dirnames[dirnames.index(".git")]

        for name in filenames + dirnames:
            root, ext = path.splitext(name)
            if ext == ".symlink":
                symlinks.append((path.join(source, name), 
                                 path.join(link_name, root)))
    return symlinks


@task
def symlink():
    overwrite_all = backup_all = skip_all = False
    for source, link_name in get_symlinks():
        overwrite = backup = False
        dirname = path.dirname(link_name)

        if path.lexists(link_name):
            if not (overwrite_all or backup_all or skip_all):
                if path.islink(link_name):
                    answer = prompt(blue("Symbolic link %r already exists.\n"
                                    "What do you want to do? "
                                    "[s]kip, [S]kip all, [o]verwrite, "
                                    "[O]verwrite all: " % link_name))
                else:
                    answer = prompt(blue("File %r already exists.\n"
                                    "What do you want to do? "
                                    "[s]kip, [S]kip all, [o]verwrite, [O]verwrite all,"
                                    " [b]ackup, [B]ackup all: " % link_name))
                if answer == 'O':
                    overwrite_all = True
                elif answer == 'o':
                    overwrite = True
                elif answer == 'B':
                    backup_all = True
                elif answer == 'b':
                    backup = True
                elif answer == 'S':
                    skip_all = True
                elif answer == 's':
                    continue
                else:
                    return

            if backup or backup_all:
                os.rename(link_name, "%s.backup" % link_name)
            if overwrite or overwrite_all:
                try:
                    os.remove(link_name)
                except OSError:
                    shutil.rmtree(link_name)

        elif not path.exists(dirname):
            if confirm(blue("Path {!r} does not exists. Create?".format(
                dirname))):
                os.makedirs(dirname)
            else:
                print(yellow("Skipping {!r}".format(link_name)))
                continue

        if not skip_all:
            try:
                os.symlink(source, link_name)
            except Exception, exception:
                print(red("Exception {} for {!r}".format(exception,
                                                         link_name)))
                error(red("An error occured while symlinking {!r}".format(
                    link_name)))
