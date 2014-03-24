# Gentoo bug #498030.

EAPI=5-hdepend
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI=5-hdepend

HDEPEND="${CATEGORY}/${PN}"
MAKEOPTS="${MAKEOPTS} AGexe=$(which autogen) CLexe=$(which columns) GDexe=$(which getdefs)"

post_src_configure() {
	sed -i "s:PROG=\./:PROG=:" autoopts/tpl/agtexi-cmd.tpl || die
}
