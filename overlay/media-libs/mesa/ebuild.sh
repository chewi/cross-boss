# No bug for this, think they got sick of HDEPEND ebuilds!

EAPI=5-hdepend
AUTOTOOLS_AUTO_DEPEND=no
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI=5-hdepend

HDEPEND="$(echo "${DEPEND}" | egrep "dev-libs/libxml2|sys-devel/(bison|flex)|virtual/pkgconfig") ${AUTOTOOLS_DEPEND} wayland? ( dev-libs/wayland )"
DEPEND="$(echo "${DEPEND}" | sed -r "/dev-libs\/libxml2|sys-devel\/(bison|flex)|virtual\/pkgconfig/d")"
