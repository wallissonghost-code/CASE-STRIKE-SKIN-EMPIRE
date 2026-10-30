-- Modelos 3D estilizados dos 20 objetos, montados só com peças do Roblox (sem IDs externos).
-- Usados no compartimento da máquina, nas vitrines e nos ícones do inventário (ViewportFrame).
-- Cada modelo tem cerca de 2,6 studs, centro em (0,0,0) e PrimaryPart "Root" invisível.

local ItemModels = {}

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local M = Enum.Material
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder

-- peças: { size = {x,y,z}, pos = {x,y,z}, rot = {x,y,z} em graus, color, mat, shape, alpha, wedge }
local function ring(list, radius, count, y, size, color, mat, tiltX)
	for i = 0, count - 1 do
		local a = (i / count) * math.pi * 2
		table.insert(list, {
			size = size,
			pos = { math.cos(a) * radius, y + (tiltX and math.sin(a) * radius * tiltX or 0), math.sin(a) * radius },
			rot = { 0, -math.deg(a), 0 },
			color = color,
			mat = mat,
		})
	end
	return list
end

local Builders = {}

Builders.cup = function()
	return {
		{ size = { 2.0, 1.5, 1.5 }, pos = { 0, 0, 0 }, rot = { 0, 0, 90 }, shape = CYL, color = C(120, 200, 255), mat = M.Glass, alpha = 0.25 },
		{ size = { 0.05, 1.3, 1.3 }, pos = { 0, 0.98, 0 }, rot = { 0, 0, 90 }, shape = CYL, color = C(255, 150, 60) },
		{ size = { 0.25, 1.1, 0.25 }, pos = { 1.05, 0, 0 }, color = C(80, 160, 230) },
		{ size = { 0.4, 0.22, 0.25 }, pos = { 0.85, 0.45, 0 }, color = C(80, 160, 230) },
		{ size = { 0.4, 0.22, 0.25 }, pos = { 0.85, -0.45, 0 }, color = C(80, 160, 230) },
		{ size = { 0.2, 0.2, 0.2 }, pos = { 0.2, 1.3, 0.2 }, rot = { 0, 0, 20 }, color = C(255, 80, 120) },
		{ size = { 0.15, 1.3, 0.15 }, pos = { 0.25, 1.15, 0.15 }, rot = { 0, 0, 20 }, color = C(255, 255, 255) },
	}
end

Builders.ball = function()
	return {
		{ size = { 2.3, 2.3, 2.3 }, pos = { 0, 0, 0 }, shape = BALL, color = C(250, 250, 250) },
		{ size = { 0.35, 2.36, 2.36 }, pos = { 0, 0, 0 }, shape = CYL, color = C(235, 60, 60) },
		{ size = { 0.35, 2.36, 2.36 }, pos = { 0, 0, 0 }, rot = { 0, 90, 0 }, shape = CYL, color = C(50, 110, 235) },
		{ size = { 0.25, 2.34, 2.34 }, pos = { 0, 0, 0 }, rot = { 0, 0, 90 }, shape = CYL, color = C(255, 210, 40) },
	}
end

Builders.toy_car = function()
	local parts = {
		{ size = { 2.6, 0.7, 1.4 }, pos = { 0, -0.2, 0 }, color = C(230, 50, 50) },
		{ size = { 1.4, 0.65, 1.25 }, pos = { -0.2, 0.45, 0 }, color = C(230, 50, 50) },
		{ size = { 1.2, 0.5, 1.28 }, pos = { -0.2, 0.47, 0 }, color = C(170, 220, 255), mat = M.Glass, alpha = 0.2 },
		{ size = { 0.1, 0.2, 0.3 }, pos = { 1.31, -0.1, 0.45 }, color = C(255, 240, 120), mat = M.Neon },
		{ size = { 0.1, 0.2, 0.3 }, pos = { 1.31, -0.1, -0.45 }, color = C(255, 240, 120), mat = M.Neon },
		{ size = { 0.15, 0.1, 1.42 }, pos = { 0.6, 0.16, 0 }, color = C(255, 255, 255) },
	}
	for _, x in ipairs({ -0.85, 0.85 }) do
		for _, z in ipairs({ -0.72, 0.72 }) do
			table.insert(parts, { size = { 0.35, 0.8, 0.8 }, pos = { x, -0.55, z }, rot = { 0, 90, 0 }, shape = CYL, color = C(30, 30, 30) })
		end
	end
	return parts
