# No bug for this, think they got sick of HDEPEND ebuilds!
# xorg-server is the archetypical candidate for HDEPEND anyway.

EAPI=5-hdepend
AUTOTOOLS_AUTO_DEPEND=no
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI=5-hdepend

HDEPEND="$(echo "${DEPEND}" | egrep "sys-devel/flex") ${AUTOTOOLS_DEPEND}"
DEPEND="$(echo "${DEPEND}" | sed -r "/sys-devel\/flex/d")"
