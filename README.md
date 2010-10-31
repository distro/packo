packø - The "pacco" package manager.
====================================

packø is a package manager inspired by FreeBSD ports and Gentoo Portage which aims
to be even more flexible and easy to work with.

Some stuff has been done.

    $ packo cache -T /path/to/organo/tree -c /where/you/want/the/cache
    $ packo build -c /where/you/want/the/cache fluxbox

This should build fluxbox.

Installation hasn't been implemented yet, but we need just build functions for now.

I'm going to focus on improving *cache* and *build*.