end

Builders.teddy = function()
	local brown, light = C(160, 105, 60), C(225, 185, 140)
	return {
		{ size = { 1.6, 1.6, 1.6 }, pos = { 0, -0.5, 0 }, shape = BALL, color = brown, mat = M.Fabric },
		{ size = { 1.0, 1.0, 1.0 }, pos = { 0, -0.45, 0.35 }, shape = BALL, color = light, mat = M.Fabric },
		{ size = { 1.25, 1.25, 1.25 }, pos = { 0, 0.75, 0 }, shape = BALL, color = brown, mat = M.Fabric },
		{ size = { 0.5, 0.5, 0.5 }, pos = { -0.5, 1.3, 0 }, shape = BALL, color = brown, mat = M.Fabric },
		{ size = { 0.5, 0.5, 0.5 }, pos = { 0.5, 1.3, 0 }, shape = BALL, color = brown, mat = M.Fabric },
		{ size = { 0.5, 0.4, 0.4 }, pos = { 0, 0.62, 0.52 }, shape = BALL, color = light, mat = M.Fabric },
		{ size = { 0.18, 0.14, 0.14 }, pos = { 0, 0.7, 0.72 }, shape = BALL, color = C(30, 20, 20) },
		{ size = { 0.16, 0.16, 0.16 }, pos = { -0.22, 0.92, 0.52 }, shape = BALL, color = C(20, 20, 20) },
		{ size = { 0.16, 0.16, 0.16 }, pos = { 0.22, 0.92, 0.52 }, shape = BALL, color = C(20, 20, 20) },
		{ size = { 0.6, 0.6, 0.6 }, pos = { -0.85, -0.3, 0.1 }, shape = BALL, color = brown, mat = M.Fabric },
		{ size = { 0.6, 0.6, 0.6 }, pos = { 0.85, -0.3, 0.1 }, shape = BALL, color = brown, mat = M.Fabric },
		{ size = { 0.65, 0.65, 0.65 }, pos = { -0.5, -1.15, 0.3 }, shape = BALL, color = brown, mat = M.Fabric },
		{ size = { 0.65, 0.65, 0.65 }, pos = { 0.5, -1.15, 0.3 }, shape = BALL, color = brown, mat = M.Fabric },
		{ size = { 0.5, 0.25, 0.2 }, pos = { 0, 0.18, 0.55 }, color = C(230, 40, 70) },
	}
end

Builders.headphones = function()
	local dark, accent = C(35, 35, 45), C(160, 80, 255)
	return {
		{ size = { 1.4, 0.28, 0.45 }, pos = { 0, 1.15, 0 }, color = dark },
		{ size = { 0.28, 0.9, 0.45 }, pos = { -0.88, 0.8, 0 }, rot = { 0, 0, -25 }, color = dark },
		{ size = { 0.28, 0.9, 0.45 }, pos = { 0.88, 0.8, 0 }, rot = { 0, 0, 25 }, color = dark },
		{ size = { 0.15, 0.4, 0.3 }, pos = { 0, 1.32, 0 }, color = accent, mat = M.Neon },
		{ size = { 0.25, 0.6, 0.35 }, pos = { -1.05, 0.15, 0 }, color = C(150, 150, 160) },
		{ size = { 0.25, 0.6, 0.35 }, pos = { 1.05, 0.15, 0 }, color = C(150, 150, 160) },
		{ size = { 0.55, 1.2, 1.2 }, pos = { -1.05, -0.5, 0 }, shape = CYL, color = dark },
		{ size = { 0.55, 1.2, 1.2 }, pos = { 1.05, -0.5, 0 }, shape = CYL, color = dark },
		{ size = { 0.1, 0.8, 0.8 }, pos = { -1.36, -0.5, 0 }, shape = CYL, color = accent, mat = M.Neon },
		{ size = { 0.1, 0.8, 0.8 }, pos = { 1.36, -0.5, 0 }, shape = CYL, color = accent, mat = M.Neon },
	}
end

