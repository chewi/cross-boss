cross-boss
==========

###### Cross-compile like a boss!

Introduction
------------

Cross-compiling is hard work. There are so many things that can go wrong, usually because of poor assumptions made by upstream developers. autotools helps but not every piece of software uses it and it still only gets us so far in any case. Many users get beaten back one too many times and eventually just put up with painfully slow builds on their target hardware or emulated environments. I have written cross-boss to take some of the pain away.

There are several projects dedicated to cross-compiling whole systems such as the Yocto Project and uClibc's buildroot. These are great projects that are likely to give you reliable results. In my mind, Gentoo stands apart from these as being a general purpose distribution that gives you the ultimate in configuration power. Having been a Gentoo user since 2003, I was not about to give up that power lightly. You are probably a Gentoo user and you probably feel the same way.

Being source-based by nature, Gentoo has great potential to be able to cross-compile systems of any kind. I have toyed with its cross-compiling capabilities on and off since 2005 and it must be said that it has come an awful long way in that time. Upstream has also improved thanks to an increased awareness brought about primarily by the rise of ARM. As a result, cross-boss went through very many rewrites with fewer and fewer ugly hacks each time. It is only now that I feel it is worthy of a release.

That's not to say it has no ugly hacks. This project exists to paper over the cracks left by troublesome software and that's never going to be pretty. Ideally all these problems would be fixed upstream but upstream is all too often slow, unresponsive, or uninterested. Gentoo does what it can to help where upstream fails us but manpower is limited and sometimes the short term solution is just too ugly to be considered for inclusion. I respect such decisions but none of this helps us when we need our systems cross-compiled today. cross-boss therefore employs the hacks that Gentoo doesn't want to or just hasn't had time to apply.

No one wants to rely on hacks forever though so I strive to report issues to Gentoo and/or upstream whenever I believe it to be appropriate. Many of the files in cross-boss mention issue numbers or URLs in the hope that these issues will eventually be resolved. In fact, many fixes that were due for inclusion in cross-boss were already applied by Gentoo or upstream by the time I got around to releasing it. That is definitely a good thing.

Approach
--------

cross-boss is designed to aid in cross-building new systems from scratch, cross-building new and updated packages in existing systems, and falling back to emulated building via QEMU when all else fails.

It tries to apply fixes in such a way that they will continue to work in the face of continued updates to the Portage tree. This is what sets cross-boss apart from some of the overlays you may have seen. The techniques may be ugly but I believe the end justifies the means. Overlays can only do so much and they quickly become stale if not maintained. One of the most ambitious cross-compile overlays was ambro-cross-overlay but it has not seen a single update since early 2013, making it practically useless now. My own time is very limited and it is likely that updates to cross-boss will be infrequent so these techniques really are needed.

Building new systems from scratch without a stage tarball has traditionally been difficult, let alone cross-building them. Some time ago, Gentoo's vapier came up with a bootstrap script to build Bash, Python, and Portage in order to get one started. cross-boss previously made use of this script until I realised that Portage only needed a little guidance to get things up and running by itself. Even if there is a stage tarball available for your target, building from scratch feels much more like the _Gentoo way_ and it'll allow you to build with your own flags right from the get-go.

I have all too often seen users in #gentoo-embedded attempt to cross-compile systems from scratch, only to be hit by missing libraries almost immediately. The library mentioned is frequently ncurses. Perhaps this sounds familiar? Where did they go wrong? Toolchains installed by crossdev differ from the system toolchain in that they are configured with a sysroot. The sysroot points to `/usr/${CHOST}` and this is used to locate libraries and headers instead of looking in / as usual. crossdev installs plenty of files in this location that would conflict if you attempt to build a new system there. Users therefore specify a different location with ROOT and herein lies the problem. The toolchain knows nothing about ROOT and so libraries installed there, such as ncurses, simply don't get found. Users then fumble about with flags like `-L${ROOT}/usr/lib` and `-I${ROOT}/usr/include`, find that this only works very sporadically, if at all, and then give up.

