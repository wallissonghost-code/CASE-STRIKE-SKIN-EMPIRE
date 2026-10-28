"use strict";
// ============================================================================
// CASE STRIKE 3D — prévia no navegador.
// Regras portadas dos módulos Luau (ProfileOps, Probability, BankMath, Progression).
// Os números vêm de DATA, exportado de src/shared/Config por tools/export_web_data.py.
// ============================================================================

const DAY = 86400, WEEK = 7 * DAY, MONDAY_EPOCH = 345600;
const now = () => Date.now() / 1000;
const dayIndex = (t) => Math.floor(t / DAY);
const weekIndex = (t) => Math.floor((t - MONDAY_EPOCH) / WEEK);

const RAR = DATA.rarity.defs;
const RORDER = DATA.rarity.order;
const tierOf = (r) => RAR[r].tier;
const rgb = (c) => `rgb(${c[0]},${c[1]},${c[2]})`;
const SKIN = {}; DATA.skins.forEach((s) => (SKIN[s.id] = s));
const CASE = {}; DATA.cases.forEach((c) => (CASE[c.id] = c));
const ZONE = {}; DATA.zones.forEach((z) => (ZONE[z.id] = z));
const POT = DATA.potions.defs;
const ATTR = {}; DATA.attributes.forEach((a) => (ATTR[a.id] = a));
const BANKUP = DATA.bank.upgrades;
const BCFG = DATA.bank.cfg;
const ECO = DATA.economy;
const PROG = DATA.progression;
const RB = PROG.rebirth;
const MISSION = {};
DATA.missions.daily.forEach((m) => (MISSION[m.id] = Object.assign({ period: "daily" }, m)));
DATA.missions.weekly.forEach((m) => (MISSION[m.id] = Object.assign({ period: "weekly" }, m)));
const COLLECTIONS = DATA.cases.filter((c) => c.isCollection);
const RECIPE = {}; DATA.recipes.forEach((r) => (RECIPE[r.id] = r));
const MAT_NAMES = { scrap: "Sucata", pigment: "Pigmento", core: "Núcleo" };

// ---------------------------------------------------------------- formatação
function fmt(n) {
  n = Math.floor(n);
  if (Math.abs(n) >= 1e9) return (n / 1e9).toLocaleString("pt-BR", { maximumFractionDigits: 2 }) + " bi";
  if (Math.abs(n) >= 1e6) return (n / 1e6).toLocaleString("pt-BR", { maximumFractionDigits: 2 }) + " mi";
  return n.toLocaleString("pt-BR");
}
function fmtRate(r) {
  return r.toLocaleString("pt-BR", { maximumFractionDigits: r < 10 ? 2 : 1 });
}
function fmtTime(s) {
  s = Math.max(0, Math.floor(s));
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
  if (h > 0) return `${h}h ${String(m).padStart(2, "0")}m`;
  return `${String(m).padStart(2, "0")}:${String(x).padStart(2, "0")}`;
}
const pct = (x, d = 0) => (x * 100).toLocaleString("pt-BR", { maximumFractionDigits: d, minimumFractionDigits: d }) + "%";

// ---------------------------------------------------------------- estado
const SAVE_KEY = "caseStrike3d.v1";
function newProfile() {
  return {
    v: 1, credits: ECO.StartingCredits, level: 1, xp: 0, inv: {}, nextUid: 1, discovered: {},
    materials: { scrap: 0, pigment: 0, core: 0 },
    bank: { pending: 0, lastTick: now(), upgrades: {} },
    attributes: {}, zones: { zone1: true }, potions: { luck: 0, xp: 0, income: 0 }, activePotions: {},
    stock: { day: dayIndex(now()), used: {} },
    missions: { day: -1, week: -1, daily: [], weekly: [], progress: {}, claimed: {} },
    eventProgress: { eventId: null, progress: {}, claimed: {} },
    rewards: { lastDailyDay: null, dailyStreak: 0, levelClaimed: {} },
    collectionsClaimed: {}, achievementsClaimed: {}, titles: { novato: true }, title: "novato",
    stats: { casesOpened: 0, skinsSold: 0, bestDropValue: 0, upgradesDone: 0, creditsFromSales: 0, creditsSpentOnCases: 0, bankClaimedTotal: 0 },
    xpCaps: { day: -1, by: {} }, rebirths: 0, freeCases: {},
    settings: { fast: false, reduce: false, skip: false }, showcase: {},
  };
}
let S = null;
function loadProfile() {
  let p = null;
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (raw) p = JSON.parse(raw);
  } catch (e) { p = null; }
  if (window.claude && window.claude.hot && window.claude.hot.data && window.claude.hot.data.S) p = window.claude.hot.data.S;
  const base = newProfile();
  if (!p || p.v !== 1) return base;
  for (const k in base) if (p[k] === undefined) p[k] = base[k];
  return p;
}
let saveTimer = 0;
function save() {
  try { localStorage.setItem(SAVE_KEY, JSON.stringify(S)); } catch (e) { /* armazenamento indisponível */ }
}
function markDirty() { saveTimer = 1; }

