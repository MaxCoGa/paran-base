sudo bash ./scripts/install-gcc-from-dir.sh /workspaces/gcc-install --prefix /opt/gcc-14.1.0 --system --force-links
sudo bash scripts/uninstall-gcc-from-dir.sh --prefix /opt/gcc-14.1.0 --remove-tree --yes


pack it:
./scripts/pack-paranpackage.sh pkg/gcc pkg/gcc-14.1.0.tar.gz

./pp a gcc 14.1.0 /workspaces/paran-base/pkg/gcc-14.1.0.tar.gz 4cc528d44a11d39a07caa50182347637ef776fd867afdaa18e93d58daa297436

$HOME/pp/opt/gcc-14.1.0/bin/gcc t.c -o t && ./t && echo OK