Builders.watch = function()
	return {
		{ size = { 0.75, 2.7, 0.15 }, pos = { 0, 0, -0.1 }, color = C(40, 40, 50) },
		{ size = { 1.3, 1.25, 0.45 }, pos = { 0, 0, 0.05 }, color = C(170, 175, 190), mat = M.Metal },
		{ size = { 1.05, 0.8, 0.05 }, pos = { 0, 0, 0.29 }, color = C(60, 255, 140), mat = M.Neon },
		{ size = { 0.5, 0.12, 0.02 }, pos = { 0, 0.1, 0.32 }, color = C(20, 60, 30) },
		{ size = { 0.35, 0.12, 0.02 }, pos = { 0, -0.12, 0.32 }, color = C(20, 60, 30) },
		{ size = { 0.15, 0.25, 0.15 }, pos = { 0.72, 0.2, 0.05 }, color = C(220, 60, 60) },
	}
end

Builders.gamepad = function()
	local parts = {
		{ size = { 2.4, 0.95, 0.5 }, pos = { 0, 0.15, 0 }, color = C(55, 55, 70) },
		{ size = { 0.9, 0.9, 0.5 }, pos = { -0.95, -0.3, 0 }, shape = BALL, color = C(55, 55, 70) },
		{ size = { 0.9, 0.9, 0.5 }, pos = { 0.95, -0.3, 0 }, shape = BALL, color = C(55, 55, 70) },
		{ size = { 0.5, 0.15, 0.1 }, pos = { -0.75, 0.25, 0.28 }, color = C(20, 20, 25) },
		{ size = { 0.15, 0.5, 0.1 }, pos = { -0.75, 0.25, 0.28 }, color = C(20, 20, 25) },
		{ size = { 0.2, 0.32, 0.32 }, pos = { -0.35, -0.15, 0.3 }, rot = { 0, 90, 0 }, shape = CYL, color = C(20, 20, 25) },
		{ size = { 0.2, 0.32, 0.32 }, pos = { 0.35, -0.15, 0.3 }, rot = { 0, 90, 0 }, shape = CYL, color = C(20, 20, 25) },
	}
	local colors = { C(80, 220, 90), C(230, 60, 60), C(70, 130, 255), C(255, 210, 40) }
	local offsets = { { 0, 0.42 }, { 0.17, 0.25 }, { -0.17, 0.25 }, { 0, 0.08 } }
	for i, o in ipairs(offsets) do
		table.insert(parts, { size = { 0.16, 0.16, 0.16 }, pos = { 0.75 + o[1], o[2], 0.3 }, shape = BALL, color = colors[i], mat = M.Neon })
	end
	return parts
end

Builders.phone = function()
	return {
		{ size = { 1.25, 2.4, 0.2 }, pos = { 0, 0, 0 }, color = C(25, 25, 30) },
		{ size = { 1.08, 2.05, 0.03 }, pos = { 0, 0.05, 0.11 }, color = C(70, 140, 255), mat = M.Neon },
		{ size = { 0.25, 0.25, 0.25 }, pos = { -0.25, 0.35, 0.13 }, color = C(255, 255, 255), mat = M.Neon },
		{ size = { 0.25, 0.25, 0.25 }, pos = { 0.25, 0.35, 0.13 }, color = C(255, 120, 200), mat = M.Neon },
		{ size = { 0.25, 0.25, 0.25 }, pos = { -0.25, -0.15, 0.13 }, color = C(120, 255, 160), mat = M.Neon },
		{ size = { 0.25, 0.25, 0.25 }, pos = { 0.25, -0.15, 0.13 }, color = C(255, 220, 90), mat = M.Neon },
		{ size = { 0.3, 0.05, 0.03 }, pos = { 0, -1.05, 0.12 }, color = C(200, 200, 200) },
		{ size = { 0.15, 0.15, 0.05 }, pos = { 0, 1.1, 0.12 }, shape = BALL, color = C(10, 10, 10) },
	}
end