// ---------------------------------------------------------------- eventos
function activeEvent(t) {
  return DATA.events.list.find((ev) => t >= ev.startsAt && t < ev.endsAt) || null;
}
function nextEvent(t) {
  let best = null;
  DATA.events.list.forEach((ev) => { if (ev.startsAt > t && (!best || ev.startsAt < best.startsAt)) best = ev; });
  return best;
}
const F = DATA.events.flash;
let flashOverride = null; // modo teste: força um evento 2X agora
function flashSlot(i) {
  const ty = F.types[((i % F.types.length) + F.types.length) % F.types.length];
  const s = i * F.period;
  return Object.assign({}, ty, { startsAt: s, endsAt: s + F.duration });
}
function flashAt(t) {
  if (flashOverride && t < flashOverride.endsAt && t >= flashOverride.startsAt) return flashOverride;
  const sl = flashSlot(Math.floor(t / F.period));
  return t >= sl.startsAt && t < sl.endsAt ? sl : null;
}
function nextFlash(t) {
  const i = Math.floor(t / F.period);
  const sl = flashSlot(i);
  return sl.startsAt > t ? sl : flashSlot(i + 1);
}
function flashWindows(from, to, kind) {
  const out = [];
  for (let i = Math.floor(from / F.period); i <= Math.floor(to / F.period); i++) {
    const sl = flashSlot(i);
    if (sl.kind === kind && sl.endsAt > from && sl.startsAt < to) out.push(sl);
  }
  if (flashOverride && flashOverride.kind === kind && flashOverride.endsAt > from && flashOverride.startsAt < to) out.push(flashOverride);
  return out;
}

// ---------------------------------------------------------------- XP e níveis
const xpNeeded = (l) => Math.floor(PROG.xpBase * Math.pow(l, PROG.xpExponent) + 0.5);
function attrLevel(id) {
  const a = ATTR[id];
  if (a && a.linkedBankUpgrade) return S.bank.upgrades[a.linkedBankUpgrade] || 0;
  return S.attributes[id] || 0;
}
function xpMultiplier(t) {
  const rb = Math.min(S.rebirths * RB.XpBonusPerRebirth, RB.XpBonusMax);
  let m = 1 + attrLevel("xpBonus") * ATTR.xpBonus.perLevel + rb;
  if ((S.activePotions.xp || 0) > t) m *= POT.xp.xpMultiplier;
  const fl = flashAt(t);
  if (fl && fl.kind === "xp") m *= fl.multiplier;
  return m;
}
const pendingLevelUps = [];
function giveXp(amount, source, t) {
  amount = Math.floor(amount * xpMultiplier(t) + 0.5);
  if (amount <= 0) return 0;
  const cap = PROG.dailyXpCaps[source];
  if (cap) {
    const d = dayIndex(t);
    if (S.xpCaps.day !== d) { S.xpCaps.day = d; S.xpCaps.by = {}; }
    const used = S.xpCaps.by[source] || 0;
    amount = Math.min(amount, Math.max(0, cap - used));
    S.xpCaps.by[source] = used + amount;
    if (amount <= 0) return 0;
  }
  let levels = 0;
  S.xp += amount;
  while (S.level < PROG.maxLevel && S.xp >= xpNeeded(S.level)) {
    S.xp -= xpNeeded(S.level);
    S.level += 1;
    levels++;
  }
  if (S.level >= PROG.maxLevel) S.xp = 0;
  if (levels > 0) {
    PROG.levelTitleOrder.forEach((id) => { if (S.level >= PROG.titles[id].level) S.titles[id] = true; });
    emit("levelUp", {}, levels);
    pendingLevelUps.push(S.level);
  }
  return amount;
}

