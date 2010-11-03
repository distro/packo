packø - The "pacco" package manager.
====================================

packø is a package manager inspired by FreeBSD ports and Gentoo Portage which aims
to be even more flexible and easy to work with.

Some stuff has been done.

    $ export PACKO_CACHE=/where/you/want/the/cache # this has to be a file, not a directory
    $ export PACKO_PROFILE=/where/you/have/your/profile # if you downloaded organo/tree it's organo/tree/profiles/default

Then you can start doing some things.

    $ packo cache /path/to/organo/tree

This creates the cache, it's an sqlite database with all the packages in all the trees.

Once you have a cache you can do some other stuff, like searching.

    $ packo search x11/

This searches all packages that have x11 in their category.

You can also build packages into .pko files.

    $ packo build fluxbox

This will build fluxbox.

Installation hasn't been implemented yet, but we need just build functions for now.

I'm going to focus on improving *cache* and *build*.
