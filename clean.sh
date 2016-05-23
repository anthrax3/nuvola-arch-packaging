#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
# No set -o errexit because failing typically just means there was nothing to clean.
set -o nounset
source common.sh

function remove_packages() {
	rm -rf "${PKGDEST}"
}

function remove_sources() {
	rm -rf "${SRCDEST}"
}

function remove_logs() {
	rm -rf "${LOGDEST}"
}

function update_chroots() {
	for arch in "${ARCHITECTURES[@]}"; do
		sudo makechrootpkg -u -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}" &>/dev/null || true
	done
}

function reset_chroots() {
	sudo btrfs subvolume delete "${CHRDEST}"/*/build || true
	sudo rm -rf "${CHRDEST}"/*/build
}

function remove_chroots() {
	# mkarchroot likes to create btrfs subvolumes, which can't be `rm`ed.
	sudo btrfs subvolume delete "${CHRDEST}"/*/* || true
	rm -rf "${CHRDEST}"
}

function remove_all() {
	remove_chroots
	rm -rf "${BUILDDIR}"
}

COMMAND="${1}"
shift && "${COMMAND}" "${@}"
