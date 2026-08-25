#!/usr/bin/env bash
# Build the wrangler .deb from a tree produced by install-tree.sh.
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "usage: $0 <tree-dir> <version> <arch> <outdir>" >&2
    exit 2
fi

tree="$1"
version="$2"
arch="$3"
outdir="$4"

if [ ! -d "$tree/node_modules/wrangler" ]; then
    echo "::error::no wrangler tree at $tree" >&2
    exit 1
fi

pkgdir=$(mktemp -d)
# mktemp -d gives 0700. dpkg does not apply metadata to directories that already
# exist on the target, so / is unaffected either way, but lintian flags it.
chmod 755 "$pkgdir"

install -d -m 755 "$pkgdir/DEBIAN" "$pkgdir/usr/bin" "$pkgdir/usr/lib/wrangler" \
    "$pkgdir/usr/share/doc/wrangler"

# -a keeps the relative symlinks npm puts in node_modules/.bin.
cp -a "$tree/node_modules" "$pkgdir/usr/lib/wrangler/node_modules"

cat > "$pkgdir/usr/bin/wrangler" <<'WRAPPER'
#!/bin/sh
exec node /usr/lib/wrangler/node_modules/wrangler/bin/wrangler.js "$@"
WRAPPER
chmod 755 "$pkgdir/usr/bin/wrangler"

cat > "$pkgdir/DEBIAN/control" <<CONTROL
Package: wrangler
Version: ${version}
Architecture: ${arch}
Maintainer: li-ruijie <1547237+li-ruijie@users.noreply.github.com>
Depends: nodejs (>= 22)
Homepage: https://developers.cloudflare.com/workers/wrangler/
Description: Cloudflare Workers command line interface
 wrangler initialises, develops, and deploys Cloudflare Workers, Pages
 projects, and the storage bindings around them.
 .
 Upstream publishes wrangler only to npm, as a bundle that still resolves its
 dependencies at run time. This package vendors the published release together
 with its production dependencies, including the workerd runtime that
 "wrangler dev" executes Workers on, so nothing is fetched at install time.
Section: misc
Priority: optional
CONTROL

# wrangler ships no LICENSE file in its npm tarball, so the copyright file
# records the dual licence its package.json declares.
cat > "$pkgdir/usr/share/doc/wrangler/copyright" <<COPYRIGHT
Upstream-Name: wrangler
Source: https://github.com/cloudflare/workers-sdk

Files: usr/lib/wrangler/*
Copyright: Cloudflare, Inc. and the wrangler contributors
License: MIT OR Apache-2.0
 wrangler and its bundled dependencies are distributed under the terms
 declared by each package. wrangler itself is "MIT OR Apache-2.0".

Files: usr/bin/wrangler
Copyright: li-ruijie
License: AGPL-3.0-or-later
 The packaging in this repository is licensed under the GNU Affero General
 Public License version 3 or later. On Debian systems the full text is at
 /usr/share/common-licenses/AGPL-3.
COPYRIGHT
chmod 644 "$pkgdir/usr/share/doc/wrangler/copyright"

mkdir -p "$outdir"
deb="$outdir/wrangler_${version}_${arch}.deb"

# --root-owner-group, or the archive records the runner account as the owner of
# /usr/bin/wrangler and dpkg applies that on install.
dpkg-deb --root-owner-group --build "$pkgdir" "$deb"
rm -rf "$pkgdir"

ls -la "$deb"
dpkg-deb -I "$deb"
