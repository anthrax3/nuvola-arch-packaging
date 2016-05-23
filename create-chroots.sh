#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -o errexit -o nounset
source common.sh

for arch in "${ARCHITECTURES[@]}"; do
	sudo setarch "${arch}" mkarchroot \
		-C "/usr/share/devtools/pacman-extra.conf" \
		-M "/usr/share/devtools/makepkg-${arch}.conf" \
		"${CHRDEST}/${arch}/root" \
		base-devel
done
