#!/usr/bin/env python3
"""
Harness de testes fora do Roblox.

1. Verifica a sintaxe de TODOS os arquivos .lua de src/ (o projeto usa um subconjunto de
   Luau compatível com o parser Lua, sem anotações de tipo nem operadores compostos).
2. Carrega os módulos de src/shared com um `require` simulado (script.Parent.X)
   e executa tests/spec.lua, que cobre os testes obrigatórios de lógica.

Uso:  pip install lupa  &&  python3 tests/harness.py

MYSTERY MACHINE: testes de lógica (spec.lua) e servidor + cliente simulados (server_smoke.lua).
"""
import os
import sys

try:
    from lupa import LuaRuntime
except ImportError:
    print("Instale a dependência: pip install lupa")
    sys.exit(2)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "src")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def syntax_check(lua):
    loader = lua.eval("function(src, name) local f, err = load(src, name, 't') return err end")
    failures = []
    count = 0
    for base, _, files in os.walk(SRC):
        for name in sorted(files):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(base, name)
            count += 1
            err = loader(read(path), "@" + os.path.relpath(path, ROOT))
            if err:
                failures.append(err)
    return count, failures


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    count, failures = syntax_check(lua)
    print(f"[sintaxe] {count} arquivos verificados")
    for f in failures:
        print("  ERRO:", f)
    if failures:
        sys.exit(1)

    lua.globals().__readfile = lambda p: read(os.path.join(SRC, p + ".lua"))
    lua.globals().__readtest = lambda: read(os.path.join(ROOT, "tests", "spec.lua"))
    prelude = r"""
    -- shims de funções exclusivas do Luau usadas pelo código compartilhado
    math.clamp = math.clamp or function(x, a, b) if x < a then return a elseif x > b then return b end return x end
    math.round = math.round or function(x) return math.floor(x + 0.5) end
    table.find = table.find or function(t, v) for i, x in ipairs(t) do if x == v then return i end end end
    table.clone = table.clone or function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
    -- tipos do Roblox usados pelas configs compartilhadas (substituídos pelo mock no teste de servidor)
    Color3 = Color3 or { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
    __clock = 1793000000
    DateTime = DateTime or { now = function() return { UnixTimestamp = __clock } end }

    local cache = {}
    local function proxy(path)
        return setmetatable({ __path = path }, {
            __index = function(_, k)
                if k == "Parent" then
                    local parent = string.match(path, "^(.*)/[^/]+$") or ""
                    return proxy(parent)
                end
                if path == "" then return proxy(k) end
                return proxy(path .. "/" .. k)
            end,
        })
    end
    function require(p)
        local path = rawget(p, "__path")
        if cache[path] ~= nil then return cache[path] end
        local src = __readfile(path)
        local env = setmetatable({ script = proxy(path) }, { __index = _G })
        local chunk = assert(load(src, "@" .. path, "t", env))
        local result = chunk()
        cache[path] = result
        return result
    end
    function shared_module(path) return require(proxy("shared/" .. path)) end
    """
    lua.execute(prelude)
    ok = lua.execute("return (load(__readtest(), '@tests/spec.lua', 't'))()")
    if ok is not True:
        sys.exit(1)

    # 3. servidor real em ambiente Roblox simulado (runtime Lua separado)
    sim = LuaRuntime(unpack_returned_tuples=True)
    g = sim.globals()
    g.__readfile = lambda p: read(os.path.join(ROOT, p))

    def listdir(p):
        full = os.path.join(ROOT, p)
        entries = []
        for name in sorted(os.listdir(full)):
            entries.append((name, os.path.isdir(os.path.join(full, name))))
        return sim.table_from([sim.table_from(list(e)) for e in entries])

    g.__listdir = listdir
    sim.execute(prelude.split("local cache = {}")[0])
    sim.execute("__mock = (load(__readfile('tests/roblox_mock.lua'), '@tests/roblox_mock.lua', 't'))()")
    ok = sim.execute("return (load(__readfile('tests/server_smoke.lua'), '@tests/server_smoke.lua', 't'))()")
    if ok is not True:
        sys.exit(1)


if __name__ == "__main__":
    main()
