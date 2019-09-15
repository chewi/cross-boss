while read -r LINE; do
	LINE=${LINE#* }
	set -- --ro-bind "${LINE}" "${LINE}" "${@}"
done < <(grep "^interpreter " /proc/sys/fs/binfmt_misc/qemu-* 2>/dev/null)