Builders.drone = function()
	local parts = {
		{ size = { 1.0, 0.45, 1.0 }, pos = { 0, 0, 0 }, color = C(240, 240, 245) },
		{ size = { 2.7, 0.12, 0.18 }, pos = { 0, 0.05, 0 }, rot = { 0, 45, 0 }, color = C(60, 60, 70) },
		{ size = { 2.7, 0.12, 0.18 }, pos = { 0, 0.05, 0 }, rot = { 0, -45, 0 }, color = C(60, 60, 70) },
		{ size = { 0.4, 0.4, 0.4 }, pos = { 0, -0.3, 0.3 }, shape = BALL, color = C(20, 20, 20) },
		{ size = { 0.2, 0.08, 0.08 }, pos = { 0, 0.12, 0.52 }, color = C(80, 255, 120), mat = M.Neon },
	}
	for _, x in ipairs({ -0.95, 0.95 }) do
		for _, z in ipairs({ -0.95, 0.95 }) do
			table.insert(parts, { size = { 0.25, 0.2, 0.2 }, pos = { x, 0.15, z }, rot = { 0, 0, 90 }, shape = CYL, color = C(60, 60, 70) })
			table.insert(parts, { size = { 0.05, 1.0, 1.0 }, pos = { x, 0.28, z }, rot = { 0, 0, 90 }, shape = CYL, color = C(120, 200, 255), alpha = 0.45 })
		end
	end
	return parts
end

Builders.handheld = function()
	local parts = {
		{ size = { 2.7, 1.3, 0.35 }, pos = { 0, 0, 0 }, color = C(30, 190, 180) },
		{ size = { 1.35, 0.9, 0.05 }, pos = { 0, 0.05, 0.19 }, color = C(20, 20, 30) },
		{ size = { 1.2, 0.75, 0.03 }, pos = { 0, 0.05, 0.22 }, color = C(255, 120, 60), mat = M.Neon },
		{ size = { 0.45, 0.13, 0.08 }, pos = { -1.0, 0.05, 0.2 }, color = C(20, 20, 25) },
		{ size = { 0.13, 0.45, 0.08 }, pos = { -1.0, 0.05, 0.2 }, color = C(20, 20, 25) },
		{ size = { 2.75, 0.08, 0.4 }, pos = { 0, 0.62, 0 }, color = C(255, 205, 60), mat = M.Metal },
	}
	table.insert(parts, { size = { 0.2, 0.2, 0.1 }, pos = { 0.95, 0.15, 0.2 }, shape = BALL, color = C(230, 60, 60) })
	table.insert(parts, { size = { 0.2, 0.2, 0.1 }, pos = { 1.15, -0.05, 0.2 }, shape = BALL, color = C(255, 220, 60) })
	return parts
end

Builders.robot = function()
	local grey, dark = C(180, 185, 195), C(70, 75, 90)
	return {
		{ size = { 1.2, 1.1, 0.8 }, pos = { 0, -0.2, 0 }, color = grey, mat = M.Metal },
		{ size = { 0.5, 0.35, 0.05 }, pos = { 0, -0.1, 0.42 }, color = C(255, 90, 90), mat = M.Neon },
		{ size = { 0.95, 0.75, 0.75 }, pos = { 0, 0.75, 0 }, color = grey, mat = M.Metal },
		{ size = { 0.2, 0.2, 0.05 }, pos = { -0.22, 0.8, 0.39 }, color = C(60, 230, 255), mat = M.Neon },
		{ size = { 0.2, 0.2, 0.05 }, pos = { 0.22, 0.8, 0.39 }, color = C(60, 230, 255), mat = M.Neon },
		{ size = { 0.5, 0.08, 0.05 }, pos = { 0, 0.55, 0.39 }, color = dark },
		{ size = { 0.08, 0.4, 0.08 }, pos = { 0, 1.3, 0 }, color = dark },
		{ size = { 0.22, 0.22, 0.22 }, pos = { 0, 1.52, 0 }, shape = BALL, color = C(255, 60, 60), mat = M.Neon },
		{ size = { 0.3, 0.9, 0.3 }, pos = { -0.8, -0.2, 0 }, rot = { 0, 0, 10 }, color = dark },
		{ size = { 0.3, 0.9, 0.3 }, pos = { 0.8, -0.2, 0 }, rot = { 0, 0, -10 }, color = dark },
		{ size = { 0.35, 0.6, 0.35 }, pos = { -0.3, -1.05, 0 }, color = dark },
		{ size = { 0.35, 0.6, 0.35 }, pos = { 0.3, -1.05, 0 }, color = dark },
	}
end

