#!/usr/bin/env bash
# Install the built .deb and confirm the packaged CLI and runtime both run.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <deb> <expected-version>" >&2
    exit 2
fi

deb="$1"
version="$2"

# --force-depends: the package declares nodejs (>= 22) and the Ubuntu runner's
# archive carries 18, so apt cannot satisfy it here. The runner's own Node 22 is
# on PATH and that is what /usr/bin/wrangler execs, so the vendored tree is
# still exercised for real. Whether an archive can satisfy the dependency is a
# property of the target distribution rather than of this package.
sudo dpkg -i --force-depends "$deb"

node --version

got=$(wrangler --version)
if [ "$got" != "$version" ]; then
    echo "::error::installed wrangler reported '$got', expected '$version'" >&2
    exit 1
fi

# --version never loads workerd, so it would pass on a tree with the runtime
# missing. workerd is the largest vendored piece and the reason this is packaged
# at all, so check it separately.
workerd=$(find /usr/lib/wrangler/node_modules/@cloudflare -maxdepth 3 \
    -type f -name workerd -print -quit)
if [ -z "$workerd" ]; then
    echo "::error::no workerd binary in the installed tree" >&2
    exit 1
fi
"$workerd" --version

echo "Smoke test passed: wrangler $got"
