# Not everyone uses 022.
umask 022

# Give us some toys.
OLD_PATH=${PATH}
source /lib/rc/sh/functions.sh
PATH=${OLD_PATH}:${PATH}

die() {
	[[ -z "${1}" ]] && eend 1
	eerror "Error on line ${BASH_LINENO[0]} of ${BASH_SOURCE[1]}! ${1}"
	exit 1
}

on-exit() {
	ebegin "Removing temporary cross-boss files"
	find "${ROOT}"/etc/portage -type f -name cross-boss -delete
	eend 0

	ebegin "Pruning empty directories"
	find "${ROOT}"/etc/portage -type d -empty -delete
	eend 0

	if [[ -n "${DISTCCD_PID}" ]]; then
		ebegin "Stopping distccd"
		kill "${DISTCCD_PID}"
		wait "${DISTCCD_PID}" 2> /dev/null
		eend 0
	fi
}

cb-git() {
	git --git-dir "${CROSS_BOSS}"/.git --work-tree "${CROSS_BOSS}" "${@}"
}

export-env() {
	export PORTDIR DISTDIR PORTAGE_TMPDIR MAKEOPTS ROOT PORTAGE_CONFIGROOT CONFIG_SITE
}

set-sysroot() {
	export \
		CPP="${HOST}-cpp --sysroot=${ROOT}" \
		CC="${HOST}-gcc --sysroot=${ROOT}" \
		CXX="${HOST}-g++ --sysroot=${ROOT}" \
		SYSROOT=${ROOT} \
		PREROOTPATH
}

cross-emerge() {
	OLD_PATH=${PATH} PATH=${PREROOTPATH}:${PATH} "${HOST}-emerge" "${@}"
}

PORTDIR=$(portageq get_repo_path / gentoo)
DISTDIR=$(portageq envvar DISTDIR)
PORTAGE_TMPDIR=$(portageq envvar PORTAGE_TMPDIR)
MAKEOPTS=$(portageq envvar MAKEOPTS)

ROOT=${1%/}
PORTAGE_CONFIGROOT=${ROOT}
CONFIG_SITE=${CROSS_BOSS}/scripts/config.site
WRAPPER_PATH=${ROOT}/usr/libexec/cross-boss/bin
PREROOTPATH=${WRAPPER_PATH}${PREROOTPATH+:}${PREROOTPATH}

if [[ -z ${ROOT} ]]; then
	eerror "Please specify a target directory."
	exit 1
fi

ebegin "Creating ${ROOT}"
mkdir -p "${ROOT}"/etc/portage || die
eend 0

# Clean up on exit.
trap on-exit EXIT || die

unset CFG_EXCLUDE
[[ ${0##*/} = cb-emerge-proot ]] && CFG_EXCLUDE+=" --exclude=*/cross-boss"

ebegin "Copying cross-boss files"
rsync -rltDmx --chmod=ugo=rwX ${CFG_EXCLUDE} "${CROSS_BOSS}/root/" "${ROOT}/" || die
eend 0

ebegin "Removing obsolete cross-boss files"
COMMIT=`cat "${ROOT}/.cross-boss-commit" 2> /dev/null`
cb-git diff --name-only --diff-filter=D ${COMMIT} "${CROSS_BOSS}"/root | sed "s:^root/:${ROOT}/:" | xargs rm -f || die
eend 0

ebegin "Recording cross-boss commit"
cb-git show-ref --head --dereference HEAD | sed "s: .*::" > "${ROOT}"/.cross-boss-commit || die
eend 0

if [[ ! -d "${ROOT}"/etc/portage/make.profile ]]; then
	eerror "Please create a ${ROOT}/etc/portage/make.profile symlink."
	exit 1
fi

# CHOST may be set in the profile but make.conf is preferable.
HOST=$(PORTAGE_CONFIGROOT=${PORTAGE_CONFIGROOT} portageq envvar CHOST)

if [[ -z ${HOST} ]]; then
	eerror "Please specify CHOST in the target make.conf."
	exit 1
fi

ebegin "Recreating sysroot script symlinks"
mkdir -p "${WRAPPER_PATH}" || die
rm -f "${WRAPPER_PATH}"/*

for TOOL in compiler generate scanner; do
	ln -snf "${CROSS_BOSS}"/scripts/g-ir-wrapper "${WRAPPER_PATH}/g-ir-${TOOL}" || die
done

for CONFIG in krb5 ksba libassuan libpng ncurses{w,}{5,6} npth pcap pth python sdl sdl2 xml2 xslt; do
    ln -snf "${CROSS_BOSS}"/scripts/config-wrapper "${WRAPPER_PATH}/${CONFIG}-config" || die
done

ln -snf "${CROSS_BOSS}"/scripts/guile-config "${WRAPPER_PATH}/guile-config" || die
ln -snf "${CROSS_BOSS}"/scripts/ldconfig "${WRAPPER_PATH}/${HOST}-ldconfig" || die
eend 0
