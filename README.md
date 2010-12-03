packø - The "pacco" package manager.
====================================

packø is a package manager inspired by FreeBSD ports and Gentoo Portage which aims
to be even more flexible and easy to work with.

These environment variables are needed for testing.

    export PACKO_DATABASE=sqlite:///tmp/packo_database
    export PACKO_SELECTORS=/tmp/packo_selectors
    export PACKO_REPOSITORIES=/tmp/packo_repositories
    export PACKO_TMP=/tmp
    export PACKO_PROFILE=~/projects/distro/profiles/default
    export PACKO_VERBOSE=true

Then you can start doing some things.

    $ packo repository add git://github.com/distro/source-universe.git
    $ packo repository add https://github.com/distro/binary-universe/raw/master/core2.xml

This adds two repositories and gives you some packages.

    $ packo repository search "[library]"

This searches all packages that have library as tag.

To get more informations about packages do

    $ packo repository info "[library]"

This will give a lot of informations about the package.

You can also build packages into .pko files.

    $ packo build package fluxbox

This will build fluxbox.

To get a list of packø's environment variables just do:

    $ packo env show

Installation is nearly finished, just few things are missing.

How to install
--------------

To install packo just build the gem and install it.

    $ gem build *spec
    $ gem instlal *gem

And then install the adapter you want to use, to get a list of adapters do

    $ gem list --remote | grep "dm-.*-adapter"

Then modify the `PACKO_DATABASE` env variable and you're ready to use packo.

At this point you should install `sandbox` which is a package developed by Gentoo devs.

Common problems
---------------

*   If you get a huge error message about `sandbox` it means it tried to access some place it wasn't supposed
    to, so sandbox killed the process to prevent damages, if you're sure you wanted it to access that place configure
    `sandbox` to be able to do so.
\
    Read `sandbox`'s documentation to know how to do so.

*   If you can't install sandbox you can use packo anyway, just don't use the protected syntax (packo &lt;command&gt;) but use
    packo-&lt;command&gt; which is the not secure way.
\
    I suggest getting sandbox anyway beacause packages could do something harmful by mistake or on purpose, you can never know.
