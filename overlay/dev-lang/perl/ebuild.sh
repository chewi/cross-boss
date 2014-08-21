# Gentoo bug #134650.

EAPI=5
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI=5

case "${PV}" in
5.20.0) CROSS_VER=0.9 ;;
5.18.2) CROSS_VER=0.8.5 ;;
5.18.1) CROSS_VER=0.8.3 ;;
5.16.3) CROSS_VER=0.7.4 ;;
# Following versions need fixing!
5.16.0) CROSS_VER=0.7.1 ;;
5.14.2) CROSS_VER=0.6.5 ;;
5.14.1) CROSS_VER=0.6.2 ;;
5.12.3) CROSS_VER=0.5   ;;
esac

if [[ -n "${CROSS_VER}" ]]; then
	SRC_URI+=" https://raw.github.com/arsv/${PN}-cross/releases/${P}-cross-${CROSS_VER}.tar.gz"

	eval "
	src_prepare() {
		$(function_body src_prepare)
		echo \"exec ./configure \\\"\\\${@/-des}\\\" --target=\${CHOST} -Dinstallprefix='' -Dinstallusrbinperl='undef' -Dusevendorprefix='define'\" > Configure || die

		if use gdbm; then
			sed -i 's:INC => .*:INC => \"-I${EROOT}usr/include/gdbm\":g' ext/NDBM_File/Makefile.PL || die
		fi
	}"

	src_compile() {
		export BZIP2_INCLUDE=${EROOT}usr/include
		export BZIP2_LIB=${EROOT}usr/$(get_libdir)
		export ZLIB_INCLUDE=${EROOT}usr/include
		export ZLIB_LIB=${EROOT}usr/$(get_libdir)
		emake -j1
	}
fi
