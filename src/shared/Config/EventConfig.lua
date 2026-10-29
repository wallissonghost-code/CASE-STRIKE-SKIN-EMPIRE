-- EventConfig: eventos de mutação do servidor.
-- Agenda fixa em UTC (igual em todos os servidores): a cada 30 minutos começa um evento
-- de 6 minutos, alternando o tipo. Como a agenda é determinística, a renda offline
-- também pode somar corretamente os períodos de "Renda em Dobro".

local EventConfig = {}

EventConfig.Period = 1800
EventConfig.Duration = 360

-- kind: mutation (multiplica o peso de uma mutação), luck (sorte extra), income (multiplica renda),
--       conveyor (esteira mais rápida e com sorte)
EventConfig.Types = {
	{ id = "chuva_dourada", name = "Chuva Dourada", icon = "🌟", kind = "mutation", mutation = "dourada", weightMult = 5, description = "Mutação Dourada 5× mais comum." },
	{ id = "hora_sorte", name = "Hora da Sorte", icon = "🍀", kind = "luck", luck = 0.5, description = "+50% de sorte para todos." },
	{ id = "tempestade_radioativa", name = "Tempestade Radioativa", icon = "☢️", kind = "mutation", mutation = "radioativa", weightMult = 5, description = "Mutação Radioativa 5× mais comum." },
	{ id = "renda_dobro", name = "Renda em Dobro", icon = "💰", kind = "income", incomeMult = 2, description = "Todas as criaturas produzem o dobro." },
	{ id = "eclipse_vazio", name = "Eclipse do Vazio", icon = "🌑", kind = "mutation", mutation = "vazio", weightMult = 4, description = "Mutação Vazio 4× mais comum." },
	{ id = "esteira_turbo", name = "Esteira Turbo", icon = "⚡", kind = "conveyor", intervalMult = 0.5, luck = 0.5, description = "A esteira solta criaturas 2× mais rápido e com mais sorte." },
	{ id = "aurora_arcoiris", name = "Aurora Arco-íris", icon = "🌈", kind = "mutation", mutation = "arcoiris", weightMult = 5, description = "Mutação Arco-íris 5× mais comum." },
}

local function slot(index)
	local t = EventConfig.Types[(index % #EventConfig.Types) + 1]
	local startsAt = index * EventConfig.Period
	return {
		id = t.id,
		name = t.name,
		icon = t.icon,
		kind = t.kind,
		mutation = t.mutation,
		weightMult = t.weightMult,
		luck = t.luck,
		incomeMult = t.incomeMult,
		intervalMult = t.intervalMult,
		description = t.description,
		startsAt = startsAt,
		endsAt = startsAt + EventConfig.Duration,
	}
end

-- teste/servidor pode forçar um evento (ex.: comando de administrador no Studio)
EventConfig.override = nil

function EventConfig.at(now)
	local o = EventConfig.override
	if o and now >= o.startsAt and now < o.endsAt then
		return o
	end
	local s = slot(math.floor(now / EventConfig.Period))
	if now >= s.startsAt and now < s.endsAt then
		return s
	end
	return nil
end

function EventConfig.nextEvent(now)
	local i = math.floor(now / EventConfig.Period)
	local s = slot(i)
	if s.startsAt > now then
		return s
	end
	return slot(i + 1)
end

-- janelas de um tipo (kind) que se sobrepõem a [from, to]
function EventConfig.windows(from, to, kind)
	local out = {}
	if to <= from then
		return out
	end
	local first = math.floor(from / EventConfig.Period)
	local last = math.floor(to / EventConfig.Period)
	if last - first > 2000 then
		first = last - 2000 -- proteção: nunca percorre mais que ~41 dias
	end
	for i = first, last do
		local s = slot(i)
		if s.kind == kind and s.endsAt > from and s.startsAt < to then
			table.insert(out, s)
		end
	end
	local o = EventConfig.override
	if o and o.kind == kind and o.endsAt > from and o.startsAt < to then
		table.insert(out, o)
	end
	return out
end

-- força um evento agora (por id) por `seconds` segundos
function EventConfig.force(id, now, seconds)
	for _, t in ipairs(EventConfig.Types) do
		if t.id == id then
			local s = slot(0)
			for k, v in pairs(t) do
				s[k] = v
			end
			s.startsAt = now
			s.endsAt = now + (seconds or EventConfig.Duration)
			EventConfig.override = s
			return s
		end
	end
	return nil
end

return EventConfig
