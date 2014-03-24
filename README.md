cross-boss
==========

###### Cross-compile like a boss!

Introduction
------------

Cross-compiling is hard work. There are so many things that can go wrong, usually because of poor assumptions made by upstream developers. autotools helps but not every piece of software uses it and it still only gets us so far in any case. Many users get beaten back one too many times and eventually just put up with painfully slow builds on their target hardware or emulated environments. I have written cross-boss to take some of the pain away.

There are several projects dedicated to cross-compiling whole systems such as the Yocto Project and uClibc's buildroot. These are great projects that are likely to give you reliable results. In my mind, Gentoo stands apart from these as being a general purpose distribution that gives you the ultimate in configuration power. Having been a Gentoo user since 2003, I was not about to give up that power lightly. You are probably a Gentoo user and you probably feel the same way.

Being source-based by nature, Gentoo has great potential to be able to cross-compile systems of any kind. I have toyed with its cross-compiling capabilities on and off since 2005 and it must be said that it has come an awful long way in that time. Upstream has also improved thanks to an increased awareness brought about primarily by the rise of ARM. As a result, cross-boss went through very many rewrites with fewer and fewer ugly hacks each time. It is only now that I feel it is worthy of a release.

That's not to say it has no ugly hacks. This project exists to paper over the cracks left by troublesome software and that's never going to be pretty. Ideally all these problems would be fixed upstream but upstream is all too often slow, unresponsive, or uninterested. Gentoo does what it can to help where upstream fails us but manpower is limited and sometimes the short term solution is just too ugly to be considered for inclusion. I respect such decisions but none of this helps us when we need our systems cross-compiled today. cross-boss therefore employs the hacks that Gentoo doesn't want to or just hasn't had time to apply.

No one wants to rely on hacks forever though so I strive to report issues to Gentoo and/or upstream whenever I believe it to be approriate. Many of the files in cross-boss mention issue numbers or URLs in the hope that these issues will eventually be resolved. In fact, many fixes that were due for inclusion in cross-boss were already applied by Gentoo or upstream by the time I got around to releasing it. That is definitely a good thing.

Approach
--------

cross-boss is designed to aid in cross-building new systems from scratch, cross-building new and updated packages in existing systems, and falling back to emulated building via QEMU when all else fails. It also tries to apply fixes for uClibc targets but this is admittedly a secondary concern.

It tries to apply fixes in such a way that they will continue to work in the face of continued updates to the Portage tree. This is what sets cross-boss apart from some of the overlays you may have seen. The techniques may be ugly but I believe the end justifies the means. Overlays can only do so much and they quickly become stale if not maintained. One of the most ambitious cross-compile overlays was ambro-cross-overlay but it has not seen a single update since early 2013, making it practically useless now. My own time is very limited and it is likely that updates to cross-boss will be infrequent so these techniques really are needed.

Building new systems from scratch without a stage tarball has traditionally been difficult, let alone cross-building them. Some time ago, Gentoo's vapier came up with a bootstrap script to build Bash, Python, and Portage in order to get one started. cross-boss previously made use of this script until I realised that Portage only needed a little guidance to get things up and running by itself. Even if there is a stage tarball available for your target, building from scratch feels much more like the _Gentoo way_ and it'll allow you to build with your own flags right from the get-go.

I have all too often seen users in #gentoo-embedded attempt to cross-compile systems from scratch, only to be hit by missing libraries almost immediately. The library mentioned is frequently ncurses. Perhaps this sounds familiar? Where did they go wrong? Toolchains installed by crossdev differ from the system toolchain in that they are configured with a sysroot. The sysroot points to /usr/${CHOST} and this is used to locate libraries and headers instead of looking in / as usual. crossdev installs plenty of files in this location that would conflict if you attempt to build a new system there. Users therefore specify a different location with ROOT and herein lies the problem. The toolchain knows nothing about ROOT and so libraries installed there, such as ncurses, simply don't get found. Users then fumble about with flags like -L${ROOT}/usr/lib and -I${ROOT}/usr/include, find that this only works very sporadically, if at all, and then give up.

