# paran-base




## Release pipeline (GitHub Actions)

The `release` workflow builds and packages GCC into a canonical `usr/` staging
tree and uploads the archive as a GitHub release. High-level flow:

```mermaid
flowchart TD
  Checkout["Checkout repo"] --> Setup["Setup build environment"]
  Setup --> Download["Download GCC source & prerequisites"]
  Download --> Configure["Configure (--prefix=/usr)"]
  Configure --> Build["make -j$(nproc)"]
  Build --> Install["make install DESTDIR=\$INSTALL_DIR (staged /usr)"]
  Install --> Package["Package staged usr/ as tar.gz"]
  Package --> Release["Create GitHub release (upload files)"]
  Release --> Done["Done"]

  classDef step fill:#f9f,stroke:#333,stroke-width:1px;
  class Checkout,Setup,Download,Configure,Build,Install,Package,Release step;
```

Notes:
- The workflow now configures GCC with `--prefix=/usr` and uses `DESTDIR` to
  stage the installation under `$WORKDIR/gcc-install/usr`.
- The produced archive contains a `usr/` tree; use `scripts/install-gcc-from-dir.sh`
  (it now auto-detects and accepts a staged `usr/` layout) to install on target
  systems such as Paran OS.
