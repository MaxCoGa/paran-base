#!/usr/bin/env python3
"""
Generate JSON matrix from pkg/pkg_list
Usage: scripts/make-matrix.py > /tmp/matrix.json
"""
import json
import os

rows = []
pkg_filter = os.environ.get('PACKAGE_INPUT', '')
try:
    with open('pkg/pkg_list', 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            name = parts[0]
            src = parts[1] if len(parts) > 1 else ''
            deps = parts[2:] if len(parts) > 2 else []
            if pkg_filter:
                if name == pkg_filter:
                    rows.append({'name': name, 'src': src, 'deps': deps})
                    break
                else:
                    continue
            else:
                rows.append({'name': name, 'src': src, 'deps': deps})
except FileNotFoundError:
    pass
print(json.dumps(rows))