The good news is the toolchain sysroot can be overridden at runtime using the --sysroot flag. The bad news is that relying on CFLAGS and LDFLAGS never works. Gentoo policy dictates that all packages should honour these flags in producing the resulting binaries but ./configure generally ignores these flags when producing transient binaries for its checks. Thankfully ./configure scripts generated by recent versions of autoconf directly support the --sysroot flag, which is used throughout the build. I intend to propose to Gentoo that this flag should be set by default when appropriate. cross-boss already does this. But what about older ./configure scripts and packages that don't use autotools? The next most reliable way to enforce this flag is with wrapper scripts placed early in the PATH. cross-boss sets these up too and between these two techniques, the results are impressive.

Requirements
------------

* A working Gentoo system, preferably up to date.
* A stage 4 toolchain for your target, built with sys-devel/crossdev.
* sys-apps/proot to chroot into a target system. _(optional)_
* app-emulation/qemu to chroot into a non-native target system and cross-compile certain packages. _(optional)_
* sys-devel/distcc for a speed boost when using cb-emerge-proot. _(optional)_

Installation
------------

I don't intend to provide versioned release tarballs of cross-boss. The Portage tree is forever changing and we need to keep up with it so it only makes sense to have the very latest cross-boss code. You are therefore encouraged to clone the repository from GitHub and continue to pull updates from it whenever necessary. There is nothing to install. Simply run it in place. Hopefully this will encourage you and others to submit your own fixes to the project. It also serves as a sort of profile mechanism. You may need to use cross-boss against multiple targets and git will allow you to store configuration details such as make.conf under separate branches. If you need to modify existing cross-boss files, git will allow you to track upstream changes against your own. If you're not familiar with git then don't worry, it's not a strict requirement. Finally, the executable tools are located in the bin directory. You can add this to your PATH if you like.

Usage
-----

All of cross-boss's tools take the path to the target ROOT as the first argument.

**WARNING!** All of cross-boss's tools, except for cb-proot, copy files from the _root_ directory into the target ROOT directory, overwriting any files that already exist, including make.conf. This is done is ensure that the latest fixes are always installed. It also makes the assumption that you will almost always build using cross-boss rather than your target hardware.

### cross-boss

Builds a new system from scratch into the specified directory. It uses Portage to emerge @system in steps, specifically virtual/os-headers, virtual/libc, sys-devel/gcc, and then the rest, first without dev-lang/perl, and then with it if possible. If building fails at any point, the command can simply be run again to continue where it left off. Failure to build dev-lang/perl is not considered fatal as the only part of @system that absolutely requires it is the _man_ command.

New Gentoo installations require a little preparation and that still applies to cross-boss, as it seeks to keep the power in your capable hands. At the very least, you will need to create a make.profile symlink and make.conf file in root/etc/portage. These will automatically be copied to your target ROOT by cross-boss.

    # make.profile symlink example.
    ln -snf /usr/portage/profiles/default/linux/arm/13.0/armv7a root/etc/portage/make.profile

I won't bore you with configuring make.conf as you will have obviously done it before. You can use your existing /etc/portage/make.conf as a template. Don't forget to set ARCH and ACCEPT\_KEYWORDS values that are appropriate for your target. _man make.conf_ is always your friend. Note that using Gentoo's stable branch is not recommended. cross-boss focuses on testing/unstable packages and you'll get the latest upstream fixes from these too. I've never found unstable to be very unstable anyway!

