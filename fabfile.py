import os
import os.path as path
import shutil

from fabric.api import task
from fabric.operations import prompt

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
    overwrite = overwrite_all = backup = backup_all = skip_all = False
    for source, link_name in get_symlinks():
        if path.lexists(link_name):
            if not (overwrite_all or backup_all or skip_all):
                if path.islink(link_name):
                    answer = prompt("Symbolic link %r already exists.\n"
                                    "What do you want to do? "
                                    "[s]kip, [S]kip all, [o]verwrite, "
                                    "[O]verwrite all: " % link_name)
                else:
                    answer = prompt("File %r already exists.\n"
                                    "What do you want to do? "
                                    "[s]kip, [S]kip all, [o]verwrite, [O]verwrite all,"
                                    " [b]ackup, [B]ackup all: " % link_name)
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

        if not skip_all:
            os.symlink(source, link_name)
