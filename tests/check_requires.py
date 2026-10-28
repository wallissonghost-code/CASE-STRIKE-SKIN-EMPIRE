#!/usr/bin/env python3
"""Confere se todo require(...) do projeto aponta para um módulo existente na árvore do Rojo."""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
# raiz do Rojo -> caminho no disco
MOUNTS = {
    ("ReplicatedStorage", "Shared"): "src/shared",
    ("ServerScriptService", "Server"): "src/server",
    ("StarterPlayer", "StarterPlayerScripts", "Client"): "src/client",
}


def instance_path(file_path):
    rel = os.path.relpath(file_path, ROOT).replace(os.sep, "/")
    for inst, disk in MOUNTS.items():
        if rel.startswith(disk + "/"):
            rest = rel[len(disk) + 1:]
            name = re.sub(r"(\.server|\.client)?\.lua$", "", rest)
            return list(inst) + name.split("/")
    return None


def exists(parts):
    for inst, disk in MOUNTS.items():
        n = len(inst)
        if tuple(parts[:n]) == inst:
            sub = "/".join(parts[n:])
            base = os.path.join(ROOT, disk, sub)
            for suffix in (".lua", ".server.lua", ".client.lua"):
                if os.path.isfile(base + suffix):
                    return True
            return os.path.isdir(base)
    return False


def resolve(expr, here, local_aliases):
    expr = expr.strip()
    expr = re.sub(r":WaitForChild\(\"([^\"]+)\"(?:,\s*\d+)?\)", r".\1", expr)
    tokens = expr.split(".")
    head = tokens[0]
    if head == "script":
        cur = list(here)
        tokens = tokens[1:]
    elif head in local_aliases:
        cur = list(local_aliases[head])
        tokens = tokens[1:]
    else:
        return None
    for t in tokens:
        if t == "Parent":
            cur = cur[:-1]
        else:
            cur.append(t)
    return cur


def main():
    failures = 0
    checked = 0
    for base, _, files in os.walk(os.path.join(ROOT, "src")):
        for name in files:
            if not name.endswith(".lua"):
                continue
            path = os.path.join(base, name)
            here = instance_path(path)
            src = open(path, encoding="utf-8").read()
            aliases = {}
            # local X = script.Parent... / ReplicatedStorage.Shared / game:GetService("ReplicatedStorage")
            services = {}
            for m in re.finditer(r'local (\w+) = game:GetService\("(\w+)"\)', src):
                services[m.group(1)] = [m.group(2)]
            aliases.update(services)
            for m in re.finditer(r"local (\w+) = ((?:script|\w+)(?:\.\w+|:WaitForChild\(\"\w+\"(?:,\s*\d+)?\))*)\s*$", src, re.M):
                if "require" in m.group(2):
                    continue
                r = resolve(m.group(2), here, aliases)
                if r:
                    aliases[m.group(1)] = r
            for m in re.finditer(r"require\(([^()]*(?:\([^()]*\)[^()]*)*)\)", src):
                expr = m.group(1)
                r = resolve(expr, here, aliases)
                if r is None:
                    continue
                checked += 1
                if not exists(r):
                    failures += 1
                    print(f"  ERRO {os.path.relpath(path, ROOT)}: require({expr}) -> {'.'.join(r)}")
    print(f"[requires] {checked} verificados, {failures} com erro")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