cross-boss looks for one additional make.conf variable that is optional but may help a great deal. PORTAGE\_EMULATOR is used to start QEMU when using proot and under certain other circumstances mentioned below. It has been put forward for official inclusion in [Gentoo bug #500090](https://bugs.gentoo.org/show_bug.cgi?id=500090). Obviously you will need app-emulation/qemu installed with QEMU\_USER\_TARGETS set appropriately for your target. Enabling the _static-user_ flag is not necessary.

    # PORTAGE_EMULATOR is used by some ebuilds while cross-compiling
    #     when it is necessary to execute a target binary on the build
    #     host. This will typically point to a userspace emulator such
    #     as qemu. Please escape variables such as ${ROOT} and watch
    #     out for the sandbox as it may not work inside the ROOT.
    PORTAGE_EMULATOR="qemu-arm -L \${ROOT} -U LD_PRELOAD"

You can also apply additional Portage configuration through other files under root/etc/portage, if required. When you're ready, simply execute cross-boss as follows.

    # cross-boss invocation.
    cross-boss /path/to/root

Sit back and pray that it reaches the end. If it doesn't, check out the tips section, take any necessary steps, and try again.

### cb-emerge

A wrapper around the standard emerge command that installs packages to the specified directory. It ensures that cross-compile fixes applied to this directory are up to date and activates them before starting to build.

    # cb-emerge invocation.
    cb-emerge /path/to/root <emerge arguments>

### cb-ebuild

Similar to cb-emerge but runs ebuild instead of emerge. Useful for debugging.

    # cb-ebuild invocation.
    cb-ebuild /path/to/root <ebuild arguments>

### cb-proot

Runs the specified command in a proot-style chroot under the specified directory, using QEMU if necessary.

    # cb-proot invocation.
    cb-proot /path/to/root <command> <arguments>

### cb-emerge-proot

Similar to cb-proot but acts as a wrapper to the emerge command. Useful for those stubborn packages that simply won't cross-compile. It starts a local instance of distccd, when available, to give a much-needed speed boost.

    # cb-emerge-proot invocation.
    cb-emerge-proot /path/to/root <emerge arguments>

### cb-eselect

A wrapper around eselect that operates in the specified directory. Useful for dealing with Portage news messages.

    # cb-eselect invocation.
    cb-eselect /path/to/root <eselect arguments>

Tips
----

The practically infinite combinations of USE flags means that is is impossible to guarantee that cross-boss will work for you. I could state a list of USE flags that work for me but this would not be a very Gentoo thing to do and with constant changes to the Portage tree, there is still a good chance it would fail anyway. I will list a few things to avoid but beyond that, feel free to enable the flags that you want. You may be pleasantly surprised. Having said that, it is usually sensible when installing a new Gentoo system to start with fewer flags in order to get a working system sooner rather than later.

### In the event of failure…

It is highly likely that cross-boss will fail for you at some point. It's not a miracle solution, I'm afraid. The easiest thing to do when a package fails is to try and build it with cb-emerge-proot instead as this should theoretically always work. Being emulated, it may take a while but it'll probably still be faster than trying to figure out what went wrong. You'll be left feeling empty though as you won't be able to shake the fact that it should have worked and you'll obviously want to do all you can to help your fellow Gentoo users. ;) See _Common Problems_ and _Contributing_ below.

### Avoid Qt

I have tried to cross-compile Qt in the past with little success. I have since found a guide but have yet to try it. However, you can still build Qt using cb-emerge-proot and any Qt-enabled applications should subsequently cross-compile.

### Avoid native Python modules

Until recently, even cross-compiling Python itself was a pain. Modules without native extensions should install without issue but others will most likely build for the wrong target, if they even build at all. I have included hacks for dev-libs/gobject-introspection and sys-devel/distcc but only because the former is often required and the latter is damn useful to have. I am generally treating native modules as a lost cause until upstream gets its act together.

### Python versions

For reasons that escape me right now, it is a good idea to have the Python versions present on your target system also present on your build system. The best way to achieve this is to set PYTHON\_TARGETS and PYTHON\_SINGLE\_TARGET the same way in both versions of make.conf.

### Perl 5 modules

Perl 5 itself is supposed to cross-compile but it simply doesn't. Thankfully the perlcross project has remedied that situation. Modules are still a problem though, even non-native ones. It is doubtful that Perl 5 modules will ever cross-compile but there is a little good news. The configure phase of the ebuild typically invokes Perl. If this Perl invocation is done in a proot with QEMU then the rest of the build usually succeeds. In fact, I've never seen it fail though I know that it potentially could under certain circumstances. Please set PORTAGE\_EMULATOR if you want this to work.

### ldconfig

When not cross-compiling, Portage runs ldconfig every time a package is installed or removed. A long time ago, it used to run ldconfig unconditionally. The problem with this is that /etc/ld.so.cache is endian-sensitive so running a little-endian ldconfig for a big-endian target breaks the cache. Now it only runs ldconfig when cross-compiling if ${CHOST}-ldconfig exists; it usually doesn't. If the first time you use your target system is on your target hardware where you can run ldconfig manually then this wouldn't matter much. However, if you have intend to allow cross-boss to automatically invoke proot with QEMU via the PORTAGE\_EMULATOR variable then ld.so.cache needs to be up-to-date, otherwise most commands will simply fail to execute. For this reason, cross-boss installs ${CHOST}-ldconfig as a wrapper that calls the target ldconfig via QEMU if you have PORTAGE\_EMULATOR defined.

### gobject-introspection