The toolchain sysroot can be overridden at runtime using the `--sysroot` flag. The bad news is that relying on `CFLAGS` and `LDFLAGS` never works. Gentoo policy dictates that all packages should honour these flags in producing the resulting binaries but `./configure` generally ignores these flags when producing transient binaries for its checks. The good news is that injecting `--sysroot` via `CC`, `CXX`, and `CPP` instead is very reliable so that's what cross-boss does.

Requirements
------------

* A working Gentoo system, preferably up to date.
* A stage 4 toolchain for your target, built with sys-devel/crossdev.
* sys-apps/bubblewrap to run ldconfig and chroot into a target system.
* app-emulation/qemu to chroot into a non-native target system and cross-compile certain packages. _(optional)_
* sys-devel/distcc for a speed boost when using `cb-bwrap`. _(optional)_

Installation
------------

I don't intend to provide versioned release tarballs of cross-boss. The Portage tree is forever changing and we need to keep up with it so it only makes sense to have the very latest cross-boss code. You are therefore encouraged to clone the repository from GitHub and continue to pull updates from it whenever necessary. There is nothing to install. Simply run it in place. Hopefully this will encourage you and others to submit your own fixes to the project. The executable tools are located in the bin directory. You can add this to your `PATH` if you like.

If you want to leverage QEMU, you need to start the `qemu-binfmt` service that is installed with it. This can be set to start at boot.

Usage
-----

All of cross-boss's tools take the path to the target ROOT as the first argument.

### cb-bootstrap

Builds a new system from scratch into the specified directory. It uses Portage to emerge @system in steps, specifically virtual/os-headers, virtual/libc, sys-devel/gcc, and then the rest. If building fails at any point, the command can simply be run again to continue where it left off.

New Gentoo installations require a little preparation and that still applies to cross-boss, as it seeks to keep the power in your capable hands. At the very least, you will need to create a make.profile symlink in your target ROOT under /etc/portage.

    # make.profile symlink example.
    mkdir -p /path/to/root/etc/portage
    ln -snf /usr/portage/profiles/default/linux/arm/13.0/armv7a /path/to/root/etc/portage/make.profile

I won't bore you with configuring make.conf as you will have obviously done it before. You can use your existing /etc/portage/make.conf as a template. Don't forget to set ARCH and ACCEPT\_KEYWORDS values that are appropriate for your target. `man make.conf` is always your friend. Note that using Gentoo's stable branch is not recommended. cross-boss focuses on testing/unstable packages and you'll get the latest upstream fixes from these too.

You can also apply additional Portage configuration through other files under `/path/to/root/etc/portage`, if required. When you're ready, simply execute `cb-bootstrap` as follows.

    # cb-bootstrap invocation.
    cb-bootstrap /path/to/root

Sit back and pray that it reaches the end. If it doesn't, check out the tips section, take any necessary steps, and try again.

### cb-emerge

A wrapper around the standard emerge command that installs packages to the specified directory. It ensures that cross-compile fixes applied to this directory are up to date and activates them before starting to build.

    # cb-emerge invocation.
    cb-emerge /path/to/root <emerge arguments>

### cb-ebuild

Similar to cb-emerge but runs ebuild instead of emerge. Useful for debugging.

    # cb-ebuild invocation.
    cb-ebuild /path/to/root <ebuild arguments>

### cb-bwrap

Runs the specified command in a namespaced chroot under the specified directory, using QEMU if necessary.

    # cb-bwrap invocation.
    cb-bwrap /path/to/root <command> <arguments>

### cb-eselect

A wrapper around eselect that operates in the specified directory. Useful for dealing with Portage news messages.

    # cb-eselect invocation.
    cb-eselect /path/to/root <eselect arguments>

Tips
----

The practically infinite combinations of USE flags means that is is impossible to guarantee that cross-boss will work for you. I could state a list of USE flags that work for me but this would not be a very Gentoo thing to do and with constant changes to the Portage tree, there is still a good chance it would fail anyway. I will list a few things to avoid but beyond that, feel free to enable the flags that you want. You may be pleasantly surprised. Having said that, it is usually sensible when installing a new Gentoo system to start with fewer flags in order to get a working system sooner rather than later.

### In the event of failure…