Builders.scooter = function()
	return {
		{ size = { 0.55, 0.14, 2.3 }, pos = { 0, -0.95, 0 }, color = C(255, 80, 170) },
		{ size = { 0.12, 0.12, 2.0 }, pos = { 0, -1.04, 0 }, color = C(0, 255, 230), mat = M.Neon },
		{ size = { 0.15, 2.1, 0.15 }, pos = { 0, 0.05, 1.05 }, rot = { -12, 0, 0 }, color = C(200, 205, 215), mat = M.Metal },
		{ size = { 1.3, 0.14, 0.14 }, pos = { 0, 1.1, 1.25 }, color = C(40, 40, 50) },
		{ size = { 0.25, 0.7, 0.7 }, pos = { 0, -1.05, 1.15 }, shape = CYL, color = C(30, 30, 35) },
		{ size = { 0.25, 0.7, 0.7 }, pos = { 0, -1.05, -1.15 }, shape = CYL, color = C(30, 30, 35) },
		{ size = { 0.28, 0.4, 0.4 }, pos = { 0, -1.05, 1.15 }, shape = CYL, color = C(0, 255, 230), mat = M.Neon },
		{ size = { 0.28, 0.4, 0.4 }, pos = { 0, -1.05, -1.15 }, shape = CYL, color = C(0, 255, 230), mat = M.Neon },
	}
end

Builders.rocket = function()
	local parts = {
		{ size = { 1.8, 0.95, 0.95 }, pos = { 0, -0.1, 0 }, rot = { 0, 0, 90 }, shape = CYL, color = C(245, 245, 250) },
		{ size = { 0.5, 0.75, 0.75 }, pos = { 0, 0.95, 0 }, rot = { 0, 0, 90 }, shape = CYL, color = C(230, 50, 60) },
		{ size = { 0.75, 0.75, 0.75 }, pos = { 0, 1.2, 0 }, shape = BALL, color = C(230, 50, 60) },
		{ size = { 0.4, 0.4, 0.3 }, pos = { 0, 0.25, 0.42 }, shape = BALL, color = C(90, 180, 255), mat = M.Neon },
		{ size = { 0.6, 0.6, 0.6 }, pos = { 0, -1.15, 0 }, shape = BALL, color = C(255, 150, 40), mat = M.Neon },
	}
	for i = 0, 3 do
		local a = i * 90
		local r = math.rad(a)
		table.insert(parts, { size = { 0.1, 0.7, 0.5 }, pos = { math.sin(r) * 0.55, -0.75, math.cos(r) * 0.55 }, rot = { 0, a + 90, 0 }, color = C(230, 50, 60), wedge = true })
	end
	return parts
end

Builders.diamond = function()
	return {
		{ size = { 1.55, 1.55, 1.55 }, pos = { 0, 0, 0 }, rot = { 45, 0, 45 }, color = C(120, 230, 255), mat = M.Glass, alpha = 0.15 },
		{ size = { 0.9, 0.9, 0.9 }, pos = { 0, 0, 0 }, rot = { 45, 45, 0 }, color = C(200, 250, 255), mat = M.Neon },
		{ size = { 1.6, 0.12, 1.6 }, pos = { 0, 0.55, 0 }, rot = { 0, 45, 0 }, color = C(170, 240, 255), mat = M.Glass, alpha = 0.3 },
	}
end

Builders.crown = function()
	local gold = C(255, 200, 40)
	local parts = {
		{ size = { 0.8, 2.1, 2.1 }, pos = { 0, -0.5, 0 }, rot = { 0, 0, 90 }, shape = CYL, color = gold, mat = M.Metal },
		{ size = { 0.82, 1.7, 1.7 }, pos = { 0, -0.48, 0 }, rot = { 0, 0, 90 }, shape = CYL, color = C(150, 20, 40), mat = M.Fabric },
		{ size = { 0.3, 0.3, 0.2 }, pos = { 0, -0.5, 1.05 }, shape = BALL, color = C(230, 30, 50), mat = M.Neon },
	}
	for i = 0, 4 do
		local a = math.rad(i * 72)
		table.insert(parts, { size = { 0.35, 0.8, 0.35 }, pos = { math.sin(a) * 0.9, 0.2, math.cos(a) * 0.9 }, rot = { 0, i * 72, 45 }, color = gold, mat = M.Metal })
		table.insert(parts, { size = { 0.25, 0.25, 0.25 }, pos = { math.sin(a) * 0.9, 0.75, math.cos(a) * 0.9 }, shape = BALL, color = C(90, 170, 255), mat = M.Neon })
	end
	return parts
end

