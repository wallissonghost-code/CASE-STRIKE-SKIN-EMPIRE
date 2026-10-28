#!/usr/bin/env python3
"""Gera a prévia 3D do navegador (preview/case-strike-3d.html) a partir das configs do jogo."""
import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
out_json = os.path.join(HERE, "web_data.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "export_web_data.py"), out_json])
d = open(out_json, encoding="utf-8").read()
js = "\n".join(open(os.path.join(HERE, f), encoding="utf-8").read() for f in ["logic.js", "world.js", "ui.js", "main.js"])
html = open(os.path.join(HERE, "template.html"), encoding="utf-8").read().replace("/*DATA*/", d).replace("/*GAME*/", js)
os.makedirs(os.path.join(ROOT, "preview"), exist_ok=True)
dst = os.path.join(ROOT, "preview", "case-strike-3d.html")
open(dst, "w", encoding="utf-8").write(html)
os.remove(out_json)
print("gerado:", dst)