It is highly likely that cross-boss will fail for you at some point. It's not a miracle solution, I'm afraid. The easiest thing to do when a package fails is to try and build it via `cb-bwrap` instead as this should theoretically always work. Being emulated, it may take a while but it'll probably still be faster than trying to figure out what went wrong. You'll be left feeling empty though as you won't be able to shake the fact that it should have worked and you'll obviously want to do all you can to help your fellow Gentoo users. ;) See _Common Problems_ and _Contributing_ below.

### Avoid Qt

I have tried to cross-compile Qt in the past with little success. I have since found a guide but have yet to try it. However, you can still build Qt via `cb-bwrap` and any Qt-enabled applications should subsequently cross-compile.

### Avoid native Python modules

Until recently, even cross-compiling Python itself was a pain. Modules without native extensions should install without issue but others will most likely build for the wrong target, if they even build at all. I have included hacks for dev-libs/gobject-introspection and sys-devel/distcc but only because the former is often required and the latter is damn useful to have. I am generally treating native modules as a lost cause until upstream gets its act together.

### Python versions

For reasons that escape me right now, it is a good idea to have the Python versions present on your target system also present on your build system. The best way to achieve this is to set `PYTHON_TARGETS` and `PYTHON_SINGLE_TARGET` the same way in both versions of make.conf.

### ldconfig

When not cross-compiling, Portage runs `ldconfig` every time a package is installed or removed. A long time ago, it used to run `ldconfig` unconditionally. The problem with this is that `/etc/ld.so.cache` is endian-sensitive so running a little-endian `ldconfig` for a big-endian target breaks the cache. Now it only runs `ldconfig` when cross-compiling if `${CHOST}-ldconfig` exists; it usually doesn't. For this reason, cross-boss creates `${CHOST}-ldconfig` as a wrapper that calls the target ldconfig via bwrap and QEMU if you have them available.

Common Problems
---------------

### libtool: install: error: relink `libfoo.la' with the above command before installing it

libtool is quite clever but this is one thing it gets very wrong. When relinking, it adds the `-L/usr/lib` flag, breaking the sysroot and causing the above error. Gentoo patches libtool to avoid this but only if the ebuild runs `elibtoolize`. Many packages suffer from this issue, including all of the gstreamer packages. I have already filed many Gentoo bugs so I am hesitant to file a whole bunch more about what is effectively a single issue. I plan to contact Gentoo developers about it on IRC once I have cross-boss out the door. cross-boss could possibly call `elibtoolize` by itself in the short term but this may break more than it fixes.

### /usr/lib/libfoo.so: file not recognized: File format not recognized

This is related to the above problem in that both will display this error and both come as a result of adding the `-L/usr/lib` flag but this isn't always caused by libtool. In other cases, the flag is often introduced by naive configure scripts and Makefiles, and as such, an upstream fix is usually preferable.

### cc1: warning: include location "/usr/include" is unsafe for cross-compilation, followed by various syntax/type errors

The above message isn't always fatal but it's certainly a bad sign. This is similar to the above problem in that adding the `-I/usr/include` flag breaks the sysroot. Again, this is usually introduced by naive configure scripts and Makefiles, and an upstream fix is usually preferable. If the directory mentioned is below `/usr/include`, such as `/usr/include/xcb`, then you will usually get away with it, assuming the directory even exists on your build system, but this is still not ideal.

### /var/tmp/portage/app-misc/foo-1.2.3/work/foo-1.2.3/.libs/foo: cannot execute binary file

Unfortunately, many packages try to execute binaries they have just built in order to build the rest of the package. Sometimes the package can be modified to build this binary for the build system instead. This can be awkward though, as sometimes the binary also needs to be built for the target system, and sometimes it is complex enough to require an entirely separate build tree and configuration.

Before it was removed from Portage, EAPI 5-hdepend would allow a package to depend on itself, but for the build system instead of the target system. This only worked when the package actually installed the binary concerned, which is often not the case. There is currently no plan to restore this feature to Portage. In cases like this, such as sys-devel/clang, we check for the presence on the build system binary at build time and error out if it's missing.

### configure: error: cannot run test program while cross compiling

