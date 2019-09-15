# Not everyone uses 022.
umask 022

export-env() {
	export \
		CBFLAGS \
		CONFIG_SITE \
		CROSS_CMD \
		DISTDIR \
		MAKEOPTS \
		PORTAGE_CONFIGROOT \
		PORTAGE_TMPDIR \
		PORTDIR \
		ROOT
}

set-toolchain() {
	export \
		CPP="${OLD_CPP} ${CBFLAGS}" \
		CC="${OLD_CC} ${CBFLAGS}" \
		CXX="${OLD_CXX} ${CBFLAGS}"
}

set-sysroot() {
	CBFLAGS+="${CBFLAGS:+ }--sysroot=${ESYSROOT}"
	set-toolchain

	export \
		PATH=${PREROOTPATH}:${PATH} \
		PREROOTPATH \
		SYSROOT
}

cross-emerge() {
	# Unfortunately, overlays can't have NFS layers.
	case "$(stat -f -c %T "${EROOT}"/etc/portage)" in
	nfs)
		"${HOST}-emerge" "${@}" ;;
	*)
		mkdir -p "${EROOT}"/mnt/workdir || exit $?
		unshare --mount sh -c "
			mount -t overlay -o 'lowerdir=${CROSS_BOSS}/root/etc/portage,upperdir=${EROOT}/etc/portage,workdir=${EROOT}/mnt/workdir' overlay '${EROOT}'/etc/portage || exit 1
			exec '${HOST}-emerge' \"\${@}\"
		" - "${@}" ;;
	esac
}

host_portageq() {
	env -u ROOT -u SYSROOT -u PORTAGE_CONFIGROOT -u EPREFIX portageq "${@}" 2>/dev/null
}

root_portageq() {
	ROOT=${ROOT} SYSROOT=${SYSROOT} PORTAGE_CONFIGROOT=${PORTAGE_CONFIGROOT} portageq "${@}" 2>/dev/null
}

ABI=$(host_portageq envvar DEFAULT_ABI)
DISTDIR=$(host_portageq envvar DISTDIR)
LIBDIR=$(host_portageq envvar "LIBDIR_${ABI}")
MAKEOPTS=$(host_portageq envvar MAKEOPTS)
PORTAGE_TMPDIR=$(host_portageq envvar PORTAGE_TMPDIR)
PORTDIR=$(host_portageq get_repo_path / gentoo)

ROOT=${1%/}
EROOT=${ROOT}${EPREFIX:-}
SYSROOT=${SYSROOT:-${ROOT}}
ESYSROOT=${SYSROOT:-${ROOT}}${EPREFIX:-}
PORTAGE_CONFIGROOT=${EROOT}
CONFIG_SITE=${CROSS_BOSS}/scripts/config.site
PREROOTPATH=${CROSS_BOSS}/path/generated:${CROSS_BOSS}/path

# cross-emerge defaults to --root-deps=rdeps, which is unhelpful.
CROSS_CMD=emerge

if [[ -z ${ROOT} ]]; then
	echo "Please specify a target directory." >&2
	exit 1
fi

mkdir -p "${EROOT}"/etc/portage || exit $?
ROOT_PROFILE=${EROOT}/etc/portage/make.profile
ROOT_PROFILE_RESOLVED=$(readlink -m "${ROOT_PROFILE}" 2>/dev/null)

if [[ ! -d ${ROOT_PROFILE} && ${ROOT_PROFILE_RESOLVED} = */profiles/* ]]; then
	echo "Auto-correcting ${ROOT_PROFILE} symlink for build system." >&2
	ln -snf "${PORTDIR}/profiles/${ROOT_PROFILE_RESOLVED##*/profiles/}" "${ROOT_PROFILE}" || exit $?
fi

if [[ ! -d ${ROOT_PROFILE} ]]; then
	echo "Please create a valid ${ROOT_PROFILE} symlink." >&2
	exit 1
fi

ROOT_PROFILE_RESOLVED=$(readlink -e "${ROOT_PROFILE}" 2>/dev/null)

if [[ ${ROOT_PROFILE_RESOLVED} = */profiles/embedded ]]; then
	echo "${ROOT_PROFILE} is pointing at the embedded profile. Please choose a more appropriate one." >&2
    exit 1
fi

HOST=$(root_portageq envvar CHOST)
ROOT_ABI=$(root_portageq envvar DEFAULT_ABI)
ROOT_LIBDIR=$(root_portageq envvar "LIBDIR_${ROOT_ABI}")
ROOT_PORTDIR=$(unset PORTDIR; host_portageq get_repo_path "${EROOT}" gentoo)

if [[ -z ${HOST} ]]; then
	echo "Please specify CHOST in the target make.conf." >&2
    exit 1
fi

OLD_CPP=${CPP:-${HOST}-cpp}
OLD_CC=${CC:-${HOST}-gcc}
OLD_CXX=${CXX:-${HOST}-g++}

if [[ -n ${EPREFIX} ]]; then
	# glibc: ld.so is a symlink, ldd is a binary.
	# musl: ld.so doesn't exist, ldd is a symlink.
	DYNLINKER=$(find /usr/"${HOST}"/usr/bin/{ld.so,ldd} -type l -print -quit 2>/dev/null)

	# musl symlinks ldd to ld-musl.so to libc.so. We want the ld-musl.so path,
	# not the libc.so path, so don't resolve the symlinks entirely.
	DYNLINKER=$(readlink "${DYNLINKER}")

	# Try to work out what the dynamic linker path will be. This is easier to
	# figure out after the libc is installed, but we need to know before.
	DYNLINKER=${EPREFIX}/lib${DYNLINKER##*/lib}

	# The toolchain sysroot doesn't set the linker path, so explicitly specify.
	CBFLAGS="-Wl,--dynamic-linker=${DYNLINKER}"
else
	CBFLAGS=
fi

set-toolchain

# Portage looks for ${CHOST}-ldconfig in the PATH after each build.
install -m0755 /dev/stdin "${CROSS_BOSS}"/path/generated/"${HOST}"-ldconfig <<EOF
#!/bin/sh
exec "${CROSS_BOSS}/bin/cb-bwrap-lite" "${ROOT}" \\
	--setenv LD_LIBRARY_PATH "${EPREFIX}/usr/${ROOT_LIBDIR}:${EPREFIX}/${ROOT_LIBDIR}" \\
	--setenv PATH "${EPREFIX}/usr/sbin:${EPREFIX}/usr/bin:${EPREFIX}/sbin:${EPREFIX}/bin" \\
	ldconfig
EOF
