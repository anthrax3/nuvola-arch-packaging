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

REPO='/srv/pacman/nuvolaplayer'
POOL='/srv/pacman/packages'

ARCHITECTURES=('i686' 'x86_64')

sudo_env_args=("PKGDEST=${PKGDEST}" "SRCDEST=${SRCDEST}" "LOGDEST=${LOGDEST}")
makepkg_template_args=('--template-dir' "${BASEDIR}/templates/makepkg")
makechrootpkg_args=('-c' '-n' '-l' 'build' '--' '--syncdeps' '--log' '--clean')
gpg_args=('--batch' '--yes' '--no-armor')
repose_args=('--verbose' '--pool' "${POOL}" '--xz' '--sign' '--files' '--verbose' 'nuvolaplayer')
mkarchroot_dependencies=('base-devel' 'namcap' 'git' 'python' 'vala' 'gtk3' 'libarchive' 'webkit2gtk' 'lasem' 'scour')

CORE_LATEST=('diorite-git' 'nuvolaplayer-git')
APPS_LATEST=('amazon-cloud-player-git' 'bandcamp-git' 'deezer-git' 'google-play-music-git' 'groove-git' 'jango-git' 'kexp-git' 'logitech-media-server-git' 'mixcloud-git' 'owncloud-music-git' 'plex-git' 'soundcloud-git' 'spotify-git' 'tunein-git' 'yandex-music-git' 'all-services-git')

CORE_STABLE=('diorite' 'nuvolaplayer')
APPS_STABLE=('amazon-cloud-player' 'bandcamp' 'deezer' 'google-play-music' 'groove' 'jango' 'logitech-media-server' 'mixcloud' 'owncloud-music' 'plex' 'soundcloud' 'spotify' 'tunein' 'yandex-music' 'all-services')
######## APPS_NOT_WORKING=('8tracks' 'google-calendar' 'hype-machine' 'pandora')

# Set some error handling stuff.
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
function exitmsg() { error "${1}"; exit "${2}"; }
set -o errexit -o nounset

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
		# global -f create directories
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
		function stable() {
			# global -f `create directories` `clean chroots` `update chroots` `build single`
			# global -a makechrootpkg_args ARCHITECTURES APPS_STABLE CORE_STABLE
			# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
			create directories
			clean chroots
			update chroots

			msg "Building core software releases:"
			for arch in "${ARCHITECTURES[@]}"; do
				for core in "${CORE_STABLE[@]}"; do
					cp -r "${BASEDIR}/packages/${core}" "${BUILDDIR}/${arch}/${core}"
					(
						cd "${BUILDDIR}/${arch}/${core}"
						msg2 "Building ${core} (${arch})..."
						sudo -E "${sudo_env_args[@]}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}"
						msg2 "Finished: ${core} (${arch})."
					)
					rm -rf "${BUILDDIR}/${arch}/${core}"
				done
			done

			msg "Building app integration releases:"
			for app in "${APPS_STABLE[@]}"; do
				build single stable "${app}"
			done
		}

		function latest() {
			# global -f `create directories` `clean chroots` `update chroots` `build single`
			# global -a makechrootpkg_args ARCHITECTURES APPS_LATEST CORE_LATEST
			# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
			create directories
			clean chroots
			update chroots

			msg "Building latest core software revisions:"
			for arch in "${ARCHITECTURES[@]}"; do
				for core in "${CORE_LATEST[@]}"; do
					cp -r "${BASEDIR}/packages/${core}" "${BUILDDIR}/${arch}/${core}"
					(
						msg2 "Building ${core} (${arch})..."
						cd "${BUILDDIR}/${arch}/${core}"
						sudo -E "${sudo_env_args[@]}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}"
						msg2 "Finished: ${core} (${arch})."
					)
					rm -rf "${BUILDDIR}/${arch}/${core}"
				done
			done

			msg "Building latest app integration revisions:"
			for app in "${APPS_LATEST[@]}"; do
				build single latest "${app}"
			done
		}

		COMMAND="${1}"
		shift && "${COMMAND}" "${@}"
	}

	function single() {
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

	COMMAND="${1}"
	shift && "${COMMAND}" "${@}"
}


function publish() {
	# global -a ARCHITECTURES gpg_args repose_args
	# global POOL REPO PKGDEST

	# List all built packages.
	local -a packages=( $(find "${PKGDEST}" -name '*.pkg.tar.xz' -printf '%f ') )
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
		msg "Updating and signing database [nuvolaplayer] (${arch}):"
		msg2 "Dropping old packages..."
		repose -m "${arch}" -r "${REPO}/${arch}" "${repose_args[@]}" --drop "${packages[@]}"
		msg2 "Adding new packages..."
		repose -m "${arch}" -r "${REPO}/${arch}" "${repose_args[@]}" "${packages[@]}"
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
