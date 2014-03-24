# No bug for the moment, want to raise libtool issue in general.

EAPI="5"
source "${PORTDIR}/${CATEGORY}/${PN}/${BASH_SOURCE[0]##*/}"
EAPI="5"

inherit libtool

eval "
src_prepare() {
	$(function_body src_prepare)
	elibtoolize

	# Fool make to use g-ir-scanner from PATH.
	touch gtk/g-ir-scanner || die
}"