// ---------------------------------------------------------------- missões
function pickIds(pool, count, seed) {
  const idx = pool.map((_, i) => i);
  let st = (Math.floor(seed) % 2147483646) + 1;
  for (let i = idx.length; i >= 2; i--) {
    st = (st * 16807) % 2147483647;
    const j = (st % i) + 1;
    const a = idx[i - 1]; idx[i - 1] = idx[j - 1]; idx[j - 1] = a;
  }
  return idx.slice(0, Math.min(count, idx.length)).map((i) => pool[i].id);
}
function refreshPeriods(t) {
  const m = S.missions;
  const d = dayIndex(t), w = weekIndex(t);
  if (m.day !== d) {
    m.daily.forEach((id) => { delete m.progress[id]; delete m.claimed[id]; });
    m.day = d; m.daily = pickIds(DATA.missions.daily, DATA.missions.dailyCount, d);
  }
  if (m.week !== w) {
    m.weekly.forEach((id) => { delete m.progress[id]; delete m.claimed[id]; });
    m.week = w; m.weekly = pickIds(DATA.missions.weekly, 3, w + 7919);
  }
  const ev = activeEvent(t);
  if (ev && S.eventProgress.eventId !== ev.id) S.eventProgress = { eventId: ev.id, progress: {}, claimed: {} };
}
function matches(f, p) {
  if (!f) return true;
  if (f.rarity && p.rarity !== f.rarity) return false;
  if (f.minTier && (p.tier || 0) < f.minTier) return false;
  if (f.collection && p.collection !== f.collection) return false;
  if (f.collections && f.collections.indexOf(p.collection) < 0) return false;
  if (f.caseId && p.caseId !== f.caseId) return false;
  return true;
}
function emit(name, payload, amount) {
  amount = amount || 1;
  const m = S.missions;
  m.daily.concat(m.weekly).forEach((id) => {
    const d = MISSION[id];
    if (d && d.event === name && !m.claimed[id] && matches(d.filter, payload)) m.progress[id] = Math.min(d.target, (m.progress[id] || 0) + amount);
  });
  const ev = activeEvent(now());
  if (ev && S.eventProgress.eventId === ev.id) {
    const ep = S.eventProgress;
    ev.challenges.forEach((c) => {
      if (c.event === name && !ep.claimed[c.id] && matches(c.filter, payload)) ep.progress[c.id] = Math.min(c.target, (ep.progress[c.id] || 0) + amount);
    });
  }
}

// ---------------------------------------------------------------- sorte
function activeLuck(t, zoneId) {
  const list = [];
  const rb = Math.min(S.rebirths * RB.LuckPerRebirth, RB.LuckMax);
  if (rb > 0) list.push({ name: "Legado do renascimento", luck: rb });
  const al = attrLevel("luck") * ATTR.luck.perLevel;
  if (al > 0) list.push({ name: `Atributo Sorte (nível ${attrLevel("luck")})`, luck: al });
  const ev = activeEvent(t);
  if (ev && ev.luckModifier) list.push({ name: "Festival: " + ev.name, luck: 0.03 });
  const z = zoneId && ZONE[zoneId];
  if (z && z.luck > 0 && S.zones[zoneId]) list.push({ name: z.name, luck: z.luck });
  if ((S.activePotions.luck || 0) > t) list.push({ name: POT.luck.displayName, luck: POT.luck.luck });
  let total = list.reduce((a, e) => a + e.luck, 0);
  const fl = flashAt(t);
  if (fl && fl.kind === "luck") {
    list.push({ name: `${fl.name} (×${fl.multiplier})`, luck: total * (fl.multiplier - 1) });
    total *= fl.multiplier;
  }
  return { total: Math.min(total, DATA.luck.max), raw: total, list };
}
function computeTable(c, luck) {
  luck = Math.max(0, Math.min(luck || 0, DATA.luck.max));
  let total = 0;
  const e = c.drops.map((d) => {
    const w = d.weight * (1 + luck * (DATA.luck.tierScale[String(tierOf(d.rarity))] || 0));
    total += w;
    return { skinId: d.skinId, rarity: d.rarity, weight: w, p: 0 };
  });
  e.forEach((x) => (x.p = x.weight / total));
  return e;
}
function pickEntry(entries, r) {
  let acc = 0;
  for (const e of entries) { acc += e.p; if (r < acc) return e; }
  return entries[entries.length - 1];
}
// percentuais que somam exatamente 100 (maior resto), em centésimos de ponto
function displayPercents(entries, dec) {
  const unit = Math.pow(10, dec), total = Math.round(100 * unit);
  let used = 0;
  const fl = [], rem = [];
  entries.forEach((e, i) => { const ex = e.p * 100 * unit; fl[i] = Math.floor(ex); rem.push({ i, r: ex - fl[i] }); used += fl[i]; });
  rem.sort((a, b) => (a.r === b.r ? a.i - b.i : b.r - a.r));
  for (let k = 0; k < total - used; k++) fl[rem[k % rem.length].i]++;
  return fl.map((f) => f / unit);
}
function rng() {
  if (window.crypto && crypto.getRandomValues) { const a = new Uint32Array(1); crypto.getRandomValues(a); return a[0] / 4294967296; }
  return Math.random();
}

