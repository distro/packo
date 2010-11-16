packø - The "pacco" package manager.
====================================

packø is a package manager inspired by FreeBSD ports and Gentoo Portage which aims
to be even more flexible and easy to work with.

These environment variables are needed for testing.

    export PACKO_CACHE=/tmp/packo_cache
    export PACKO_BUILD_CACHE=/tmp/packo_build
    export PACKO_SELECTOR_CACHE=/tmp/packo_select
    export PACKO_SELECTOR_MODULES=/tmp/packo_selectors
    export PACKO_REPOSITORY_DIRECTORY=/tmp/packo_repositories
    export PACKO_REPOSITORY_CACHE=/tmp/packo_repository
    export PACKO_BINARY_CACHE=/tmp/packo_binary
    export PACKO_SOURCE_CACHE=/tmp/packo_source
    export PACKO_TMP=/tmp
    export PACKO_PROFILE=~/projects/packo/profiles/default
    export PACKO_VERBOSE=true

Then you can start doing some things.

    $ packo repository add git://github.com/organo/source
    $ packo repository add https://github.com/organo/binary/raw/master/core2.xml

This adds two repositories and gives you some packages.

    $ packo repository search x11/

This searches all packages that have x11 in their category.

To get more informations about packages do

    $ packo repository info x11/

This will give a lot of informations about the package.

You can also build packages into .pko files.

    $ packo build package fluxbox

This will build fluxbox.

To get a list of packø's environment variables just do:

    $ packo env show

Installation is nearly finished, just few things are missing.
