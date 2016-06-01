# Nuvola Player Arch Linux Packaging Tools
This is a collection of `bash` scripts that leverage [`makepkg-template`](https://www.archlinux.org/pacman/makepkg-template.1.html) (from [`pacman`](https://www.archlinux.org/pacman/)) and `makechrootpkg` (from the Arch Linux [devtools](https://git.archlinux.org/devtools.git)) to build a complete collection of packages (both stable and the latest git) for [Nuvola Player](https://tiliado.eu/nuvolaplayer/), and create a repository for them with [`repose`](https://github.com/vodik/repose).

## Package Repository (Pacman)
The primary purpose of these scripts is to maintain the official Arch Linux package repository for Nuvola Player. This repository includes the current release builds of Diorite 0.2, Nuvola Player 3.0, and all declared-stable Nuvola Player integrations; plus VCS-source builds of Diorite 0.3, Nuvola Player 3.1, and all declared-functional Nuvola Player integrations. It also includes chromium-pepper-flash-standalone and freshplayerplugin, to benefit integrations that require Flash.

These should always be quite up-to-date; if they are not, [file an issue](https://github.com/tiliado/nuvola-arch-packaging/issues/new) against this repository.

To use these packages, add the following to your pacman.conf:

```ini
[nuvolaplayer]
SigLevel = Required TrustedOnly
Server = https://repo.celti.name/archlinux/$repo/$arch
```

This repository and its database will always be GPG-signed: you can find my key on [most keyservers](https://sks-keyservers.net/pks/lookup?op=vindex&search=0x123C3F8B058A707F86643316FA682BD8910CF4EA), on [Keybase](https://keybase.io/Celti), on my [personal website](https://celti.name/), and on every commit to the [canonical git repository for these scripts](https://github.com/tiliado/nuvola-arch-packaging/), or you can run the following commands to have pacman import it automatically:

```sh
pacman-key --recv-keys 123C3F8B058A707F86643316FA682BD8910CF4EA
pacman-key --lsign-key 123C3F8B058A707F86643316FA682BD8910CF4EA
```

## Usage
By default, all building happens in `${PWD}/build/`, the packages end up in `/srv/pacman/packages/`, and the repository is named `[nuvolaplayer]` and ends up in `/srv/pacman/nuvolaplayer/${ARCH}`, for both x86\_64 and i686.

```sh
pacman -S devtools repose
# Note that repose is not available in the official repositories.

git clone https://github.com/tiliado/nuvola-arch-packaging.git
cd nuvola-arch-packaging

# Build and publish the tree, then delete all working files.
./do create chroots
./do build all releases
./do build all latest
./do publish
./do clean dist

# Build and publish a single release app in an updated pre-existing container.
./do clean chroots
./do update chroots
./do build app release google-play-music
./do publish

# Wipe the entire tree, then build several -git apps and publish them.
./do clean dist
./do create chroots
./do build apps latest google-play-music-git yandex-music-git bandcamp-git deezer-git
./do publish
```

## Build Status
 - [8tracks](https://github.com/tiliado/nuvola-app-8tracks): Fully functional.
 - [Amazon Cloud Player](https://github.com/tiliado/nuvola-app-amazon-cloud-player): Fully functional.
 - [Bandcamp](https://github.com/tiliado/nuvola-app-bandcamp): Fully functional.
 - [Deezer](https://github.com/tiliado/nuvola-app-deezer): Fully functional.
 - [Google Calendar](https://github.com/tiliado/nuvola-app-google-calendar): Experimental, outdated Makefiles, requires nuvolaplayer-git.
 - [Google Play Music](https://github.com/tiliado/nuvola-app-google-play-music): Fully functional.
 - [Hype Machine](https://github.com/tiliado/nuvola-app-hype-machine): Not currently functional, not being built.
 - [Jango](https://github.com/tiliado/nuvola-app-jango): Outdated Makefiles.
 - [KEXP-FM radio (Seattle 90.3)](https://github.com/tiliado/nuvola-app-kexp): Outdated Makefiles, no tagged release.
 - [Microsoft Groove Music](https://github.com/tiliado/nuvola-app-groove): Outdated Makefiles.
 - [Mixcloud](https://github.com/tiliado/nuvola-app-mixcloud): Outdated Makefiles.
 - [OwnCloud Music](https://github.com/tiliado/nuvola-app-owncloud-music): Outdated Makefiles, requires nuvolaplayer-git.
 - [Pandora Radio](https://github.com/tiliado/nuvola-app-pandora): Outdated Makefiles, not currently functional, not being built.
 - [Plex Media](https://github.com/tiliado/nuvola-app-plex): Outdated Makefiles.
 - [SoundCloud](https://github.com/tiliado/nuvola-app-soundcloud): Outdated Makefiles.
 - [Spotify](https://github.com/tiliado/nuvola-app-spotify): Outdated Makefiles.
 - [TuneIn](https://github.com/tiliado/nuvola-app-tunein): Outdated Makefiles.
 - [Yandex.Music](https://github.com/tiliado/nuvola-app-yandex-music): Outdated Makefiles.
