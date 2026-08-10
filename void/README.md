# Void Linux packaging

An `xbps-src` template for installing Utumno as a real system package on Void
Linux. Void has no AUR-style overlay, so using this means dropping the
template into a local checkout of `void-packages`.

## One-time setup

```
git clone --depth 1 https://github.com/void-linux/void-packages.git
cd void-packages
./xbps-src binary-bootstrap
```

## Add this template

From this repo:

```
cp -r void/srcpkgs/utumno /path/to/void-packages/srcpkgs/
```

(symlink instead of `cp` if you want `git pull` here to keep it in sync.)

## Build & install

```
cd /path/to/void-packages
./xbps-src pkg utumno
sudo xbps-install --repository=hostdir/binpkgs -R utumno
```

This installs Utumno to `/usr/share/quickshell/utumno`, picked up by
`qs -c utumno` the same way as the manual `~/.config/quickshell/utumno`
install — see the [root README](../README.md) for how to start it from your
compositor.

## Notes

- The template fetches the tagged release tarball (`refs/tags/$version`).
  Bump `version` and recompute the checksum whenever you want to package a
  newer release, e.g.:
  `curl -sL https://github.com/dani-77/utumno/archive/refs/tags/<version>.tar.gz | sha256sum`.
- `quickshell` itself, plus everything else in `depends`, is already
  packaged in void-packages, so `xbps-src`/`xbps-install` pull it in
  automatically. Optional pieces (a wallpaper daemon, PAM for the lock
  screen, `elogind` for the session menu — see the
  [technical documentation](../doc/README.md#dependencies-void-linux)) are
  left out of `depends` since they're either already part of a typical
  desktop setup or a matter of choosing one of several alternatives.
- A ready-built binary is also kept in sync as part of the
  [`d77void/srcpkgs-d77`](https://github.com/d77void/srcpkgs-d77) collection,
  served from its SourceForge repo — no local build needed:

  ```sh
  sudo sh -c 'echo "repository=https://sourceforge.net/projects/d77void/files/d77void-repo" >> /etc/xbps.d/d77void.conf'
  sudo xbps-install -S
  sudo xbps-install utumno
  ```
