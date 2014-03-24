# Gentoo bug #446172.

EAPI=5-hdepend
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI=5-hdepend

HDEPEND="$(echo "${DEPEND}" | egrep "sys-devel/(flex|gettext|libtool)|virtual/pkgconfig")"
DEPEND="$(echo "${DEPEND}" | sed -r "/sys-devel\/(gettext|libtool)|virtual\/pkgconfig/d")"
