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

To install packo just clone the repo, build the gem and install it.

    $ git clone git://github.com/distro/packo.git
    $ gem build packo/*spec
    $ gem install packo/*gem

And then install the adapter you want to use, to get a list of adapters do

    $ gem list --remote | grep "dm-.*-adapter"

Then modify the `PACKO_DATABASE` env variable and you're ready to use packo.

At this point you should install `sandbox` which is a package developed by Gentoo devs.

Common problems
---------------

*   If you get a huge error message about `sandbox` it means it tried to access some place it wasn't supposed
    to, so sandbox killed the process to prevent damages, if you're sure you wanted it to access that place configure
    `sandbox` to be able to do so. Read `sandbox`'s documentation to know how to do so.

*   If you can't install sandbox you can use packo anyway, just don't use the protected syntax (packo &lt;command&gt;) but use
    packo-&lt;command&gt; which is the not secure way. I suggest getting sandbox anyway beacause packages could do something harmful by mistake or on purpose, you can never know.

It's slow as hell :(
--------------------

Actually it isn't, it's slow at starting because it has to require lot of stuff and the models have to be checked when required,
so majority of the time is spent there. I'll probably implement a server/client thingy to speed things up.

Installation isn't slow, sqlite is slow at changing data in the db, so choose another adapter and you'll get it fast, remember
that sqlite is fast at selecting, so searches of packages/files/whatever will be fast and updates/installations will be slow,
choose the adapter that better suits your needs.
