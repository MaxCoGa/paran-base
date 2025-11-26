# paran-base

## Release pipeline (GitHub Actions)

The `release` workflow is modular and package-driven. It reads `pkg/pkg_list`,
builds each package listed there (one matrix job per package), packs the
package with `./scripts/pack-paranpackage.sh`, and publishes a single GitHub
release containing all produced paranpackage tarballs.

## PACKAGING (conventions)

This section formalizes the `pkg_list` and `BUILD` conventions used by the
release pipeline. Treat this as the canonical packaging guidance (same
content as a `PACKAGING.md` file, but embedded here for convenience).

Package index (`pkg/pkg_list`)
- Format: one entry per line, whitespace-separated tokens. Lines starting with
  `#` are comments and empty lines are ignored.
- Tokens: `package_name [source] [extra...]`
  - `package_name`: directory under `pkg/` containing the package files.
  - `source` (optional): either a version (e.g. `14.1.0`) or a full URL to
    a source tarball. `BUILD` scripts should accept either form.
  - `extra`: optional additional URLs or metadata; package `BUILD` may parse
    these if needed.

MANIFEST keys (package-level)
- `name:` The package name.
- `version:` Package version.
- `description:` Short description.
- `install:` Relative path to install script (e.g. `install.sh`).
- `uninstall:` Relative path to uninstall script (e.g. `uninstall.sh`).
- `helper:` (optional) Space-separated helper files that should be copied
  into `pp_info/<pkg>/` at install time and preserved for uninstall. Example:

  ```text
  helper: uninstall-from-dir.sh uninstall.sh
  ```

`pkg/*/BUILD` contract (detailed)
- Signature: `BUILD WORKDIR SOURCE_OR_VERSION RELEASE_TAG`
- Purpose: obtain or produce a staged payload for the package and place it
  under `pkg/<name>/files/`. For binary packages this commonly means a
  prebuilt `usr/` tree (so `pkg/<name>/files/usr/...` exists). For source
  packages BUILD may run configure/make/install into a DESTDIR and then copy
  the staged tree into `pkg/<name>/files/`.
- Expectations:
  - BUILD must be idempotent: re-running should replace `pkg/<name>/files/`
    with the latest staged output.
  - BUILD should not create the final paranpackage tarball — the repacker
    (`./scripts/pack-paranpackage.sh`) handles packaging.
  - BUILD should exit non-zero on failure so CI will mark the job failed.

Packaging steps (how the CI uses these pieces)
1. `generate-matrix` reads `pkg/pkg_list` and builds a job matrix.
2. For each package CI runs `pkg/<name>/BUILD WORKDIR SRC RELEASE_TAG`.
3. CI runs `./scripts/pack-paranpackage.sh pkg/<name> <out-tarball>` to
   create a complete paranpackage containing `MANIFEST`, `install.sh`,
   `uninstall.sh`, helpers, and the `files/` payload.
4. The workflow uploads all produced tarballs as part of a single GitHub
   release (glob `/tmp/paranbuild/release/*`).

Example minimal `MANIFEST`:

```
name: helloworld
version: 1.0.0
description: Simple hello package
install: install.sh
uninstall: uninstall.sh
# helper: uninstall-from-dir.sh
```

Tips
- Use `helper:` to preserve any scripts needed at uninstall time; `pp` will
  copy those into `pp_info/<pkg>/` and remove them on uninstall.

Quick overview
- Matrix generation: the workflow reads `pkg/pkg_list` and creates a build
  matrix entry for each package.

```mermaid
flowchart TD
  Checkout["Checkout repo"] --> Matrix["Generate package matrix\n(pkg/pkg_list)"]
  Matrix --> Build["Matrix: run pkg/<name>/BUILD\n(per-package job)"]
  Build --> Stage["Stage payload under pkg/<name>/files/\n(e.g. usr/ tree)"]
  Stage --> Pack["Pack paranpackage with\n./scripts/pack-paranpackage.sh"]
  Pack --> Collect["Collect tarballs in $RELEASEDIR"]
  Collect --> Release["Create GitHub release\n(upload /tmp/paranbuild/release/*)"]
  Release --> Done["Done"]

  classDef step fill:#f9f,stroke:#333,stroke-width:1px;
  class Checkout,Matrix,Build,Stage,Pack,Collect,Release step;
```
- Per-package build: for each package the runner calls `pkg/<name>/BUILD`
  with arguments `WORKDIR SOURCE_OR_VERSION RELEASE_TAG`. `BUILD` should
  stage the package payload under `pkg/<name>/files/` (for example a `usr/`
  tree for prebuilt binaries).
- Packing: the workflow runs `./scripts/pack-paranpackage.sh pkg/<name> <out>` to
  produce a valid paranpackage tarball that includes `MANIFEST`, scripts,
  helpers and the `files/` payload.
- Release: the workflow publishes a single GitHub release for the tag and
  uploads the entire release directory glob (e.g. `/tmp/paranbuild/release/*`).

pkg_list format
- File: `pkg/pkg_list`
- Each non-empty, non-comment line is a whitespace-separated entry where the
  first token is the package name (directory under `pkg/`) and the second
  token is an optional source identifier (either a version like `14.1.0` or a
  full tarball URL). Additional tokens are accepted but currently ignored by
  default.

Example `pkg/pkg_list`:

```
gcc 14.1.0
mypkg https://example.com/mypkg-1.2.3.tar.gz
```

`pkg/*/BUILD` contract
- Signature: `BUILD WORKDIR SOURCE_OR_VERSION RELEASE_TAG`
- Responsibility: download/build or stage artifacts and place the final
  payload under `pkg/<name>/files/`. Do NOT create the final paranpackage
  tarball; the repository packer will do that.

Local testing
- Build and stage a package locally (example for `gcc`):

```bash
# run BUILD to produce pkg/gcc/files/usr/
cd pkg/gcc
./BUILD /tmp/paranbuild 14.1.0 v0.0.1

# from repo root, create paranpackage tarball
./scripts/pack-paranpackage.sh pkg/gcc /tmp/paranbuild/release/gcc-v0.0.1.tar.gz

# optionally add and install with the local pp binary
./temp/pp/pp a gcc 14.1.0 /tmp/paranbuild/release/gcc-v0.0.1.tar.gz <sha256>
./temp/pp/pp i gcc
./temp/pp/pp r gcc
```

Adding a new package
1. Create `pkg/<name>/` containing `MANIFEST`, `install.sh`, `uninstall.sh`,
   and a `BUILD` helper that follows the contract above.
2. Add a line to `pkg/pkg_list` with the package name and optional source.