// ---------------------------------------------------------------- banco
const bankUp = (id) => S.bank.upgrades[id] || 0;
const upgradeCost = (id, l) => Math.floor(BANKUP[id].baseCost * Math.pow(BANKUP[id].growth, l) + 0.5);
const bankSlots = () => BCFG.BaseSlots + bankUp("slots") * BANKUP.slots.perLevel + Math.floor(S.rebirths / RB.ExtraBankSlotEvery);
const offlineCap = () => BCFG.MaxOfflineSeconds + bankUp("offline") * BANKUP.offline.perLevel;
const storageCap = () => Math.floor(BCFG.BaseStorage * Math.pow(1 + BANKUP.storage.perLevel, bankUp("storage")) + 0.5);
const efficiency = () => 1 + bankUp("efficiency") * BANKUP.efficiency.perLevel + Math.min(S.rebirths * RB.BankEfficiencyPerRebirth, RB.BankEfficiencyMax);
function baseIncome(def) {
  const inc = BCFG.K * Math.pow(def.value, BCFG.Exponent) * RAR[def.rarity].bankMultiplier;
  return Math.max(BCFG.MinIncomePerSkin, Math.min(inc, BCFG.MaxIncomePerSkin));
}
const itemIncome = (it) => baseIncome(SKIN[it.defId]) * efficiency();
const bankItems = () => Object.values(S.inv).filter((i) => i.loc === "bank").sort((a, b) => (a.depAt || 0) - (b.depAt || 0));
const totalRate = () => bankItems().reduce((a, i) => a + itemIncome(i), 0);
function overlap(a1, a2, b1, b2) { return Math.max(0, Math.min(a2, b2) - Math.max(a1, b1)); }
function boostedSeconds(from, to) {
  let secs = to - from;
  if (secs <= 0) return 0;
  const pe = S.activePotions.income || 0;
  if (pe > from) secs += overlap(from, to, from, pe) * (POT.income.incomeMultiplier - 1);
  flashWindows(from, to, "income").forEach((w) => (secs += overlap(from, to, w.startsAt, w.endsAt) * (w.multiplier - 1)));
  return secs;
}
function currentBoost(t) {
  let m = 1;
  if ((S.activePotions.income || 0) > t) m += POT.income.incomeMultiplier - 1;
  const fl = flashAt(t);
  if (fl && fl.kind === "income") m += fl.multiplier - 1;
  return m;
}
function settle(t) {
  const b = S.bank;
  let dt = t - (b.lastTick || t);
  if (dt < 0) dt = 0;
  dt = Math.min(dt, offlineCap());
  const cap = storageCap();
  const before = b.pending || 0;
  let produced = 0;
  if (before < cap) {
    produced = totalRate() * boostedSeconds(t - dt, t);
    b.pending = Math.min(cap, before + produced);
    produced = b.pending - before;
  }
  b.lastTick = t;
  return produced;
}

// ---------------------------------------------------------------- patrimônio
function netWorth() {
  let v = 0;
  Object.values(S.inv).forEach((i) => (v += SKIN[i.defId].value));
  return S.credits + v + Math.floor(S.bank.pending || 0);
}

