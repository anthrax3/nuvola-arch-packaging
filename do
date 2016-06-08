#!/bin/bash

# Source and define message utility functions.
source /usr/share/makepkg/util/message.sh

set -o nounset

STARTED="$(date -Im)"
BASEDIR="${PWD}"
BUILDDIR="${BASEDIR}/build"
PKGDEST="${BUILDDIR}/packages"
SRCDEST="${BUILDDIR}/sources"
CHRDEST="${BUILDDIR}/chroot"
LOGDEST="${BUILDDIR}/logs"

REPO_NAME='nuvolaplayer'
REPO='/srv/pacman/nuvolaplayer'
POOL='/srv/pacman/packages'

ARCHITECTURES=('i686' 'x86_64')

sudo_env_args=("PKGDEST=${PKGDEST}" "SRCDEST=${SRCDEST}" "LOGDEST=${LOGDEST}")
makepkg_template_args=('--template-dir' "${BASEDIR}/templates/makepkg")
makechrootpkg_args=('-n' '-l' 'build' '--' '--syncdeps' '--log' '--clean')
gpg_args=('--batch' '--yes' '--no-armor')
repose_args=('--pool' "${POOL}" '--xz' '--sign' '--files' '--verbose')
mkarchroot_dependencies=('base-devel' 'namcap' 'git' 'python' 'vala' 'gtk3' 'libarchive' 'webkit2gtk' 'lasem' 'scour')

CORE_STABLE=('diorite0.2' 'nuvolaplayer')
CORE_LATEST=('diorite0.3' 'nuvolaplayer-git')

APPS_STABLE=('8tracks' 'amazon-cloud-player' 'bandcamp' 'deezer' 'google-play-music' 'groove' 'jango' 'logitech-media-server' 'mixcloud' 'owncloud-music' 'plex' 'soundcloud' 'spotify' 'tunein' 'yandex-music' 'all-services')
APPS_LATEST=('8tracks-git' 'amazon-cloud-player-git' 'bandcamp-git' 'deezer-git' 'google-calendar-git' 'google-play-music-git' 'groove-git' 'jango-git' 'kexp-git' 'logitech-media-server-git' 'mixcloud-git' 'owncloud-music-git' 'plex-git' 'soundcloud-git' 'spotify-git' 'tunein-git' 'yandex-music-git' 'all-services-git')
APPS_NOT_WORKING=('hype-machine' 'pandora')

# Set some error handling stuff.
IFS=$'\n\t'
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
function exitmsg() { error "${1}"; exit "${2}"; }
set -o errexit -o nounset -o pipefail

# Colourise if stderr is a terminal.
[[ -t 2 ]] && colorize

function create() {
	function directories() {
		# global BUILDDIR PKGDEST SRCDEST LOGDEST CHRDEST REPO POOL
		# global -a ARCHITECTURES
		mkdir -p "${BUILDDIR}" "${REPO}" "${POOL}"
		mkdir -p "${PKGDEST}" "${SRCDEST}" "${LOGDEST}" "${CHRDEST}"
		( cd "${BUILDDIR}"; mkdir -p "${ARCHITECTURES[@]}" "any" )
		( cd "${CHRDEST}"; mkdir -p "${ARCHITECTURES[@]}" )
		( cd "${REPO}"; mkdir -p "${ARCHITECTURES[@]}" )
	}

	function chroots() {
		# global -f `create directories`
		# global -a ARCHITECTURES mkarchroot_dependencies
		# global BASEDIR CHRDEST

		msg "Creating directory tree in ${BUILDDIR}..."
		create directories

		msg "Creating chroots in ${CHRDEST}:"
		for arch in "${ARCHITECTURES[@]}"; do
			msg2 "Creating ${arch} chroot..."
			sudo setarch "${arch}" mkarchroot \
				-C "${BASEDIR}/config/pacman.conf" \
				-M "/usr/share/devtools/makepkg-${arch}.conf" \
				"${CHRDEST}/${arch}/root" \
				"${mkarchroot_dependencies[@]}"
		done
	}

	COMMAND="${1}"
	shift && "${COMMAND}" "${@}"
}

