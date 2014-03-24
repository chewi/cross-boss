# Gentoo bug #472224.

EAPI=5
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI=5

python_check_deps() {
	has_version --host-root $(echo "${DEPEND}" | grep -o "[^ ]*x11-proto/xcb-proto[^ ]*" | head -n1)
}