// ---------------------------------------------------------------- operações (validam tudo antes de alterar)
const MSG = {
  insufficient_credits: "Créditos insuficientes.",
  level_locked: "Nível insuficiente.",
  quantity_locked: "Compre o atributo Abertura ×25 para abrir 25 de uma vez.",
  inventory_full: "Inventário cheio. Venda ou deposite skins.",
  out_of_stock: "Estoque de hoje esgotado. Volta amanhã (00:00 UTC).",
  bank_full: "Todas as vagas do banco estão ocupadas.",
  favorite_locked: "Item favorito: confirme para vender.",
  valuable_locked: "Item raro: confirme para vender.",
  nothing_to_claim: "Nada para resgatar ainda.",
  already_claimed: "Já resgatado.",
  max_level: "Nível máximo.",
  zone_requires: "Desbloqueie a zona anterior primeiro.",
  no_potion: "Você não tem essa poção.",
  potion_max: "Limite de tempo acumulado atingido.",
  rarity_too_low: "Raridade baixa demais para essa melhoria.",
  already_upgraded: "Essa melhoria já foi aplicada.",
  insufficient_materials: "Materiais insuficientes.",
  showcase_full: "A vitrine está cheia (6 skins).",
  in_bank: "Retire a skin do banco primeiro.",
  rebirth_locked: "Requisitos de renascimento não atingidos.",
  confirmation_required: "Digite a frase de confirmação.",
};
const fail = (code) => ({ ok: false, code, msg: MSG[code] || code });
const itemCount = () => Object.keys(S.inv).length;
const maxQuantity = () => (attrLevel("multiOpen") >= 1 ? 25 : 10);
const speedFactor = () => 1 - attrLevel("openSpeed") * ATTR.openSpeed.perLevel;
function stockLeft(c, t) {
  if (!c.stockPerDay) return Infinity;
  const d = dayIndex(t);
  if (S.stock.day !== d) S.stock = { day: d, used: {} };
  return Math.max(0, c.stockPerDay - (S.stock.used[c.id] || 0));
}
function newItem(defId, t, caseId) {
  const uid = "i" + S.nextUid++;
  const it = { uid, defId, at: t, caseId, fav: false, eq: false, loc: "inv", up: {} };
  S.inv[uid] = it;
  return it;
}
function collectionStatus(colId) {
  const skins = DATA.skins.filter((s) => s.collection === colId);
  const found = skins.filter((s) => S.discovered[s.id]).length;
  return { found, total: skins.length, complete: found === skins.length && skins.length > 0 };
}

function openCases(caseId, qty, useFreeWanted, zoneId) {
  const t = now();
  const c = CASE[caseId];
  if (!c || !c.available) return fail("invalid_case");
  if (ECO.Opening && [1, 5, 10, 25].indexOf(qty) < 0) return fail("invalid_quantity");
  if (S.level < c.requiredLevel) return fail("level_locked");
  if (qty > maxQuantity()) return fail("quantity_locked");
  if (itemCount() + qty > ECO.InventoryCapacity) return fail("inventory_full");
  const free = S.freeCases[caseId] || 0;
  const useFree = useFreeWanted && free >= qty;
  const cost = useFree ? 0 : c.price * qty;
  if (S.credits < cost) return fail("insufficient_credits");
  if (c.stockPerDay && stockLeft(c, t) < qty) return fail("out_of_stock");
  refreshPeriods(t);
  const luck = activeLuck(t, zoneId).total;
  const entries = computeTable(c, luck);
  const draws = [];
  for (let i = 0; i < qty; i++) draws.push(pickEntry(entries, rng()));
  if (useFree) { if (free - qty > 0) S.freeCases[caseId] = free - qty; else delete S.freeCases[caseId]; }
  else { S.credits -= cost; S.stats.creditsSpentOnCases += cost; }
  if (c.stockPerDay) S.stock.used[caseId] = (S.stock.used[caseId] || 0) + qty;
  const results = [];
  draws.forEach((d) => {
    const def = SKIN[d.skinId];
    const it = newItem(def.id, t, caseId);
    const isNew = !S.discovered[def.id];
    const payload = { rarity: def.rarity, tier: tierOf(def.rarity), collection: def.collection, caseId };
    if (isNew) {
      S.discovered[def.id] = t;
      giveXp(RAR[def.rarity].discoverXp, null, t);
      emit("discover", payload, 1);
      const ev = activeEvent(t);
      if (ev && ev.featuredCollection === def.collection) emit("discoverFeatured", payload, 1);
      if (collectionStatus(def.collection).complete) emit("collectionComplete", payload, 1);
    }
    emit("obtain", payload, 1);
    if (def.value > S.stats.bestDropValue) S.stats.bestDropValue = def.value;
    results.push({ uid: it.uid, defId: def.id, isNew });
  });
  S.stats.casesOpened += qty;
  giveXp(ECO.Opening.XpPerOpen * qty, "open", t);
  emit("open", { caseId }, qty);
  markDirty();
  return { ok: true, results, cost, luck, entries, useFree };
}

