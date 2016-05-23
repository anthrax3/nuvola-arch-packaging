# Nuvola Player packaging desiderata for Arch Linux
This is a collection of `bash` scripts that leverage [`makepkg-template`](https://www.archlinux.org/pacman/makepkg-template.1.html) (from [`pacman`](https://www.archlinux.org/pacman/)) and `makechrootpkg` (from the Arch Linux [devtools](https://git.archlinux.org/devtools.git)) to build a complete collection of packages (both stable and the latest git) for [Nuvola Player](https://tiliado.eu/nuvolaplayer/), and create a repository for them with [`repose`](https://github.com/vodik/repose).

## Repository
The primary purpose of these scripts is to maintain an Arch Linux package repository for Nuvola Player. Add the following to your pacman.conf:

```ini
[nuvolaplayer]
SigLevel = Required TrustedOnly
Server = https://repo.celti.name/archlinux/$repo/$arch
```

This repository and its database will always be GPG-signed: you can find my key on [most keyservers](https://sks-keyservers.net/pks/lookup?op=vindex&search=0x123C3F8B058A707F86643316FA682BD8910CF4EA), on [Keybase](https://keybase.io/Celti), on my [personal website](https://celti.name/), and on every commit to the [canonical git repository for these scripts](https://git.celti.name/nuvola-arch-packaging.git), or you can run the following commands to have pacman import it automatically:

```sh
pacman-key --recv-keys 123C3F8B058A707F86643316FA682BD8910CF4EA
pacman-key --lsign-key 123C3F8B058A707F86643316FA682BD8910CF4EA
```

## Usage
By default, all building happens in `${PWD}/build/`, the packages end up in `/srv/pacman/packages/`, and the repository is named `[nuvolaplayer]` and ends up in `/srv/pacman/nuvolaplayer/${ARCH}`, for both x86\_64 and i686.

```sh
pacman -S devtools repose  # Note that repose is not available in the official repositories.

git clone https://git.celti.name/nuvola-arch-packaging.git
cd nuvola-arch-packaging

./create-chroots.sh
./build.sh all_stable
./build.sh all_latest
./build.sh sign_and_publish
./clean.sh remove_all
```