function build() {
	# global CHRDEST
	[[ -d "${CHRDEST}/$(uname -m)/root" ]] || exitmsg "No chroot found in ${CHRDEST}! Run \`$0 create chroots\`." 1

	function all() {
		function releases() {
			# global -f `create directories` `clean chroots` `update chroots` `build package` `build app`
			# global -a makechrootpkg_args ARCHITECTURES APPS_STABLE CORE_STABLE
			# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
			create directories
			clean chroots
			update chroots

			msg "Building core software releases:"
			for arch in "${ARCHITECTURES[@]}"; do
				build package "$arch" "${CORE_STABLE[@]}"
			done

			msg "Building app integration releases:"
			build app release "${APPS_STABLE[@]}"
		}

		function release() {
			releases
		}

		function latest() {
			# global -f `create directories` `clean chroots` `update chroots` `build package` `build app`
			# global -a makechrootpkg_args ARCHITECTURES APPS_LATEST CORE_LATEST
			# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
			create directories
			clean chroots
			update chroots

			msg "Building latest core software revisions:"
			for arch in "${ARCHITECTURES[@]}"; do
				build package "$arch" "${CORE_LATEST[@]}"
			done

			msg "Building latest app integration revisions:"
			build app latest "${APPS_LATEST[@]}"
		}

		COMMAND="${1}"
		shift && "${COMMAND}" "${@}"
	}

	function package() {
		# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
		# global -a makechrootpkg_args ARCHITECTURES
		local arch="${1}"
		shift && local -a pkgs=( "${@}" )

		for package in "${pkgs[@]}"; do
			cp -r "${BASEDIR}/packages/${package}" "${BUILDDIR}/${arch}/${package}"
			(
				msg2 "Building ${package} (${arch})..."
				cd "${BUILDDIR}/${arch}/${package}"
				sudo -E "${sudo_env_args[@]}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}"
				msg2 "Finished: ${package} (${arch})."
			)
			rm -rf "${BUILDDIR}/${arch}/${package}"
		done
	}

	function app() {
		# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
		# global -a makepkg_template_args makechrootpkg_args
		local arch="$(uname -m)"
		local which="${1}"
		shift && local -a apps=( "${@}" )

		for app in "${apps[@]}"; do
			mkdir -p "${BUILDDIR}/any/${app}"
			cd "${BUILDDIR}/any/${app}"

			msg2 "Generating PKGBUILD for ${app}..."
			makepkg-template "${makepkg_template_args[@]}" --input "${BASEDIR}/templates/${which}/${app}" --output PKGBUILD
			updpkgsums

			msg2 "Building ${app} (any)..."
			sudo -E "${sudo_env_args[@]}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}"
			msg2 "Finished: ${app} (any)."
			rm -rf "${BUILDDIR}/any/${app}"
		done
	}

	function apps() {
		app "${@}"
	}

	COMMAND="${1}"
	shift && "${COMMAND}" "${@}"
}


function publish() {
	# global -a ARCHITECTURES gpg_args repose_args
	# global POOL REPO PKGDEST

	# List all built packages.
	local -a packages=( $(find "${PKGDEST}" -name '*.pkg.tar.xz' -printf '%f\n') )
	msg "Built packages:"
	for pkg in "${packages[@]}"; do msg2 "$pkg"; done

	# Sign all built packages.
	msg "Signing packages:"
	for pkg in "${packages[@]}"; do
		msg2 "Signing ${pkg}..."
		gpg ${gpg_args[@]} --detach-sign "${PKGDEST}/${pkg}"
	done

	# Move all built packages and signatures to pool.
	msg "Moving packages to ${POOL}..."
	mv -t "${POOL}" "${PKGDEST}"/*.pkg.tar.xz{,.sig}

	# Generate repositories and databases.
	for arch in "${ARCHITECTURES[@]}"; do
		local -a pkgnames=( $( printf '%s\n' "${packages[@]}" | sed 's#.*/##;s/-[^-]*$//;s/-[^-]*$//;s/-[^-]*$//;' | sort -u) )
		msg "Updating and signing database [nuvolaplayer] (${arch}):"
		msg2 "Dropping old packages..."
		repose --arch="${arch}" --root="${REPO}/${arch}" "${repose_args[@]}" "${REPO_NAME}" --drop "${pkgnames[@]}"
		msg2 "Adding new packages..."
		repose --arch="${arch}" --root="${REPO}/${arch}" "${repose_args[@]}" "${REPO_NAME}" "${pkgnames[@]}"
	done
}

function clean() {
	function packages() {
		# global PKGDEST
		warning "Removing all packages in ${PKGDEST}!"
		rm -rf "${PKGDEST}"
	}

	function sources() {
		# global SRCDEST
		warning "Removing all package sources in ${SRCDEST}!"
		rm -rf "${SRCDEST}"
	}

	function logs() {
		# global LOGDEST
		warning "Removing all build logs in ${LOGDEST}!"
		rm -rf "${LOGDEST}"
	}

	function chroots() {
		# global CHRDEST
		warning "Removing working copies of all chroots in ${CHRDEST}!"
		sudo btrfs subvolume delete "${CHRDEST}"/*/build || true
		sudo rm -rf "${CHRDEST}"/*/build
	}

	function dist() {
		# global CHRDEST BUILDDIR
		warning "Removing all non-distribution files (${BUILDDIR})!"
		sudo btrfs subvolume delete "${CHRDEST}"/*/*/ || true
		sudo rm -rf "${BUILDDIR}"
	}

	COMMAND="${1}"
	shift && "${COMMAND}" "${@}"
}


function update() {

	function chroots() {
		# global BASEDIR CHRDEST
		# global -a ARCHITECTURES

		[[ -d "${CHRDEST}/$(uname -m)/root" ]] || exitmsg "No chroot found in ${CHRDEST}! Run \`$0 create chroots\`." 1

		msg "Updating chroots in ${CHRDEST}:"
		for arch in "${ARCHITECTURES[@]}"; do
			msg2 "Updating ${arch} chroot..."
			sudo arch-nspawn \
				-C "${BASEDIR}/config/pacman.conf" \
				-M "/usr/share/devtools/makepkg-${arch}.conf" \
				"${CHRDEST}/${arch}/root" \
				pacman -Syu --noconfirm
		done
	}

	COMMAND="${1}"
	shift && "${COMMAND}" "${@}"
}

COMMAND="${1}"
shift && "${COMMAND}" "${@}"