function sellItems(uids, confirmFav, confirmValuable) {
  const t = now();
  let total = 0;
  const mats = {};
  for (const uid of uids) {
    const it = S.inv[uid];
    if (!it) return fail("invalid_item");
    if (it.loc === "bank") return fail("in_bank");
    const def = SKIN[it.defId];
    if (it.fav && !confirmFav) return fail("favorite_locked");
    if (tierOf(def.rarity) >= ECO.ValuableConfirmTier && !confirmValuable) return fail("valuable_locked");
    total += Math.floor(def.value * ECO.SellRate);
    const sm = ECO.SellMaterials[def.rarity] || {};
    for (const k in sm) mats[k] = (mats[k] || 0) + sm[k];
  }
  uids.forEach((uid) => {
    const def = SKIN[S.inv[uid].defId];
    delete S.inv[uid];
    delete S.showcase[uid];
    emit("sell", { rarity: def.rarity, tier: tierOf(def.rarity), collection: def.collection }, 1);
  });
  S.credits += total;
  for (const k in mats) S.materials[k] = (S.materials[k] || 0) + mats[k];
  S.stats.skinsSold += uids.length;
  S.stats.creditsFromSales += total;
  markDirty();
  return { ok: true, credits: total, mats, sold: uids.length };
}
function deposit(uid) {
  const t = now();
  const it = S.inv[uid];
  if (!it) return fail("invalid_item");
  if (it.loc === "bank") return fail("in_bank");
  if (bankItems().length >= bankSlots()) return fail("bank_full");
  settle(t);
  it.loc = "bank"; it.depAt = t; it.eq = false;
  delete S.showcase[uid];
  emit("deposit", {}, 1);
  markDirty();
  return { ok: true };
}
function withdraw(uid) {
  const it = S.inv[uid];
  if (!it || it.loc !== "bank") return fail("invalid_item");
  if (itemCount() > ECO.InventoryCapacity) return fail("inventory_full");
  settle(now());
  it.loc = "inv"; delete it.depAt;
  markDirty();
  return { ok: true };
}
function claimBank() {
  const t = now();
  settle(t);
  const amt = Math.floor(S.bank.pending || 0);
  if (amt <= 0) return fail("nothing_to_claim");
  S.bank.pending -= amt;
  S.credits += amt;
  S.stats.bankClaimedTotal = (S.stats.bankClaimedTotal || 0) + amt;
  emit("bankClaim", {}, 1);
  markDirty();
  return { ok: true, credits: amt };
}
function buyBankUpgrade(id) {
  const u = BANKUP[id];
  const l = bankUp(id);
  if (l >= u.maxLevel) return fail("max_level");
  if (S.level < u.requiredLevels[l]) return fail("level_locked");
  const cost = upgradeCost(id, l);
  if (S.credits < cost) return fail("insufficient_credits");
  settle(now());
  S.credits -= cost;
  S.bank.upgrades[id] = l + 1;
  emit("bankUpgrade", {}, 1);
  markDirty();
  return { ok: true, cost };
}
function attrInfo(id) {
  const a = ATTR[id];
  const level = attrLevel(id);
  let max, cost, req;
  if (a.linkedBankUpgrade) {
    const u = BANKUP[a.linkedBankUpgrade];
    max = u.maxLevel;
    if (level < max) { cost = upgradeCost(a.linkedBankUpgrade, level); req = u.requiredLevels[level]; }
  } else {
    max = a.maxLevel;
    if (level < max) { cost = Math.floor(a.baseCost * Math.pow(a.growth, level) + 0.5); req = a.requiredLevels[level]; }
  }
  return { a, level, max, cost, req, benefit: a.benefits[level], next: level < max ? a.benefits[level + 1] : null };
}
function buyAttribute(id) {
  const a = ATTR[id];
  if (a.linkedBankUpgrade) return buyBankUpgrade(a.linkedBankUpgrade);
  const info = attrInfo(id);
  if (info.level >= info.max) return fail("max_level");
  if (S.level < info.req) return fail("level_locked");
  if (S.credits < info.cost) return fail("insufficient_credits");
  S.credits -= info.cost;
  S.attributes[id] = info.level + 1;
  markDirty();
  return { ok: true };
}
function grantReward(r, xpSource) {
  const t = now();
  const sum = [];
  if (!r) return sum;
  if (r.credits) { S.credits += r.credits; sum.push("₵ " + fmt(r.credits)); }
  if (r.xp) { const g = giveXp(r.xp, xpSource, t); sum.push(g + " XP"); }
  if (r.materials) for (const k in r.materials) { S.materials[k] = (S.materials[k] || 0) + r.materials[k]; sum.push(r.materials[k] + " " + MAT_NAMES[k]); }
  if (r.freeCases) for (const k in r.freeCases) if (CASE[k]) { S.freeCases[k] = (S.freeCases[k] || 0) + r.freeCases[k]; sum.push(r.freeCases[k] + "× " + CASE[k].name + " grátis"); }
  if (r.potions) for (const k in r.potions) if (POT[k]) { S.potions[k] = (S.potions[k] || 0) + r.potions[k]; sum.push(r.potions[k] + "× " + POT[k].displayName); }
  if (r.title && PROG.titles[r.title]) { S.titles[r.title] = true; sum.push("título “" + PROG.titles[r.title].displayName + "”"); }
  markDirty();
  return sum;
}
function dailyStatus(t) {
  const d = dayIndex(t), r = S.rewards;
  let next = 1;
  if (r.lastDailyDay === d - 1) next = (r.dailyStreak % PROG.dailyRewards.length) + 1;
  else if (r.lastDailyDay === d) next = r.dailyStreak;
  return { available: r.lastDailyDay !== d, streak: r.dailyStreak, next, resetIn: (d + 1) * DAY - t };
}
function claimDaily() {
  const st = dailyStatus(now());
  if (!st.available) return fail("already_claimed");
  S.rewards.lastDailyDay = dayIndex(now());
  S.rewards.dailyStreak = st.next;
  return { ok: true, sum: grantReward(PROG.dailyRewards[st.next - 1], null) };
}
function claimLevel(l) {
  if (S.level < l) return fail("level_locked");
  if (S.rewards.levelClaimed[l]) return fail("already_claimed");
  S.rewards.levelClaimed[l] = true;
  return { ok: true, sum: grantReward(PROG.levelRewards[String(l)], null) };
}
function claimMission(id) {
  const m = S.missions, d = MISSION[id];
  if (!d || (m.daily.indexOf(id) < 0 && m.weekly.indexOf(id) < 0)) return fail("invalid");
  if (m.claimed[id]) return fail("already_claimed");
  if ((m.progress[id] || 0) < d.target) return fail("nothing_to_claim");
  m.claimed[id] = true;
  emit("missionClaim", {}, 1);
  return { ok: true, sum: grantReward(d.reward, null) };
}
function claimEventChallenge(id) {
  const ev = activeEvent(now());
  if (!ev) return fail("invalid");
  const c = ev.challenges.find((x) => x.id === id);
  const ep = S.eventProgress;
  if (!c || ep.claimed[id]) return fail("already_claimed");
  if ((ep.progress[id] || 0) < c.target) return fail("nothing_to_claim");
  ep.claimed[id] = true;
  return { ok: true, sum: grantReward(c.reward, "event") };
}
function claimCollection(colId) {
  if (S.collectionsClaimed[colId]) return fail("already_claimed");
  if (!collectionStatus(colId).complete) return fail("nothing_to_claim");
  S.collectionsClaimed[colId] = true;
  return { ok: true, sum: grantReward(PROG.collectionRewards[colId], null) };
}
function statValue(stat) {
  if (stat === "uniqueDiscovered") return Object.keys(S.discovered).length;
  if (stat === "collectionsCompleted") return COLLECTIONS.filter((c) => collectionStatus(c.id).complete).length;
  if (stat === "level") return S.level;
  if (stat === "netWorth") return netWorth();
  if (stat === "bankIncome") return totalRate();
  if (stat === "rebirths") return S.rebirths;
  return S.stats[stat] || 0;
}
function claimAchievement(id) {
  const a = DATA.achievements.find((x) => x.id === id);
  if (!a || S.achievementsClaimed[id]) return fail("already_claimed");
  if (statValue(a.stat) < a.target) return fail("nothing_to_claim");
  S.achievementsClaimed[id] = true;
  const sum = grantReward(a.reward, null);
  sum.push(giveXp(120, null, now()) + " XP");
  return { ok: true, sum };
}
function buyZone(id) {
  const z = ZONE[id];
  if (!z || z.cost <= 0) return fail("invalid_zone");
  if (S.zones[id]) return fail("zone_owned");
  if (z.requires && !S.zones[z.requires]) return fail("zone_requires");
  if (S.level < z.requiredLevel) return fail("level_locked");
  if (S.credits < z.cost) return fail("insufficient_credits");
  S.credits -= z.cost;
  S.zones[id] = true;
  markDirty();
  return { ok: true };
}
function activatePotion(id) {
  const t = now(), d = POT[id];
  if ((S.potions[id] || 0) <= 0) return fail("no_potion");
  const cur = Math.max(t, S.activePotions[id] || 0);
  if (cur - t >= d.maxStack) return fail("potion_max");
  if (id === "income") settle(t);
  S.potions[id] -= 1;
  S.activePotions[id] = Math.min(cur + d.duration, t + d.maxStack);
  markDirty();
  return { ok: true };
}
function applyUpgrade(uid, rid) {
  const it = S.inv[uid], r = RECIPE[rid];
  if (!it || !r) return fail("invalid");
  if (it.loc === "bank") return fail("in_bank");
  const def = SKIN[it.defId];
  if (tierOf(def.rarity) < r.minRarityTier) return fail("rarity_too_low");
  if (it.up[rid]) return fail("already_upgraded");
  const cost = Math.floor(r.creditsBase + def.value * r.creditsValueFactor + 0.5);
  if (S.credits < cost) return fail("insufficient_credits");
  for (const k in r.materials) if ((S.materials[k] || 0) < r.materials[k]) return fail("insufficient_materials");
  S.credits -= cost;
  for (const k in r.materials) S.materials[k] -= r.materials[k];
  it.up[rid] = true;
  S.stats.upgradesDone++;
  giveXp(r.xp, "upgrade", now());
  emit("upgrade", { rarity: def.rarity, tier: tierOf(def.rarity) }, 1);
  markDirty();
  return { ok: true, cost };
}
function setShowcase(uid, on) {
  const it = S.inv[uid];
  if (!it) return fail("invalid_item");
  if (on) {
    if (it.loc === "bank") return fail("in_bank");
    if (Object.keys(S.showcase).length >= ECO.ShowcaseSlots) return fail("showcase_full");
    S.showcase[uid] = true;
  } else delete S.showcase[uid];
  markDirty();
  return { ok: true };
}
function equip(uid) {
  const it = S.inv[uid];
  if (!it) return fail("invalid_item");
  if (it.loc === "bank") return fail("in_bank");
  const was = it.eq;
  Object.values(S.inv).forEach((i) => (i.eq = false));
  it.eq = !was;
  if (it.eq) emit("equip", {}, 1);
  markDirty();
  return { ok: true };
}
const keepsOnRebirth = (it) => tierOf(SKIN[it.defId].rarity) >= RB.KeepMinTier || (RB.KeepFavorites && it.fav);
function rebirthPreview() {
  const n = S.rebirths + 1;
  const req = PROG.rebirthReq[Math.min(n, PROG.rebirthReq.length) - 1];
  let keep = 0, lose = 0;
  Object.values(S.inv).forEach((i) => (keepsOnRebirth(i) ? keep++ : lose++));
  const worth = netWorth();
  return { n, reqLevel: req[0], reqWorth: req[1], worth, keep, lose, maxed: S.rebirths >= RB.MaxRebirths, can: S.rebirths < RB.MaxRebirths && S.level >= req[0] && worth >= req[1] };
}
function rebirth(phrase) {
  if (phrase !== RB.ConfirmPhrase) return fail("confirmation_required");
  const p = rebirthPreview();
  if (!p.can) return fail("rebirth_locked");
  Object.keys(S.inv).forEach((uid) => { if (!keepsOnRebirth(S.inv[uid])) { delete S.inv[uid]; delete S.showcase[uid]; } });
  S.credits = ECO.StartingCredits; S.level = 1; S.xp = 0; S.rebirths++;
  S.bank.pending = 0; S.bank.lastTick = now();
  for (const k in S.bank.upgrades) S.bank.upgrades[k] = 0;
  bankItems().slice(bankSlots()).forEach((i) => { i.loc = "inv"; delete i.depAt; });
  S.titles.renascido = true;
  markDirty();
  return { ok: true };
}
function claimableCount() {
  const t = now();
  let n = 0;
  if (dailyStatus(t).available) n++;
  for (const l in PROG.levelRewards) if (S.level >= +l && !S.rewards.levelClaimed[l]) n++;
  return n;
}
function missionReadyCount() {
  const m = S.missions;
  let n = 0;
  m.daily.concat(m.weekly).forEach((id) => { if (!m.claimed[id] && (m.progress[id] || 0) >= MISSION[id].target) n++; });
  const ev = activeEvent(now());
  if (ev && S.eventProgress.eventId === ev.id) ev.challenges.forEach((c) => { if (!S.eventProgress.claimed[c.id] && (S.eventProgress.progress[c.id] || 0) >= c.target) n++; });
  return n;
}
