#!/usr/bin/env bash
# Install a production-only wrangler dependency tree into a target directory.
#
# wrangler is published to npm as a bundle that still requires its dependencies
# at run time, so the published tarball on its own exits with "Cannot find
# module 'esbuild'". The tree this produces is what actually runs.
#
# npm resolves optionalDependencies against the platform it runs on, and the
# native pieces (workerd, esbuild, sharp) are all optional platform packages, so
# this has to run on the platform being packaged. Do not cross-build.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <version> <target-dir>" >&2
    exit 2
fi

version="$1"
target="$2"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error::not a wrangler release version: $version" >&2
    exit 1
fi

mkdir -p "$target"

# A private manifest keeps npm from walking up to a parent package.json and
# installing into the checkout instead of the target.
cat > "$target/package.json" <<MANIFEST
{
  "name": "wrangler-vendored",
  "version": "$version",
  "private": true,
  "description": "wrangler $version with its production dependencies"
}
MANIFEST

npm install --prefix "$target" --omit=dev --no-audit --no-fund "wrangler@$version"

# The lockfile describes this build only and is noise in the shipped tree.
rm -f "$target/package-lock.json"

# Run the CLI rather than reading package.json. That proves every dependency
# resolves from inside the tree, which reading a version string does not.
installed=$(cd "$target" && node node_modules/wrangler/bin/wrangler.js --version)
if [ "$installed" != "$version" ]; then
    echo "::error::tree reports wrangler '$installed', expected '$version'" >&2
    exit 1
fi

echo "Installed and verified wrangler $installed in $target"
