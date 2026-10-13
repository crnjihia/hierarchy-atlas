#!/usr/bin/env python3
"""
Hierarchy Atlas Benchmark Orchestration Suite
Executes pgbench across all 4 hierarchical models for:
- Subtree Fetch (Read)
- Ancestor Lookup (Read)
- Move Subtree (Write)
"""

import subprocess
import re
import sys

BENCHMARKS = [
    # (Category, Model, Script)
    ("Subtree Fetch", "Adjacency List", "subtree_fetch_adj.sql"),
    ("Subtree Fetch", "Nested Sets", "subtree_fetch_nested.sql"),
    ("Subtree Fetch", "Closure Table", "subtree_fetch_closure.sql"),
    ("Subtree Fetch", "ltree", "subtree_fetch_ltree.sql"),
    ("Ancestor Lookup", "Adjacency List", "ancestor_lookup_adj.sql"),
    ("Ancestor Lookup", "Nested Sets", "ancestor_lookup_nested.sql"),
    ("Ancestor Lookup", "Closure Table", "ancestor_lookup_closure.sql"),
    ("Ancestor Lookup", "ltree", "ancestor_lookup_ltree.sql"),
    ("Move Subtree", "Adjacency List", "move_subtree_adj.sql"),
    ("Move Subtree", "Nested Sets", "move_subtree_nested.sql"),
    ("Move Subtree", "Closure Table", "move_subtree_closure.sql"),
    ("Move Subtree", "ltree", "move_subtree_ltree.sql"),
]

def run_bench(script, duration=10, clients=10, threads=2):
    cmd = [
        "docker", "compose", "exec", "-T", "db",
        "pgbench", "-U", "dev", "-d", "hierarchy_atlas",
        "-n",
        "-c", str(clients),
        "-j", str(threads),
        "-T", str(duration),
        "-f", f"/benchmarks/{script}"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    out = res.stdout + res.stderr
    
    tps_match = re.search(r"tps = ([\d\.]+)", out)
    latency_match = re.search(r"latency average = ([\d\.]+) ms", out)
    
    tps = float(tps_match.group(1)) if tps_match else 0.0
    latency = float(latency_match.group(1)) if latency_match else 0.0
    return tps, latency

def main():
    print("=" * 70)
    print("HIERARCHY ATLAS PGBENCH BENCHMARK SUITE")
    print("=" * 70)
    
    results = []
    for cat, model, script in BENCHMARKS:
        print(f"Running {cat} for {model} ({script})...", flush=True)
        # 10s run for reads, 5s for writes
        dur = 5 if cat == "Move Subtree" else 8
        clients = 5 if cat == "Move Subtree" else 10
        tps, latency = run_bench(script, duration=dur, clients=clients, threads=2)
        print(f"  -> TPS: {tps:.2f}, Latency: {latency:.3f} ms")
        results.append({
            "category": cat,
            "model": model,
            "script": script,
            "tps": tps,
            "latency": latency
        })
        
    print("\n" + "=" * 70)
    print("FINAL BENCHMARK RESULTS")
    print("=" * 70)
    for r in results:
        print(f"{r['category']:<18} | {r['model']:<15} | {r['tps']:>10.2f} TPS | {r['latency']:>8.3f} ms")

if __name__ == "__main__":
    main()
