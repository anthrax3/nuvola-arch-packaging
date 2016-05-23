#!/bin/bash
set -o nounset

BASEDIR="${PWD}"
BUILDDIR="${BASEDIR}/build"
PKGDEST="${BUILDDIR}/packages"
SRCDEST="${BUILDDIR}/sources"
CHRDEST="${BUILDDIR}/chroot"
LOGDEST="${BUILDDIR}/logs"

REPO='/srv/pacman/nuvolaplayer'
POOL='/srv/pacman/packages'

PACKAGER='Patrick Burroughs (Celti) <celti@celti.name>'
GPGKEY='123C3F8B058A707F86643316FA682BD8910CF4EA'
MAKEFLAGS='-j8'

ARCHITECTURES=('i686' 'x86_64')

APPS=('bandcamp' 'deezer' 'google-play-music')
APPS_NOT_WORKING=('8tracks' 'google-calendar' 'hype-machine' 'pandora')
APPS_NEED_UPDATE=('amazon-cloud-player' 'groove' 'jango' 'kexp' 'mixcloud' 'owncloud-music' 'plex' 'soundcloud' 'spotify' 'tunein' 'yandex-music')
APPS_ALL=('8tracks' 'amazon-cloud-player' 'bandcamp' 'deezer' 'google-calendar' 'google-play-music' 'groove' 'hype-machine' 'jango' 'kexp' 'logitech-media-server' 'mixcloud' 'owncloud-music' 'pandora' 'plex' 'soundcloud' 'spotify' 'tunein' 'yandex-music')

mkdir -p "${PKGDEST}" "${SRCDEST}" "${CHRDEST}" "${LOGDEST}" "${REPO}" "${POOL}"
( cd "${BUILDDIR}"; mkdir -p "${ARCHITECTURES[@]}" "any" )
( cd "${CHRDEST}"; mkdir -p "${ARCHITECTURES[@]}" )

makepkg_template_args=('--template-dir' "${BASEDIR}/templates/makepkg")
makechrootpkg_args=('-u' '-n' '-l' 'build' '--' '--syncdeps' '--log' '--clean')
gpg_args=('--batch' '--yes' '--detach-sign' '--no-armor' '--local-user' "${GPGKEY}")
repose_args=('--pool' "${POOL}" '--xz' '--sign' '--files' '--verbose' 'nuvolaplayer')