configure scripts perform a series of checks and tests in order to build software appropriately for your target. They try to do this without the need to execute any binaries but sometimes it is just unavoidable and if you are cross-compiling, that is when you will see the above error. Fortunately it can usually be worked around relatively easily. Each test sets a corresponding environment variable. If you set this variable in advance then configure will skip the test and use your value instead. crossdev installs a set of the most common test results under /usr/share/crossdev/include/site. These are categorised by architecture, operating system, and C library. The appropriate files are automatically sourced by /usr/share/config.site every time you run configure when cross-compiling. cross-boss includes a bunch of additional test results under scripts/config.site. These are not categorised like crossdev's scripts, primarily because I haven't got the means to test all these different combinations, but I have tried to aim for a relatively sane glibc-based or musl-based Linux system. If you hit the above error then locate the failing test within the configure script and make a note of its variable name. In order to determine the actual result, you will need to start the build via `cb-bwrap` or run emerge on your target hardware. Failing that, get the result from your build system instead and use your own judgement to decide whether the result is likely to be the same on your target hardware. There may also be a similarly-named variable already present in the existing result set. Once you have a result, add a corresponding line to scripts/config.site and try again. If it works, consider filing a cross-boss issue about it.

### libtool: Version mismatch error…

This happens when elibtoolize is called but the version of libtool in / doesn't match that in ROOT. Simply update them to the same version and you'll be on your way again.

Q&A
---

### Can I emerge to / and ROOT at the same time?

This is not advisable. cross-boss uses the same `PORTAGE_TMPDIR` as / does so it is possible that they may trample on each other. Even if it didn't, it is still not advisable because installing packages to ROOT can also result in packages being installed to / as well.

### These hacks don't work!

I'm sorry to hear that cross-boss has failed to meet your expectations. While these hacks are not guaranteed to work, they have been put in place for a reason. Try removing them and see how far you get. As was previously mentioned, I believe the end justifies the means.

### Aren't you a Gentoo developer? Why not fix things in the distribution?

Yes, I've been a Gentoo developer for a while, and I've tried to fix as much as possible in the distribution since then. cross-boss is just a home for the uglier hacks and the additional glue to make the process easier.

### Is building with Clang supported?

Yes! Just set `CPP="clang -E" CC="clang" CXX="clang++"` whenever you call any of the cross-boss commands. You still need a crossdev toolchain with GCC though. Other flags are normally needed to make this work, but cross-boss adds these for you.

### Is Gentoo Prefix supported?

Yes, standalone prefix (aka RAP) is supported! It's an additional layer of complexity, so considerable effort was needed to make it work, but I got there eventually. This is great for building Gentoo for your phone, as doing this the usual way would be very slow and heavy on your device. Just use an appropriate prefix profile, and set `EPREFIX` whenever you call any of the cross-boss commands.

### What's in a name?

cross-boss went through several names during its creation. It was actually called cross-stage until the very last minute but it had struck me for a while that this was a very boring name and these scripts do more than that name would suggest. cross-boss may be a tad silly but then so is its author. It also rhymes with CrossDOS and that stirs up nostalgic memories of AmigaOS. That's not entirely inappropriate given that my first experience of cross-compiling involved installing Gentoo on my Amiga 1200. Maybe I'll use cross-boss to try that again some time. (-;

Contributing
------------

Please don't file an issue about package X failing to build unless it's one that cross-boss already has a fix for. I know that cross-boss cannot build every package in the tree. Fixes are appreciated but keep in mind that I am trying to keep cross-boss as lightweight as possible. If I encounter a build failure, I try and resolve it through Gentoo or upstream first. If it looks like they won't be able to resolve it in a hurry, only then do I commit a fix to cross-boss. Fixes that can applied generally across many packages and fixes that potentially continue to work against future package versions are preferred, even if they are a little uglier as a result. Fixes that break other packages are obviously to be avoided.

Author
------

James ["Chewi"](https://github.com/chewi) Le Cuirot

License
-------

cross-boss is distributed under the GNU GPLv2 with no warranty, primarily because that's what Gentoo's ebuilds use. See COPYING for more details.
