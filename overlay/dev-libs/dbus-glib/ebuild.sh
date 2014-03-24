# Gentoo bug #498098.

EAPI=5-hdepend
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI=5-hdepend

HDEPEND="$(echo "${DEPEND}" | egrep "dev-util/gtk-doc|virtual/pkgconfig") ${CATEGORY}/${PN}"
DEPEND="$(echo "${DEPEND}" | sed -r "/dev-util\/gtk-doc|virtual\/pkgconfig/d")"

MAKEOPTS="${MAKEOPTS} DBUS_BINDING_TOOL=dbus-binding-tool"
