#!/usr/bin/env python3
"""
Generate JSON matrix from pkg/pkg_list
Usage: scripts/make-matrix.py > /tmp/matrix.json
"""
import json
import os
from collections import defaultdict, deque

PKG_LIST_PATH = 'pkg/pkg_list'
pkg_filter = os.environ.get('PACKAGE_INPUT', '').strip()

def read_pkg_list(path):
    pkgs = {}
    try:
        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                parts = line.split()
                name = parts[0]
                src = parts[1] if len(parts) > 1 else ''
                deps = parts[2:] if len(parts) > 2 else []
                pkgs[name] = {'name': name, 'src': src, 'deps': deps}
    except FileNotFoundError:
        pass
    return pkgs

def topo_sort(pkgs, selected=None):
    # Build adjacency and in-degree
    adj = defaultdict(list)
    indeg = defaultdict(int)
    for name, info in pkgs.items():
        indeg.setdefault(name, 0)
        for d in info['deps']:
            # only consider deps that are package names in pkgs
            if d in pkgs:
                adj[d].append(name)
                indeg[name] += 1

    # Choose starting nodes (zero indegree)
    q = deque([n for n in pkgs if indeg.get(n,0) == 0])
    order = []
    while q:
        n = q.popleft()
        order.append(n)
        for m in adj.get(n, []):
            indeg[m] -= 1
            if indeg[m] == 0:
                q.append(m)

    # If cycle detected (order doesn't include all pkgs), raise
    if len(order) != len(pkgs):
        # find cycle nodes
        missing = set(pkgs.keys()) - set(order)
        raise SystemExit('Dependency cycle detected or missing packages: ' + ','.join(sorted(missing)))

    # If selected is provided, compute transitive closure of selected deps
    if selected:
        # compute reverse deps mapping for selecting dependencies
        needed = set()
        stack = [selected]
        while stack:
            cur = stack.pop()
            if cur in needed:
                continue
            needed.add(cur)
            # add its declared deps (only those that are in pkgs)
            for d in pkgs.get(cur, {}).get('deps', []):
                if d in pkgs and d not in needed:
                    stack.append(d)
        # keep only items in order that are in needed
        filtered = [pkgs[n] for n in order if n in needed]
        return filtered

    return [pkgs[n] for n in order]

pkgs = read_pkg_list(PKG_LIST_PATH)

if not pkgs:
    print(json.dumps([]))
else:
    if pkg_filter:
        if pkg_filter not in pkgs:
            # If user passed a package_input not in pkg_list, return empty to skip builds
            print(json.dumps([]))
        else:
            ordered = topo_sort(pkgs, selected=pkg_filter)
            print(json.dumps(ordered))
    else:
        ordered = topo_sort(pkgs, selected=None)
        print(json.dumps(ordered))
