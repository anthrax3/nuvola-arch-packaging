#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -o errexit -o nounset
source common.sh

[[ -d "${CHRDEST}/$(uname -m)/root" ]] || ( echo "No chroot found in ${CHRDEST}! Run create-chroots.sh"; exit 1 )

function all_stable() {
	# global -a ARCHITECTURES APPS makechrootpkg_args
	# global BASEDIR CHRDEST
	local app arch

	# Reset working chroots.
	./clean.sh reset_chroots

	# Build core apps.
	for app in scour diorite nuvolaplayer; do
		for arch in "${ARCHITECTURES[@]}"; do
			cp -r "${BASEDIR}/packages/${app}" "${BUILDDIR}/${arch}/${app}"
			( cd "${BUILDDIR}/${arch}/${app}"; sudo -E PKGDEST="${PKGDEST}" SRCDEST="${SRCDEST}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}" )
			rm -rf "${BUILDDIR}/${arch}/${app}"
		done
	done

	# Build integrations.
	for app in "${APPS[@]}"; do
		app_stable "${app}"
	done
}

function app_stable() {
	# global BASEDIR PKGDEST SRCDEST CHRDEST
	# global -a makepkg_template_args makechrootpkg_args
	local app="${1}"
	local arch="$(uname -m)"

	mkdir -p "${BUILDDIR}/any/${app}"
	cd "${BUILDDIR}/any/${app}"
	makepkg-template "${makepkg_template_args[@]}" --input "${BASEDIR}/templates/stable/${app}" --output PKGBUILD
	updpkgsums
	sudo -E PKGDEST="${PKGDEST}" SRCDEST="${SRCDEST}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}"
	rm -rf "${BUILDDIR}/any/${app}"
}

function all_latest() {
	# global -a ARCHITECTURES APPS makechrootpkg_args
	# global BASEDIR CHRDEST
	local app arch

	# Reset working chroots.
	./clean.sh reset_chroots

	# Build core apps.
	for app in scour diorite-git nuvolaplayer-git; do
		for arch in "${ARCHITECTURES[@]}"; do
			cp -r "${BASEDIR}/packages/${app}" "${BUILDDIR}/${arch}/${app}"
			( cd "${BUILDDIR}/${arch}/${app}"; sudo -E PKGDEST="${PKGDEST}" SRCDEST="${SRCDEST}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}" )
			rm -rf "${BUILDDIR}/${arch}/${app}"
		done
	done

	# Build integrations.
	for app in "${APPS[@]}"; do
		app_latest "${app}"
	done
}

function app_latest() {
	# global BASEDIR PKGDEST SRCDEST CHRDEST
	# global -a makepkg_template_args makechrootpkg_args
	local app="${1}"
	local arch="$(uname -m)"

	mkdir -p "${BUILDDIR}/any/${app}-git"
	cd "${BUILDDIR}/any/${app}-git"
	makepkg-template "${makepkg_template_args[@]}" --input "${BASEDIR}/templates/git/${app}" --output PKGBUILD
	updpkgsums
	sudo -E PKGDEST="${PKGDEST}" SRCDEST="${SRCDEST}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}"
	rm -rf "${BUILDDIR}/any/${app}"
}

function sign_and_publish() {
	# global -a ARCHITECTURES APPS gpg_args repose_args
	# global BASEDIR POOL REPO ARCHITECTURES PKGDEST
	local arch

	## Move all buit packages to pkgdest.
	#find "${PKGDEST}" -name '*.pkg.tar.xz' -print0 | xargs -0 mv -t "${POOL}"

	# Sign all built packages.
	( cd "${PKGDEST}"; find . -name '*.pkg.tar.xz' -print0 | xargs -0l gpg "${gpg_args[@]}" )

	# Move all built packages and generated signatures to pool.
	find "${PKGDEST}" -name '*.pkg.tar.xz' -print0 -o -name '*.pkg.tar.xz.sig' -print0 | xargs -0 mv -t "${POOL}"

	# Generate repositories and databases.
	for arch in "${ARCHITECTURES[@]}"; do
		setarch "${arch}" repose -r "${REPO}/${arch}" "${repose_args[@]}"
	done
}

COMMAND="${1}"
shift && "${COMMAND}" "${@}"
