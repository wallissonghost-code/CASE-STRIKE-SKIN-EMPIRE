#!/usr/bin/env python3
"""Gera docs/CATALOGO.md (caixas, skins, valores, chances e renda) a partir de src/shared/Config."""
import os
import sys

from lupa import LuaRuntime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tests"))


def main():
    src = open(os.path.join(ROOT, "tests", "harness.py"), encoding="utf-8").read()
    prelude = src[src.index('prelude = r"""') + len('prelude = r"""'):src.index('    """\n    lua.execute(prelude)')]
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().__readfile = lambda p: open(os.path.join(ROOT, "src", p + ".lua"), encoding="utf-8").read()
    lua.execute(prelude)
    out = lua.execute(r'''
    local Skins = shared_module("Config/SkinDefinitions")
    local Cases = shared_module("Config/CaseDefinitions")
    local R = shared_module("Config/RarityConfig")
    local P = shared_module("Logic/Probability")
    local B = shared_module("Logic/BankMath")
    local lines = { "# Catálogo de caixas e skins", "", "Gerado por `python3 tools/gen_catalog.py` a partir de `src/shared/Config` (valores iniciais de balanceamento).", "" }
    for _, c in ipairs(Cases.List) do
      local t = P.computeTable(c, 0)
      local shown = P.displayPercents(t, 3)
      local ev = P.expectedValue(t, Skins)
      table.insert(lines, string.format("## %s — ₵ %d (nível %d)", c.name, c.price, c.requiredLevel))
      table.insert(lines, string.format("%s • %s. Valor esperado por abertura: %.1f (%.1f%% do preço).", c.collectionName, c.theme, ev, ev / c.price * 100))
      table.insert(lines, "")
      table.insert(lines, "| ID | Skin | Categoria | Raridade | Valor | Chance | Renda no banco |")
      table.insert(lines, "|---|---|---|---|---:|---:|---:|")
      for i, e in ipairs(t) do
        local s = Skins.ById[e.skinId]
        table.insert(lines, string.format("| %s | %s — %s | %s | %s | %d | %.3f%% | %.4f/s |", s.id, s.weaponName, s.finish, Skins.Categories[s.category].displayName, R.Rarities[s.rarity].displayName, s.value, shown[i], B.baseIncome(s)))
      end
      table.insert(lines, "")
    end
    return table.concat(lines, "\n")
    ''')
    path = os.path.join(ROOT, "docs", "CATALOGO.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(out + "\n")
    print("gerado:", path)


if __name__ == "__main__":
    main()
