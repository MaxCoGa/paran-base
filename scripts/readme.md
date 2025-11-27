sudo bash ./scripts/install-gcc-from-dir.sh /workspaces/gcc-install --prefix /opt/gcc-14.1.0 --system --force-links
sudo bash scripts/uninstall-gcc-from-dir.sh --prefix /opt/gcc-14.1.0 --remove-tree --yes


pack it:
./scripts/pack-paranpackage.sh pkg/gcc pkg/gcc-14.1.0.tar.gz

./pp a gcc 14.1.0 /workspaces/paran-base/pkg/gcc-14.1.0.tar.gz 4cc528d44a11d39a07caa50182347637ef776fd867afdaa18e93d58daa297436

$HOME/pp/opt/gcc-14.1.0/bin/gcc t.c -o t && ./t && echo OK





PACKAGE_INPUT=acl python3 scripts/make-matrix.py | jq


python3 - <<'PY'
try:
    import yaml
except Exception:
    import subprocess, sys
    print('PyYAML missing; installing...')
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--quiet', '--user', 'pyyaml'])
    import yaml
from yaml import safe_load
with open('.github/workflows/releases.yml') as f:
    safe_load(f)
print('YAML parse: OK')
PY