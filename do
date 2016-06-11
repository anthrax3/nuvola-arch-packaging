#!/bin/bash

# Source and define message utility functions.
source /usr/share/makepkg/util/message.sh

set -o nounset

STARTED="$(date -Im)"
BASEDIR="${PWD}"
BUILDDIR="${BASEDIR}/build"
SYNCDEST="${BUILDDIR}/sync"
PKGDEST="${BUILDDIR}/packages"
SRCDEST="${BUILDDIR}/sources"
CHRDEST="${BUILDDIR}/chroot"
LOGDEST="${BUILDDIR}/logs"

REPO_NAME='nuvolaplayer'
REPO='/srv/pacman/nuvolaplayer'
POOL='/srv/pacman/packages'

case $(uname -m) in
	i686)   ARCHITECTURES=('i686') ;;
	x86_64) ARCHITECTURES=('x86_64' 'i686') ;;
	armv7*) ARCHITECTURES=('armv7h' 'armv6h' 'arm') ;;
	armv6*) ARCHITECTURES=('armv6h' 'arm') ;;
	*)      ARCHITECTURES=("$(uname -m)") ;;
esac

sudo_env_args=("PKGDEST=${PKGDEST}" "SRCDEST=${SRCDEST}" "LOGDEST=${LOGDEST}")
makepkg_template_args=('--template-dir' "${BASEDIR}/templates/makepkg")
makechrootpkg_args=('-n' '-l' 'build' '--' '--syncdeps' '--log' '--clean')
gpg_args=('--batch' '--yes' '--no-armor')
repose_args=('--pool' "${POOL}" '--xz' '--sign' '--files' '--verbose')
mkarchroot_dependencies=('base-devel' 'hardening-wrapper' 'namcap' 'git' 'python' 'vala' 'gtk3' 'libarchive' 'webkit2gtk' 'lasem' 'scour')

CORE_ANY=('scour')
CORE_ALL=( ) #'webkit2gtk-mse')
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
	function directory() { directories; }
	function directories() {
		# global BUILDDIR PKGDEST SRCDEST LOGDEST CHRDEST SYNCDEST REPO POOL
		# global -a ARCHITECTURES
		mkdir -p "${BUILDDIR}" "${REPO}" "${POOL}" "${PKGDEST}" \
			"${SRCDEST}" "${LOGDEST}" "${CHRDEST}" "${SYNCDEST}"
		( cd "${BUILDDIR}"; mkdir -p "${ARCHITECTURES[@]}" "any" )
		( cd "${CHRDEST}"; mkdir -p "${ARCHITECTURES[@]}" )
		( cd "${REPO}"; mkdir -p "${ARCHITECTURES[@]}" )
	}

	function chroot() { chroots; }
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

function check() {
	function chroot() { chroots; }
	function chroots() {
		# global BUILDDIR CHRDEST -a ARCHITECTURES
		[[ -d "${CHRDEST}/$(uname -m)/root" ]] || exitmsg "No chroot found in ${CHRDEST}! Run \`$0 create chroots\`." 1
		for arch in "${ARCHITECTURES[@]}"; do
			local Config="${BASEDIR}/config/pacman.conf"
			local DBFake="${SYNCDEST}/${arch}"
			local DBPath="${CHRDEST}/${arch}/root/var/lib/pacman"

			mkdir -p "${DBFake}"
			ln -sf "${DBPath}/local" "${DBFake}"
			fakeroot -- pacman -Sy --dbpath "${DBFake}" --config "${Config}" --logfile /dev/null &> /dev/null
			pacman -Qu --dbpath "${DBFake}" --config "${Config}" &> /dev/null && exitmsg "Updates available! Run \`$0 update chroots\`." 2
		done
	}

	COMMAND="${1}"
	shift && "${COMMAND}" "${@}"
}

function update() {
	function chroot() { chroots; }
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

function build() {
	function all() {
		function package() { packages; }
		function packages() {
			# global -f `check chroots` `clean chroots` `create directories`
			# global -f `build package` -a makechrootpkg_args ARCHITECTURES
			# global -a CORE_ANY CORE_ALL CORE_STABLE CORE_LATEST
			# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
			create directories
			check chroots

			msg "Building core packages..."

			clean chroots
			msg2 "Building support packages..."
			build packages "${CORE_ANY[@]}" "${CORE_ALL[@]}"

			clean chroots
			msg2 "Building latest packages..."
			build packages "${CORE_LATEST[@]}"

			clean chroots
			msg2 "Building release packages..."
			build packages "${CORE_STABLE[@]}"

			msg "Done! Consider running \`$0 build all apps\` now."
		}

		function app() { apps; }
		function apps() {
			# global -f `check chroots` `clean chroots` `create directories`
			# global -f `build app` -a makechrootpkg_args
			# global -a APPS_LATEST APPS_STABLE
			# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
			create directories
			check chroots
			clean chroots

			msg "Building latest nuvola-app packages..."
			build apps latest "${APPS_LATEST[@]}"

			msg "Building release nuvola-app packages..."
			build apps release "${APPS_STABLE[@]}"
			
			msg "Done! Consider running \`$0 publish\` now."
		}

		COMMAND="${1}"
		shift && "${COMMAND}" "${@}"
	}

	function apps() { app "${@}"; }
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

	function packages() { package; }
	function package() {
		# global BASEDIR BUILDDIR PKGDEST SRCDEST CHRDEST
		# global -a makechrootpkg_args ARCHITECTURES
		local -a pkgs=( "${@}" )
		
		for package in "${pkgs[@]}"; do
			for arch in "${ARCHITECTURES[@]}"; do
				grep -Ff \
					<(printf '%s\n' "${ARCHITECTURES[@]}") \
					<(cd "${BASEDIR}/packages/${package}" && makepkg --packagelist) \
					&& pkgarch="$arch" || pkgarch="any"

				msg2 "Building ${package} (${pkgarch})..."
				cp -r "${BASEDIR}/packages/${package}" "${BUILDDIR}/${arch}/${package}"
				(
					cd "${BUILDDIR}/${arch}/${package}"
					sudo -E "${sudo_env_args[@]}" makechrootpkg -r "${CHRDEST}/${arch}" "${makechrootpkg_args[@]}"
				)
				rm -rf "${BUILDDIR}/${arch}/${package}"
				msg2 "Finished: ${package} (${pkgarch})."
				[[ "${pkgarch}" == "any" ]] && continue 2
			done
		done
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
		# global CHRDEST SYNCDEST
		warning "Removing working copies of all chroots in ${CHRDEST}!"
		sudo btrfs subvolume delete "${CHRDEST}"/*/build || true
		sudo rm -rf "${CHRDEST}"/*/build
		sudo rm -rf "${SYNCDEST}"
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

COMMAND="${1}"
shift && "${COMMAND}" "${@}"
