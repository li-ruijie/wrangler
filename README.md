# wrangler packages

Builds Windows and Debian packages of Cloudflare's `wrangler` for the scoop bucket at
https://github.com/li-ruijie/scoop and the APT repository at https://li-ruijie.github.io/apt/.
Upstream publishes wrangler only to npm, so there is no binary release to repackage.

## Assets

┌───────────────────────────────┬───────────────┬────────────────────────────────────────────┐
│ Asset                         │ Architectures │ Consumer                                   │
├───────────────────────────────┼───────────────┼────────────────────────────────────────────┤
│ `wrangler-windows-x64.zip`    │ x64           │ scoop bucket, `li-ruijie/scoop`            │
│ `wrangler_<ver>_<arch>.deb`   │ amd64, arm64  │ APT repository, `li-ruijie/apt`            │
│ `SHA256SUMS.txt`              │               │ scoop autoupdate hash extraction           │
└───────────────────────────────┴───────────────┴────────────────────────────────────────────┘

Releases are tagged `v<version>` with the upstream wrangler version, so the scoop manifest tracks
this repository with a plain `"checkver": "github"`.

## Why the npm tarball alone is not enough

`wrangler-<ver>.tgz` holds a bundle that still resolves its dependencies at run time. Extracted on
its own it exits immediately:

```
Error: Cannot find module 'esbuild'
```

A production install adds 34 packages. The platform-specific ones carry the native pieces, namely
`workerd` (the runtime that `wrangler dev` executes Workers on), `esbuild`, and `sharp`. npm selects
those against the platform it runs on, so every target is installed on its own runner and nothing is
cross-built.

## Size

Vendoring the runtime accounts for most of the payload. A Windows tree measures 184 MB installed, of
which `@cloudflare/workerd-windows-64` is 93 MB and `@img/sharp-win32-x64` is 19 MB. The Linux
`workerd` packages are larger again, 145 MB for amd64 and 149 MB for arm64 as npm reports them, so
these `.deb` files are the largest in the APT repository by a wide margin.

## Node

wrangler requires Node 22 or newer, so the `.deb` declares `Depends: nodejs (>= 22)`. Debian 12
ships 18, so the package needs a newer Node from NodeSource or an equivalent source. No interpreter
is bundled, since a second Node installation appearing on the target machine is worse than a
dependency that refuses to install and says why.

## Windows entry point

The archive is flat and carries `wrangler.cmd` beside `node_modules`, so the scoop manifest needs no
`extract_dir`. Scoop's `shim()` has no branch for `.js`, so a JavaScript entry point cannot be
shimmed directly. Using `%~dp0` in the launcher keeps it working through the `apps/wrangler/current`
junction and from anywhere the archive is unpacked.

## Building

The workflow runs daily and can be dispatched manually with a `version` override and a `force` flag.
It resolves the latest wrangler from the npm registry and skips the build when a release for that
version already exists.

The packaging scripts run standalone:

```sh
scripts/install-tree.sh <version> <target-dir>
scripts/package-deb.sh <tree-dir> <version> <arch> <outdir>
scripts/smoke-test.sh <deb> <expected-version>
```

`install-tree.sh` verifies its result by running the packaged CLI rather than by reading a version
string, which is what proves every dependency resolves from inside the tree. `smoke-test.sh` then
runs the installed `workerd` separately, since `wrangler --version` never loads it and would pass on
a tree with the runtime missing.

## Licence

The packaging in this repository is AGPL-3.0-or-later. wrangler itself is MIT OR Apache-2.0, which
the `.deb` records at `/usr/share/doc/wrangler/copyright`.
