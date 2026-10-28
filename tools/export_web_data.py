#!/usr/bin/env python3
"""
Exporta as configurações do jogo (src/shared/Config) para JSON, usado pela prévia no navegador.
Funções de configuração (requisitos e benefícios por nível) são avaliadas para cada nível.

Uso: python3 tools/export_web_data.py [saida.json]
"""
import json
import os
import sys

from lupa import LuaRuntime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def to_py(lua, v, depth=0):
    if depth > 12:
        return None
    t = lua.globals().type(v)
    if t == "table":
        keys = list(v.keys())
        if keys and all(isinstance(k, (int, float)) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [to_py(lua, v[k], depth + 1) for k in sorted(keys)]
        out = {}
        for k in keys:
            item = v[k]
            if lua.globals().type(item) == "function":
                continue
            out[str(k)] = to_py(lua, item, depth + 1)
        return out
    if t == "function":
        return None
    return v


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "web_data.json")
    src = open(os.path.join(ROOT, "tests", "harness.py"), encoding="utf-8").read()
    prelude = src[src.index('prelude = r"""') + len('prelude = r"""'):src.index('    """\n    lua.execute(prelude)')]
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().__readfile = lambda p: open(os.path.join(ROOT, "src", p + ".lua"), encoding="utf-8").read()
    lua.execute(prelude)
    m = lambda name: lua.eval('shared_module("%s")' % name)

    rarity = m("Config/RarityConfig")
    skins = m("Config/SkinDefinitions")
    cases = m("Config/CaseDefinitions")
    catalog = m("Config/CaseCatalog")
    econ = m("Config/EconomyConfig")
    bank = m("Config/BankConfig")
    attrs = m("Config/AttributeConfig")
    recipes = m("Config/UpgradeRecipes")
    missions = m("Config/MissionDefinitions")
    prog = m("Config/ProgressionConfig")
    events = m("Config/EventDefinitions")
    zones = m("Config/ZoneConfig")
    potions = m("Config/PotionConfig")
    luck = m("Config/LuckConfig")
    ach = m("Config/AchievementDefinitions")

    bank_up = {}
    for uid in to_py(lua, bank.UpgradeOrder):
        u = bank.Upgrades[uid]
        d = to_py(lua, u)
        d["requiredLevels"] = [u.requiredLevel(l) for l in range(0, u.maxLevel + 1)]
        bank_up[uid] = d

    attr_out = []
    for aid in to_py(lua, attrs.Order):
        a = attrs.Attributes[aid]
        d = to_py(lua, a)
        if a.linkedBankUpgrade:
            mx = bank.Upgrades[a.linkedBankUpgrade].maxLevel
        else:
            mx = a.maxLevel
            d["requiredLevels"] = [a.requiredLevel(l) for l in range(0, mx + 1)]
        d["benefits"] = [a.benefit(l) for l in range(0, mx + 1)]
        attr_out.append(d)

    data = {
        "rarity": {"order": to_py(lua, rarity.Order), "defs": to_py(lua, rarity.Rarities)},
        "skins": to_py(lua, skins.List),
        "categories": to_py(lua, skins.Categories),
        "cases": to_py(lua, cases.List),
        "sections": to_py(lua, catalog.Sections),
        "economy": to_py(lua, econ),
        "bank": {"cfg": {k: to_py(lua, bank[k]) for k in ["K", "Exponent", "MaxIncomePerSkin", "MinIncomePerSkin", "BaseSlots", "MaxSlotsShown", "BaseStorage", "MaxOfflineSeconds"]}, "upgrades": bank_up, "order": to_py(lua, bank.UpgradeOrder)},
        "attributes": attr_out,
        "recipes": to_py(lua, recipes.List),
        "missions": {"daily": to_py(lua, missions.Daily), "weekly": to_py(lua, missions.Weekly), "dailyCount": missions.DailyCount},
        "progression": {
            "xpBase": prog.XpBase, "xpExponent": prog.XpExponent, "maxLevel": prog.MaxLevel,
            "dailyXpCaps": to_py(lua, prog.DailyXpCaps), "titles": to_py(lua, prog.Titles),
            "levelTitleOrder": to_py(lua, prog.LevelTitleOrder),
            "levelRewards": {str(k): to_py(lua, v) for k, v in prog.LevelRewards.items()},
            "dailyRewards": to_py(lua, prog.DailyRewards), "collectionRewards": to_py(lua, prog.CollectionRewards),
            "rebirth": {k: to_py(lua, prog.Rebirth[k]) for k in ["MaxRebirths", "KeepMinTier", "BankEfficiencyPerRebirth", "BankEfficiencyMax", "LuckPerRebirth", "LuckMax", "ConfirmPhrase", "XpBonusPerRebirth", "XpBonusMax", "KeepFavorites", "ExtraBankSlotEvery", "ExtraEquipSlotEvery"]},
            "rebirthReq": [[prog.Rebirth.requiredLevel(n), prog.Rebirth.requiredNetWorth(n)] for n in range(1, 11)],
        },
        "events": {"list": to_py(lua, events.Events), "flash": to_py(lua, events.Flash)},
        "zones": to_py(lua, zones.Zones),
        "potions": {"order": to_py(lua, potions.Order), "defs": to_py(lua, potions.Potions)},
        "luck": {"max": luck.MaxTotalLuck, "tierScale": {str(k): v for k, v in luck.TierScale.items()}},
        "achievements": to_py(lua, ach.List),
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("gerado:", out_path, os.path.getsize(out_path) // 1024, "KB")


if __name__ == "__main__":
    main()