Builders.crystal_dragon = function()
	local crystal, glow = C(120, 220, 255), C(200, 250, 255)
	return {
		{ size = { 0.9, 0.85, 1.7 }, pos = { 0, -0.3, 0 }, color = crystal, mat = M.Glass, alpha = 0.15 },
		{ size = { 0.45, 0.4, 1.1 }, pos = { 0, -0.25, 0 }, color = glow, mat = M.Neon },
		{ size = { 0.45, 0.9, 0.45 }, pos = { 0, 0.3, 0.75 }, rot = { 30, 0, 0 }, color = crystal, mat = M.Glass, alpha = 0.15 },
		{ size = { 0.6, 0.5, 0.8 }, pos = { 0, 0.8, 1.05 }, color = crystal, mat = M.Glass, alpha = 0.15 },
		{ size = { 0.12, 0.12, 0.05 }, pos = { -0.18, 0.9, 1.46 }, color = C(255, 80, 120), mat = M.Neon },
		{ size = { 0.12, 0.12, 0.05 }, pos = { 0.18, 0.9, 1.46 }, color = C(255, 80, 120), mat = M.Neon },
		{ size = { 0.1, 0.45, 0.25 }, pos = { -0.2, 1.2, 0.85 }, rot = { -20, 0, 0 }, color = glow, wedge = true },
		{ size = { 0.1, 0.45, 0.25 }, pos = { 0.2, 1.2, 0.85 }, rot = { -20, 0, 0 }, color = glow, wedge = true },
		{ size = { 0.08, 1.0, 1.3 }, pos = { -0.85, 0.35, -0.1 }, rot = { 0, 0, 35 }, color = C(170, 140, 255), mat = M.Glass, alpha = 0.25, wedge = true },
		{ size = { 0.08, 1.0, 1.3 }, pos = { 0.85, 0.35, -0.1 }, rot = { 0, 0, -35 }, color = C(170, 140, 255), mat = M.Glass, alpha = 0.25, wedge = true },
		{ size = { 0.3, 0.3, 1.1 }, pos = { 0, -0.45, -1.2 }, rot = { 15, 0, 0 }, color = crystal, mat = M.Glass, alpha = 0.15 },
		{ size = { 0.3, 0.45, 0.3 }, pos = { -0.3, -0.9, 0.4 }, color = crystal, mat = M.Glass, alpha = 0.15 },
		{ size = { 0.3, 0.45, 0.3 }, pos = { 0.3, -0.9, 0.4 }, color = crystal, mat = M.Glass, alpha = 0.15 },
	}
end

Builders.cosmic_cube = function()
	local parts = {
		{ size = { 1.9, 1.9, 1.9 }, pos = { 0, 0, 0 }, color = C(60, 20, 120), mat = M.Glass, alpha = 0.55 },
		{ size = { 1.0, 1.0, 1.0 }, pos = { 0, 0, 0 }, rot = { 45, 45, 0 }, color = C(200, 90, 255), mat = M.Neon },
	}
	for _, x in ipairs({ -0.95, 0.95 }) do
		for _, y in ipairs({ -0.95, 0.95 }) do
			for _, z in ipairs({ -0.95, 0.95 }) do
				table.insert(parts, { size = { 0.3, 0.3, 0.3 }, pos = { x, y, z }, shape = BALL, color = C(120, 220, 255), mat = M.Neon })
			end
		end
	end
	return parts
end

Builders.ancient_relic = function()
	local stone, gold = C(140, 130, 100), C(220, 170, 60)
	return {
		{ size = { 1.8, 0.35, 1.2 }, pos = { 0, -1.1, 0 }, color = C(110, 100, 80), mat = M.Slate },
		{ size = { 1.2, 1.7, 0.75 }, pos = { 0, -0.1, 0 }, color = stone, mat = M.Slate },
		{ size = { 1.0, 0.75, 0.7 }, pos = { 0, 1.05, 0 }, color = stone, mat = M.Slate },
		{ size = { 1.26, 0.15, 0.8 }, pos = { 0, 0.62, 0 }, color = gold, mat = M.Metal },
		{ size = { 0.22, 0.12, 0.05 }, pos = { -0.22, 1.1, 0.36 }, color = C(255, 140, 40), mat = M.Neon },
		{ size = { 0.22, 0.12, 0.05 }, pos = { 0.22, 1.1, 0.36 }, color = C(255, 140, 40), mat = M.Neon },
		{ size = { 0.5, 0.5, 0.05 }, pos = { 0, 0.05, 0.39 }, rot = { 0, 0, 45 }, color = C(80, 220, 160), mat = M.Neon },
		{ size = { 0.15, 0.6, 0.15 }, pos = { 0, 1.55, 0 }, color = gold, mat = M.Metal },
	}