gobject-introspection is a giant pain in the ass. There is even a project dedicated to cross-compiling it and even that still requires QEMU. Merely getting it to build isn't the end of the story either. It is executed at build time by many other packages and it not safe to use the build system version when cross-compiling so QEMU must be used here too. Upstream is well aware of the issues but nothing short of a rewrite is going to fix this. cross-boss automatically wraps calls to the binaries with cb-proot when both building and using gobject-instrospection but you'll need to set PORTAGE\_EMULATOR. gobject-introspection can largely be avoided if you disable the introspection USE flag but I'm not sure what effect this actually has.

### Waf

I was rather surprised to find that the Waf build system, used by the likes of Samba and XMMS2, fully supports cross-compiling. It is highly recommended, though not entirely necessary, to have PORTAGE\_EMULATOR set for this to work. See [Gentoo bug #500090](https://bugs.gentoo.org/show_bug.cgi?id=500090) for the details.

### Linux kernel

As you're probably aware, Portage doesn't build the Linux kernel for you. cross-boss doesn't either but it's really not that hard. The main step is to set ARCH with _export ARCH=foo_. When configuring the kernel, you will also need to set the cross-compiler tool prefix, otherwise known as CONFIG\_CROSS\_COMPILE. Set this to the target triplet with a - on the end, e.g. _armv7a-hardfloat-linux-gnueabi-_. Continue building as normal but you may require the kernel in uImage format, depending on your target's bootloader.

Common Problems
---------------

### libtool: install: error: relink `libfoo.la' with the above command before installing it

libtool is quite clever but this is one thing it gets very wrong. When relinking, it adds the -L/usr/lib flag, breaking the sysroot and causing the above error. Gentoo patches libtool to avoid this but only if the ebuild runs elibtoolize. Many packages suffer from this issue, including all of the gstreamer packages. I have already filed many Gentoo bugs so I am hesitant to file a whole bunch more about what is effectively a single issue. I plan to contact Gentoo developers about it on IRC once I have cross-boss out the door. cross-boss could possibly call elibtoolize by itself in the short term but this may break more than it fixes.

### /usr/lib/libfoo.so: file not recognized: File format not recognized

This is related to the above problem in that both will display this error and both come as a result of adding the -L/usr/lib flag but this isn't always caused by libtool. In other cases, the flag is often introduced by naive configure scripts and Makefiles, and as such, an upstream fix is usually preferable.

### cc1: warning: include location "/usr/include" is unsafe for cross-compilation, followed by various syntax/type errors

The above message isn't always fatal but it's certainly a bad sign. This is similar to the above problem in that adding the -I/usr/include flag breaks the sysroot. Again, this is usually introduced by naive configure scripts and Makefiles, and an upstream fix is usually preferable. If the directory mentioned is below /usr/include, such as /usr/include/xcb, then you will usually get away with it, assuming the directory even exists on your build system, but this is still not ideal.

### /var/tmp/portage/app-misc/foo-1.2.3/work/foo-1.2.3/.libs/foo: cannot execute binary file

Unfortunately many packages try to execute binaries they have just built in order to build the rest of the package. If you're lucky, these binaries are subsequently installed. In this case, EAPI 5-hdepend can be used to install the package to the build system first. If you're really lucky, the package might even allow you to specify alternative paths for these binaries via build options or environment variables. If the binaries aren't subsequently installed, they may only be used to generate documentation or run tests, in which case you may be able to skip this non-essential step when cross-compiling. Failing all that, the build scripts will probably need major surgery.

Worst of all, even using EAPI 5-hdepend is not straightforward. This experimental EAPI is not officially supported by Gentoo so none of the official eclasses support it and bug reports with fixes that involve it are automatically closed. It also cannot simply be activated though a Portage env file like many of cross-boss's fixes because EAPI is a read-only variable. cross-boss works around both of these issues through its unusual overlay but this is arguably its ugliest hack of all. You can track EAPI 5-hdepend's slow progress in [Gentoo bug #317337](https://bugs.gentoo.org/show_bug.cgi?id=317337).

### configure: error: cannot run test program while cross compiling

configure scripts perform a series of checks and tests in order to build software appropriately for your target. They try to do this without the need to execute any binaries but sometimes it is just unavoidable and if you are cross-compiling, that is when you will see the above error. Fortunately it can usually be worked around relatively easily. Each test sets a corresponding environment variable. If you set this variable in advance then configure will skip the test and use your value instead. crossdev installs a set of the most common test results under /usr/share/crossdev/include/site. These are categorised by architecture, operating system, and C library. The appropriate files are automatically sourced by /usr/share/config.site every time you run configure when cross-compiling. cross-boss includes a bunch of additional test results under scripts/config.site. These are not categorised like crossdev's scripts, primarily because I haven't got the means to test all these different combinations, but I have tried to aim for a relatively sane glibc-based or uClibc-based Linux system. If you hit the above error then locate the failing test within the configure script and make a note of its variable name. In order to determine the actual result, you will need to start the build through cb-proot-emerge or run emerge on your target hardware. Failing that, get the result from your build system instead and use your own judgement to decide whether the result is likely to be the same on your target hardware. There may also be a similarly-named variable already present in the existing result set. Once you have a result, add a corresponding line to scripts/config.site and try again. If it works, consider filing a cross-boss issue about it.

Q&A
---

### Why are users and groups added to / rather than ROOT?

This problem is not unique to cross-boss and I'm frankly quite surprised that no one has stepped up to provide a solution. The various tools such as useradd do have a -R option to specify a root directory but this performs an actual chroot, making it useless for non-native environments. Even if this somehow worked or if it were run through QEMU, it would still not be sufficient because Portage needs to know about these users and groups from the perspective of the build system.

I believe what is needed is some way to intelligently sync the accounts between / and ROOT. If a user or group already exists in / then use the same ID in ROOT. If it doesn't already exist then create it in / first, ensuring that the new ID doesn't clash with one already in ROOT. If there is an unresolvable ID clash then error out. I may look into this in the future but any help would be greatly appreciated by both me and the community. For now, you'll just have to make do with manually copying entries from / into ROOT.

### Can I emerge to / and ROOT at the same time?

This is not advisable. cross-boss uses the same _PORTAGE\_TMPDIR_ as / does so it is possible that they may trample on each other. Even if it didn't, it is still not advisable because installing packages to ROOT can also result in packages being installed to / as well.

### These hacks don't work! They're ugly as hell! You should be ashamed!

I'm sorry to hear that cross-boss has failed to meet your expectations. While these hacks are not guaranteed to work, they have been put in place for a reason. Try removing them and see how far you get. As was previously mentioned, I believe the end justifies the means.

### Why don't you become a Gentoo developer?

This has long been an ambition but life has generally got in the way. I have had commit access to java-overlay for many years but long periods go by where I do not make a single commit. Sure, I've put time into developing cross-boss but I've been under no pressure to do so. No one will kick me off the project if I leave it to rot. Even if I were a Gentoo developer, cross-compiling fixes need to be applied right across the Portage tree so I would still need permission from the appropriate maintainers. I certainly wouldn't want to become known as the guy who meddles with everyone's packages without asking.

### Is Gentoo Prefix supported?

No. I've never used it so I always get confused about when to use ROOT and when to use EROOT. I can't think of any use case where you would want to cross-compile a Gentoo Prefix system so I'm not putting any time into this. Patches welcome.

### What's in a name?

cross-boss went through several names during its creation. It was actually called cross-stage until the very last minute but it had struck me for a while that this was a very boring name and these scripts do more than that name would suggest. cross-boss may be a tad silly but then so is its author. It also rhymes with CrossDOS and that stirs up nostalgic memories of AmigaOS. That's not entirely inappropriate given that my first experience of cross-compiling involved installing Gentoo on my Amiga 1200. Maybe I'll use cross-boss to try that again some time. (-;

Contributing
------------

Please don't file an issue about package X failing to build unless it's one that cross-boss already has a fix for. I know that cross-boss cannot build every package in the tree. Fixes are appreciated but keep in mind that I am trying to keep cross-boss as lightweight as possible. If I encounter a build failure, I try and resolve it through Gentoo or upstream first. If it looks like they won't be able to resolve it in a hurry, only then do I commit a fix to cross-boss. Fixes that can applied generally across many packages and fixes that potentially continue to work against future package versions are prefered, even if they are a little uglier as a result. Fixes that break other packages are obviously to be avoided.

Author
------

James ["Chewi"](https://github.com/chewi) Le Cuirot

License
-------

cross-boss is distributed under the GNU GPLv2 with no warranty, primarily because that's what Gentoo's ebuilds use. See COPYING for more details.
