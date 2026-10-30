#!/usr/bin/env python3
"""
Gera MysteryMachine.rbxlx a partir de src/ (mesmo mapeamento do default.project.json),
para abrir direto no Roblox Studio sem Rojo.

Uso: python3 tools/build_place.py [saida.rbxlx]
"""
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:06d}"


def cdata(text):
    # "]]>" não pode aparecer dentro de CDATA: divide em dois blocos
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, children="", source=None, extra=""):
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    props += extra
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{props}</Properties>{children}</Item>\n'


def folder_items(path):
    out = ""
    for name in sorted(os.listdir(path)):
        full = os.path.join(path, name)
        if os.path.isdir(full):
            out += item("Folder", name, folder_items(full))
        elif name.endswith(".lua"):
            src = open(full, encoding="utf-8").read()
            if name.endswith(".server.lua"):
                out += item("Script", name[: -len(".server.lua")], source=src)
            elif name.endswith(".client.lua"):
                out += item("LocalScript", name[: -len(".client.lua")], source=src)
            else:
                out += item("ModuleScript", name[: -len(".lua")], source=src)
    return out


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "MysteryMachine.rbxlx")
    src = os.path.join(ROOT, "src")
    body = ""
    body += item("ReplicatedStorage", "ReplicatedStorage", item("Folder", "Shared", folder_items(os.path.join(src, "shared"))))
    body += item("ServerScriptService", "ServerScriptService", item("Folder", "Server", folder_items(os.path.join(src, "server"))))
    body += item(
        "StarterPlayer",
        "StarterPlayer",
        item("StarterPlayerScripts", "StarterPlayerScripts", item("Folder", "Client", folder_items(os.path.join(src, "client")))),
    )
    xml = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n' + body + "</roblox>\n"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"gerado: {out_path} ({len(xml) // 1024} KB, {_ref} instâncias)")


if __name__ == "__main__":
    main()