end

Builders.galactic_star = function()
	local parts = {
		{ size = { 0.95, 0.95, 0.95 }, pos = { 0, 0, 0 }, shape = BALL, color = C(255, 245, 170), mat = M.Neon },
	}
	for i = 0, 4 do
		local a = math.rad(i * 72)
		table.insert(parts, { size = { 0.5, 1.25, 0.4 }, pos = { math.sin(a) * 0.75, math.cos(a) * 0.75, 0 }, rot = { 0, 0, -i * 72 }, color = C(255, 215, 60), mat = M.Neon })
		table.insert(parts, { size = { 0.22, 0.22, 0.22 }, pos = { math.sin(a) * 1.35, math.cos(a) * 1.35, 0 }, shape = BALL, color = C(150, 120, 255), mat = M.Neon })
	end
	return ring(parts, 1.15, 10, 0, { 0.12, 0.12, 0.3 }, C(120, 180, 255), M.Neon)
end

Builders.secret_artifact = function()
	local parts = {
		{ size = { 1.6, 0.35, 1.6 }, pos = { 0, -1.15, 0 }, color = C(20, 15, 25), mat = M.Slate },
		{ size = { 1.65, 0.08, 0.3 }, pos = { 0, -1.0, 0 }, color = C(255, 40, 60), mat = M.Neon },
		{ size = { 0.3, 0.08, 1.65 }, pos = { 0, -1.0, 0 }, color = C(255, 40, 60), mat = M.Neon },
		{ size = { 1.0, 1.0, 1.0 }, pos = { 0, 0.2, 0 }, shape = BALL, color = C(255, 50, 70), mat = M.Neon },
		{ size = { 0.55, 0.55, 0.55 }, pos = { 0, 0.2, 0 }, rot = { 45, 45, 0 }, color = C(20, 10, 20) },
	}
	ring(parts, 1.15, 12, 0.2, { 0.14, 0.14, 0.35 }, C(255, 200, 220), M.Neon)
	return ring(parts, 0.95, 10, 0.2, { 0.1, 0.1, 0.3 }, C(120, 30, 40), M.Metal, 0.6)
end

ItemModels.Builders = Builders

-- Monta o modelo do objeto. options.silhouette = true deixa tudo preto (coleção não descoberta).
function ItemModels.build(itemId, options)
	options = options or {}
	local builder = Builders[itemId]
	local model = Instance.new("Model")
	model.Name = itemId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2.6, 2.6, 2.6)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, 0, 0)
	root.Parent = model
	model.PrimaryPart = root
	if not builder then
		return model
	end
	for _, spec in ipairs(builder()) do
		local part = Instance.new(spec.wedge and "WedgePart" or "Part")
		part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		if spec.shape then
			part.Shape = spec.shape
		end
		local rot = spec.rot or { 0, 0, 0 }
		part.CFrame = CFrame.new(spec.pos[1], spec.pos[2], spec.pos[3]) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		if options.silhouette then
			part.Color = Color3.fromRGB(18, 18, 26)
			part.Material = Enum.Material.SmoothPlastic
			part.Transparency = 0
		else
			part.Color = spec.color
			part.Material = spec.mat or Enum.Material.SmoothPlastic
			part.Transparency = spec.alpha or 0
		end
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end
	return model
end

-- Mostra o objeto num ViewportFrame (ícone do inventário/coleção). Reaproveita a câmera.
function ItemModels.showInViewport(viewport, itemId, silhouette)
	local key = tostring(itemId) .. (silhouette and ":s" or "")
	if viewport:GetAttribute("ItemKey") == key then
		return
	end
	viewport:SetAttribute("ItemKey", key)
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	local camera = viewport.CurrentCamera
	if not camera then
		camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
	camera.CFrame = CFrame.new(Vector3.new(2.6, 1.6, 7.2), Vector3.new(0, 0, 0))
	if itemId then
		local model = ItemModels.build(itemId, { silhouette = silhouette })
		model.Parent = viewport
	end
end

return ItemModels
