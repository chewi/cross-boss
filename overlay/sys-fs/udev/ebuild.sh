# This should use HDEPEND but udev has lots of dependencies and
# setting that up here would be messy so just use RDEPEND instead.

EAPI=5
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI=5

RDEPEND="${RDEPEND} sys-libs/libcap"
