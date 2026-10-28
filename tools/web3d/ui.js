// ============================================================================
// Interface: HUD, menus laterais, painéis, roleta e confirmações (sem alert/confirm)
// ============================================================================

function h(tag, attrs, kids) {
  const e = document.createElement(tag);
  if (attrs) for (const k in attrs) {
    const v = attrs[k];
    if (v === undefined || v === null || v === false) continue;
    if (k === "class") e.className = v;
    else if (k === "style") e.style.cssText = v;
    else if (k === "html") e.innerHTML = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else if (k === "disabled") e.disabled = !!v;
    else e.setAttribute(k, v);
  }
  (Array.isArray(kids) ? kids : kids === undefined ? [] : [kids]).forEach((c) => {
    if (c === null || c === undefined || c === false) return;
    e.appendChild(typeof c === "string" || typeof c === "number" ? document.createTextNode(String(c)) : c);
  });
  return e;
}
function toast(msg, kind) {
  const box = document.getElementById("toast");
  const t = h("div", { class: "toast " + (kind || "") }, msg);
  box.appendChild(t);
  while (box.children.length > 4) box.removeChild(box.firstChild);
  setTimeout(() => t.remove(), 3200);
}
function handle(res, okMsg) {
  if (!res.ok) { toast(res.msg, "bad"); return false; }
  if (okMsg) toast(typeof okMsg === "function" ? okMsg(res) : okMsg, "good");
  UI.changed();
  return true;
}
const rarityName = (r) => RAR[r].displayName;
const rc = (r) => rgb(RAR[r].color);

function itemCard(it, opts) {
  opts = opts || {};
  const def = SKIN[it.defId || it];
  const owned = typeof it === "object";
  const flags = owned ? (it.fav ? "★" : "") + (it.eq ? "🖐" : "") + (it.loc === "bank" ? "🏦" : "") + (S.showcase[it.uid] ? "🏛" : "") + (Object.keys(it.up || {}).length ? "✨" : "") : "";
  const el = h("div", { class: "it" + (opts.sel ? " sel" : "") + (opts.locked ? " locked" : ""), style: `--rc:${rc(def.rarity)}`, onclick: opts.onclick, role: opts.onclick ? "button" : null, tabindex: opts.onclick ? "0" : null }, [
    flags ? h("span", { class: "flags" }, flags) : null,
    opts.isNew ? h("span", { class: "new" }, "NOVA!") : null,
    opts.locked ? h("div", { style: "aspect-ratio:2/1;display:flex;align-items:center;justify-content:center;font-family:var(--display);font-size:28px" }, "???") : iconCanvas(def.id, 160, 80),
    h("div", { class: "n" }, opts.locked ? def.weaponName : def.name),
    h("div", { class: "rn" }, rarityName(def.rarity)),
    opts.noValue ? null : h("div", { class: "v num" }, "₵ " + fmt(def.value)),
  ]);
  if (opts.onclick) el.addEventListener("keydown", (e) => { if (e.key === "Enter") opts.onclick(); });
  return el;
}
function rewardLine(r) {
  if (!r) return "";
  const p = [];
  if (r.credits) p.push("₵ " + fmt(r.credits));
  if (r.xp) p.push(r.xp + " XP");
  if (r.materials) for (const k in r.materials) p.push(r.materials[k] + " " + MAT_NAMES[k]);
  if (r.freeCases) for (const k in r.freeCases) if (CASE[k]) p.push(r.freeCases[k] + "× " + CASE[k].name);
  if (r.potions) for (const k in r.potions) if (POT[k]) p.push(r.potions[k] + "× " + POT[k].displayName);
  if (r.title && PROG.titles[r.title]) p.push("título " + PROG.titles[r.title].displayName);
  return p.join(" • ");
}

const UI = {
  cur: null, arg: null, tab: {}, sel: null, inspect: null, auto: null, live: {},
  isOpen() { return !document.getElementById("overlay").hidden || !document.getElementById("spin").hidden; },
  open(id, arg) {
    if (id === "soon") return UI.soon("Batalhas", "Batalhas, troca entre jogadores, PvP e monstros ainda não estão disponíveis.");
    UI.cur = id; UI.arg = arg; UI.sel = id === "inventory" || id === "workshop" ? UI.sel : null;
    UI.render();
  },
  openCase(id) { UI.open("case", id); },
  close() {
    UI.disposeInspect();
    document.getElementById("overlay").hidden = true;
    document.getElementById("overlay").innerHTML = "";
    UI.cur = null;
  },
  changed() {
    W.dirty = true;
    if (UI.cur && document.getElementById("spin").hidden) UI.render(true);
    UI.hud();
  },
  soon(title, text) {
    UI.cur = "soon";
    UI.frame(title, (b) => {
      b.append(h("div", { class: "card", style: "text-align:center;padding:24px" }, [
        h("div", { class: "chunk", style: "font-size:40px;color:var(--gold)" }, "EM BREVE"),
        h("p", { class: "muted" }, text),
        h("p", { class: "muted" }, "Apostas, batalhas de caixas com apostas, Crash e melhorias por risco não fazem parte do jogo."),
      ]));
    });
  },
  frame(title, fill, keepScroll) {
    const ov = document.getElementById("overlay");
    const prev = ov.querySelector(".win-b");
    const st = keepScroll && prev ? prev.scrollTop : 0;
    UI.disposeInspect();
    ov.innerHTML = "";
    const body = h("div", { class: "win-b" });
    const win = h("div", { class: "win", role: "dialog", "aria-label": title }, [
      h("div", { class: "win-h" }, [h("h2", null, title), h("button", { class: "x", type: "button", "aria-label": "Fechar", onclick: UI.close }, "✕")]),
      body,
    ]);
    if (keepScroll) win.style.animation = "none";
    ov.appendChild(win);
    ov.hidden = false;
    ov.onclick = (e) => { if (e.target === ov) UI.close(); };
    UI.live = {};
    fill(body);
    body.scrollTop = st;
  },
  render(keep) {
    const P = PANELS[UI.cur];
    if (!P) return;
    UI.frame(typeof P.title === "function" ? P.title() : P.title, (b) => P.render(b), keep);
  },
  tabs(b, key, items, onPick) {
    const cur = UI.tab[key] || items[0][0];
    b.append(h("div", { class: "tabs" }, items.map(([id, label]) => h("button", { type: "button", class: "tab" + (id === cur ? " on" : ""), onclick: () => { UI.tab[key] = id; UI.render(true); if (onPick) onPick(id); } }, label))));
    return cur;
  },
  confirm(title, text, yesLabel, onYes, opts) {
    opts = opts || {};
    const layer = h("div", { style: "position:fixed;inset:0;z-index:45;display:flex;align-items:center;justify-content:center;background:rgba(5,9,26,.6);padding:16px" });
    const input = opts.phrase ? h("input", { type: "text", id: "confirmPhrase", placeholder: opts.phrase, autocomplete: "off" }) : null;
    const yes = h("button", { type: "button", class: "btn " + (opts.danger ? "r" : "g"), onclick: () => { if (opts.phrase && input.value.trim().toUpperCase() !== opts.phrase) { toast("Digite " + opts.phrase + " para confirmar.", "bad"); return; } layer.remove(); onYes(input ? input.value.trim().toUpperCase() : undefined); } }, yesLabel);
    layer.append(h("div", { class: "win", style: "width:min(440px,100%)" }, [
      h("div", { class: "win-h" }, [h("h2", null, title)]),
      h("div", { class: "win-b" }, [
        h("p", { html: text }),
        input,
        h("div", { class: "row", style: "justify-content:flex-end;margin-top:12px" }, [h("button", { type: "button", class: "btn", onclick: () => layer.remove() }, "Cancelar"), yes]),
      ]),
    ]));
    document.body.appendChild(layer);
    if (input) input.focus();
  },
  zoneChanged(z) {
    const zn = ZONE[z];
    const ban = document.getElementById("zoneBanner");
    const owned = !!S.zones[z];
    ban.innerHTML = "";
    ban.append(zn.name.split(" — ")[0].toUpperCase(), zn.luck > 0 ? h("small", null, `+ ${Math.round(zn.luck * 100)}% Sorte${owned ? "" : " (bloqueada)"}`) : h("small", null, zn.name.split(" — ")[1] || ""));
    ban.style.color = rgb(zn.color);
    ban.style.opacity = 1;
    clearTimeout(UI.banT);
    UI.banT = setTimeout(() => (ban.style.opacity = 0), 2600);
    UI.hud();
  },
  disposeInspect() {
    if (UI.inspect) { UI.inspect.stop = true; try { UI.inspect.r.dispose(); UI.inspect.r.forceContextLoss(); } catch (e) {} UI.inspect = null; }
  },
  // visualizador 3D da skin: arrastar gira, roda aproxima
  mountInspect(canvas, it) {
    const r = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    r.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
    const w = canvas.clientWidth || 400, hh = canvas.clientHeight || 220;
    r.setSize(w, hh, false);
    const sc = new THREE.Scene();
    sc.add(new THREE.HemisphereLight(0xffffff, 0x334477, 0.9));
    const dl = new THREE.DirectionalLight(0xffffff, 0.9); dl.position.set(3, 5, 6); sc.add(dl);
    const cam = new THREE.PerspectiveCamera(40, w / hh, 0.1, 100);
    const m = buildWeapon(SKIN[it.defId], it.up); sc.add(m);
    const st = { r, stop: false, rx: 0.2, ry: 0.6, dist: 9, auto: true };
    let drag = null;
    canvas.onpointerdown = (e) => { drag = { x: e.clientX, y: e.clientY }; st.auto = false; canvas.setPointerCapture(e.pointerId); };
    canvas.onpointermove = (e) => { if (!drag) return; st.ry += (e.clientX - drag.x) * 0.01; st.rx = Math.max(-1.2, Math.min(1.2, st.rx + (e.clientY - drag.y) * 0.01)); drag = { x: e.clientX, y: e.clientY }; };
    canvas.onpointerup = canvas.onpointercancel = () => (drag = null);
    canvas.onwheel = (e) => { st.dist = Math.max(4.5, Math.min(16, st.dist + e.deltaY * 0.01)); e.preventDefault(); };
    const loop = () => {
      if (st.stop) return;
      if (st.auto) st.ry += 0.008;
      m.rotation.set(st.rx, st.ry, 0);
      m.traverse((o) => { if (o.userData.holo) o.userData.holo.emissive.setHSL((performance.now() / 6000) % 1, 0.8, 0.5); });
      cam.position.set(0, 0.6, st.dist); cam.lookAt(0, 0.1, 0);
      r.render(sc, cam);
      requestAnimationFrame(loop);
    };
    loop();
    UI.inspect = st;
    return st;
  },
};

// ---------------------------------------------------------------- HUD
const SIDE = [
  ["shop", "📦", "CAIXAS", "big"], ["inventory", "🎒", "INVENT."], ["bank", "🏦", "BANCO"], ["workshop", "🔧", "OFICINA"],
  ["index", "📖", "COLEÇÃO"], ["missions", "🎯", "MISSÕES"], ["gifts", "🎁", "PRESENTES"], ["attributes", "⭐", "ATRIBUT."],
  ["potions", "🧪", "POÇÕES"], ["zones", "🗺️", "ZONAS"], ["rebirth", "♻️", "RENASCER"], ["ranking", "🏆", "RANKING"],
  ["showroom", "🏛️", "VITRINE"], ["soon", "⚔️", "BATALHA", "soon"], ["settings", "⚙️", "AJUSTES"],
];
function buildSide() {
  const side = document.getElementById("side");
  SIDE.forEach(([id, icon, label, kind]) => {
    side.append(h("button", { type: "button", class: "sb" + (kind ? " " + kind : ""), id: "sb-" + id, onclick: () => UI.open(id), "aria-label": label }, [h("span", { class: "i" }, icon), h("span", { class: "l" }, kind === "soon" ? "EM BREVE" : label)]));
  });
  document.getElementById("luckChip").addEventListener("click", () => UI.open("luck"));
  document.getElementById("luckChip").style.cursor = "pointer";
  document.getElementById("zoneChip").addEventListener("click", () => UI.open("zones"));
  document.getElementById("zoneChip").style.cursor = "pointer";
  document.getElementById("promptBtn").addEventListener("click", () => { if (W.near) W.near.act(); });
}
function setDot(id, n) {
  const b = document.getElementById("sb-" + id);
  if (!b) return;
  let d = b.querySelector(".dot");
  if (n > 0) { if (!d) { d = h("span", { class: "dot" }); b.append(d); } d.textContent = n > 9 ? "9+" : n; }
  else if (d) d.remove();
}
UI.hud = function () {
  const t = now();
  document.getElementById("credits").textContent = "₵ " + fmt(S.credits);
  const boost = currentBoost(t);
  document.getElementById("rate").textContent = "+" + fmtRate(totalRate() * boost) + "/s" + (boost > 1 ? " ×" + boost.toLocaleString("pt-BR") : "");
  const fl = flashAt(t), fe = document.getElementById("flash");
  if (fl) { fe.className = "chunk on " + fl.kind; fe.textContent = `${fl.icon} ${fl.name.toUpperCase()} • ${fmtTime(fl.endsAt - t)}`; }
  else { const nf = nextFlash(t); fe.className = "chunk"; fe.textContent = `Próximo: ${nf.icon} ${nf.name} em ${fmtTime(nf.startsAt - t)}`; }
  const bf = document.getElementById("buffs");
  bf.innerHTML = "";
  DATA.potions.order.forEach((id) => { const e = S.activePotions[id] || 0; if (e > t) bf.append(h("span", { class: "buff" }, [POT[id].icon, " ", fmtTime(e - t)])); });
  const ev = activeEvent(t);
  if (ev) bf.append(h("span", { class: "buff" }, "🎃 " + ev.name));
  const L = activeLuck(t, W.zoneId);
  const lc = document.getElementById("luckChip");
  lc.innerHTML = ""; lc.append("🍀 Sorte ", h("b", null, "+" + pct(L.total, 1)));
  const zn = ZONE[W.zoneId];
  document.getElementById("zoneChip").textContent = zn.name.split(" — ")[0] + (zn.luck > 0 ? (S.zones[W.zoneId] ? ` • +${Math.round(zn.luck * 100)}%` : " • bloqueada") : "");
  const need = xpNeeded(S.level);
  document.getElementById("lvl").textContent = "Nv " + S.level;
  document.getElementById("xpfill").style.width = S.level >= PROG.maxLevel ? "100%" : Math.min(100, (S.xp / need) * 100) + "%";
  document.getElementById("xptxt").textContent = S.level >= PROG.maxLevel ? "Nível máximo" : `${fmt(S.xp)} / ${fmt(need)} XP`;
  setDot("missions", missionReadyCount());
  setDot("gifts", claimableCount());
  setDot("bank", S.bank.pending >= storageCap() ? 1 : 0);
  const pr = document.getElementById("prompt");
  if (W.near) { pr.hidden = false; document.getElementById("promptTxt").textContent = W.near.label(); }
  else pr.hidden = true;
  for (const k in UI.live) { const f = UI.live[k]; if (f.el.isConnected) f.el.textContent = f.fn(); else delete UI.live[k]; }
};
function live(key, fn) {
  const el = h("span", { class: "num" }, fn());
  UI.live[key] = { el, fn };
  return el;
}

// ---------------------------------------------------------------- painéis
const PANELS = {};

PANELS.shop = {
  title: "📦 Caixas",
  render(b) {
    const sec = UI.tabs(b, "shop", DATA.sections.map((s) => [s.id, s.name]));
    if (sec === "limited") b.append(h("p", { class: "muted" }, ["Estoque renova todo dia às 00:00 UTC. Renova em ", live("stockReset", () => fmtTime((dayIndex(now()) + 1) * DAY - now())), "."]));
    if (sec === "special") b.append(h("p", { class: "muted" }, "Caixas temáticas que sorteiam skins de várias coleções."));
    const g = h("div", { class: "cases" });
    DATA.cases.filter((c) => c.section === sec).sort((a, b2) => a.order - b2.order).forEach((c) => {
      const locked = S.level < c.requiredLevel;
      const left = stockLeft(c, now());
      const best = c.drops.reduce((m, d) => (tierOf(d.rarity) > tierOf(m.rarity) ? d : m), c.drops[0]);
      g.append(h("div", { class: "case" + (locked ? " lock" : ""), style: `--cc:${rgb(c.color)};--ct:${rgb(c.trim)}` }, [
        c.stockPerDay ? h("span", { class: "badge tag" }, left > 0 ? `${left}/${c.stockPerDay} hoje` : "ESGOTADA") : S.freeCases[c.id] ? h("span", { class: "badge tag" }, S.freeCases[c.id] + " grátis") : null,
        h("div", { class: "box" }),
        h("div", { class: "nm" }, c.name),
        h("div", { class: "pr num" }, locked ? "🔒 Nível " + c.requiredLevel : "₵ " + fmt(c.price)),
        h("div", { class: "muted", style: "font-size:11px;margin-bottom:6px" }, "Até " + rarityName(best.rarity)),
        h("button", { type: "button", class: "btn g s", onclick: () => UI.openCase(c.id) }, locked ? "Ver chances" : "Abrir"),
      ]));
    });
    b.append(g);
  },
};

PANELS.case = {
  title: () => "📦 " + CASE[UI.arg].name,
  render(b) {
    const c = CASE[UI.arg], t = now();
    const L = activeLuck(t, W.zoneId);
    const entries = computeTable(c, L.total);
    const pcts = displayPercents(entries, 3);
    const locked = S.level < c.requiredLevel;
    const left = stockLeft(c, t);
    const free = S.freeCases[c.id] || 0;
    const top = h("div", { class: "row", style: "margin-bottom:10px" }, [
      h("div", { class: "grow" }, [
        h("div", { class: "muted" }, c.theme || ""),
        h("div", null, ["Preço: ", h("b", { style: "color:var(--gold)" }, "₵ " + fmt(c.price)), c.stockPerDay ? ` • Estoque hoje: ${left}/${c.stockPerDay}` : "", free ? ` • ${free} grátis` : ""]),
        h("div", { class: "muted" }, ["Sorte ativa: ", h("b", { style: "color:var(--mint)" }, "+" + pct(L.total, 1)), L.raw > L.total ? " (limite de " + pct(DATA.luck.max) + ")" : "", " — as chances abaixo já incluem a sorte."]),
      ]),
      h("button", { type: "button", class: "btn s", onclick: () => UI.open("shop") }, "← Caixas"),
    ]);
    b.append(top);
    const qWrap = h("div", { class: "row", style: "margin-bottom:12px" });
    const maxQ = maxQuantity();
    [1, 5, 10, 25].forEach((q) => {
      const qLocked = q > maxQ;
      const useFree = free >= q;
      const cost = useFree ? 0 : c.price * q;
      const dis = locked || qLocked || (!useFree && S.credits < cost) || (c.stockPerDay && left < q);
      qWrap.append(h("button", { type: "button", class: "btn " + (q === 1 ? "g" : "y"), disabled: dis, title: qLocked ? "Requer o atributo Abertura ×25" : null, onclick: () => doOpen(c.id, q, useFree) }, qLocked ? `×${q} 🔒` : `×${q} • ${useFree ? "GRÁTIS" : "₵ " + fmt(cost)}`));
    });
    const autoOn = !!UI.auto;
    qWrap.append(h("button", { type: "button", class: "btn " + (autoOn ? "r" : ""), disabled: locked, onclick: () => (autoOn ? stopAuto("Abertura automática parada.") : startAuto(c.id)) }, autoOn ? "PARAR AUTO" : "AUTO ×1"));
    b.append(qWrap);
    if (locked) b.append(h("p", { class: "confirm" }, `Disponível no nível ${c.requiredLevel}. Você está no nível ${S.level}.`));
    const byR = {};
    entries.forEach((e, i) => (byR[e.rarity] = (byR[e.rarity] || 0) + pcts[i]));
    b.append(h("div", { class: "row", style: "margin-bottom:8px" }, RORDER.filter((r) => byR[r] !== undefined).map((r) => h("span", { class: "pill", style: `background:${rc(r)};color:#0b1230` }, `${rarityName(r)} ${byR[r].toLocaleString("pt-BR", { maximumFractionDigits: 3 })}%`))));
    const odds = h("div", { class: "odds" });
    entries.map((e, i) => ({ e, p: pcts[i] })).sort((a, b2) => tierOf(a.e.rarity) - tierOf(b2.e.rarity)).forEach(({ e, p }) => {
      const s = SKIN[e.skinId];
      odds.append(h("div", { class: "odd", style: `--rc:${rc(e.rarity)}` }, [
        iconCanvas(s.id, 152, 76),
        h("div", { style: "min-width:0" }, [h("div", { style: "font-weight:600;font-size:13px" }, s.name), h("div", { class: "muted", style: "font-size:11px" }, `${rarityName(s.rarity)} • ₵ ${fmt(s.value)}${S.discovered[s.id] ? " • descoberta" : ""}`)]),
        h("div", { class: "p" }, p.toLocaleString("pt-BR", { maximumFractionDigits: 3 }) + "%"),
      ]));
    });
    b.append(odds);
    b.append(h("p", { class: "muted", style: "margin-top:10px" }, "As chances somam 100%. O sorteio usa números aleatórios do navegador nesta prévia; no Roblox, o servidor sorteia e os valores nunca vêm do cliente."));
  },
};

PANELS.inventory = {
  title: () => `🎒 Inventário (${itemCount()}/${ECO.InventoryCapacity})`,
  render(b) {
    const f = UI.tabs(b, "inv", [["all", "Todas"]].concat(RORDER.map((r) => [r, rarityName(r)])).concat([["bank", "No banco"]]));
    let items = Object.values(S.inv);
    if (f === "bank") items = items.filter((i) => i.loc === "bank");
    else if (f !== "all") items = items.filter((i) => SKIN[i.defId].rarity === f);
    items.sort((a, c) => SKIN[c.defId].value - SKIN[a.defId].value || c.at - a.at);
    const sel = UI.sel && S.inv[UI.sel] ? S.inv[UI.sel] : null;
    if (sel) b.append(itemDetail(sel));
    const sellable = Object.values(S.inv).filter((i) => i.loc !== "bank" && !i.fav && tierOf(SKIN[i.defId].rarity) <= 2);
    const total = sellable.reduce((a, i) => a + Math.floor(SKIN[i.defId].value * ECO.SellRate), 0);
    b.append(h("div", { class: "row", style: "margin:10px 0" }, [
      h("span", { class: "muted grow" }, `Valor total: ₵ ${fmt(Object.values(S.inv).reduce((a, i) => a + SKIN[i.defId].value, 0))} • toque numa skin para inspecionar`),
      h("button", { type: "button", class: "btn y s", disabled: !sellable.length, onclick: () => UI.confirm("Vender comuns e incomuns", `Vender <b>${sellable.length}</b> skins (exceto favoritas e as do banco) por <b>₵ ${fmt(total)}</b>?`, "Vender", () => handle(sellItems(sellable.map((i) => i.uid), false, false), (r) => `Vendidas ${r.sold} skins por ₵ ${fmt(r.credits)}.`)) }, `Vender comuns/incomuns (₵ ${fmt(total)})`),
    ]));
    if (!items.length) { b.append(h("div", { class: "card muted", style: "text-align:center;padding:24px" }, "Nada aqui ainda. Abra caixas na praça ou no botão CAIXAS.")); return; }
    const g = h("div", { class: "grid" });
    items.slice(0, 300).forEach((it) => g.append(itemCard(it, { sel: sel && sel.uid === it.uid, onclick: () => { UI.sel = it.uid; UI.render(); } })));
    b.append(g);
  },
};
function sellOne(it) {
  const def = SKIN[it.defId];
  const valuable = tierOf(def.rarity) >= ECO.ValuableConfirmTier;
  const doSell = () => { if (handle(sellItems([it.uid], true, true), (r) => `Vendida por ₵ ${fmt(r.credits)}.`)) UI.sel = null, UI.changed(); };
  if (valuable || it.fav) UI.confirm("Confirmar venda", `${it.fav ? "Esta skin é <b>favorita</b>. " : ""}${valuable ? `É uma skin <b>${rarityName(def.rarity)}</b>. ` : ""}Vender <b>${def.name}</b> por <b>₵ ${fmt(def.value)}</b>? Não dá para desfazer.`, "Vender", doSell, { danger: true });
  else doSell();
}
function itemDetail(it) {
  const def = SKIN[it.defId];
  const cv = h("canvas", { id: "inspect", "aria-label": "Inspeção 3D: arraste para girar" });
  const ups = Object.keys(it.up || {}).map((k) => RECIPE[k] ? RECIPE[k].displayName : k);
  const inBank = it.loc === "bank";
  const box2 = h("div", { class: "card", style: `border-color:${rc(def.rarity)}` }, [
    h("div", { class: "row", style: "align-items:flex-start" }, [
      h("div", { class: "grow", style: "min-width:min(100%,260px)" }, [cv, h("div", { class: "muted", style: "text-align:center;font-size:11px;margin-top:4px" }, "Arraste para girar • roda do mouse aproxima")]),
      h("div", { class: "grow", style: "min-width:200px" }, [
        h("h3", null, def.name),
        h("div", { class: "row" }, [h("span", { class: "pill", style: `background:${rc(def.rarity)};color:#0b1230` }, rarityName(def.rarity)), h("span", { class: "tag" }, DATA.categories[def.category].displayName), h("span", { class: "tag" }, CASE[def.caseId] ? CASE[def.caseId].collectionName : "")]),
        h("p", null, ["Valor: ", h("b", { style: "color:var(--gold)" }, "₵ " + fmt(def.value)), h("br"), "Renda no banco: ", h("b", { style: "color:var(--mint)" }, fmtRate(itemIncome(it)) + "/s"), ups.length ? [h("br"), "Melhorias: " + ups.join(", ")] : null].flat()),
        h("div", { class: "row" }, [
          h("button", { type: "button", class: "btn s", onclick: () => { it.fav = !it.fav; markDirty(); UI.changed(); } }, it.fav ? "★ Desfavoritar" : "☆ Favoritar"),
          h("button", { type: "button", class: "btn s", disabled: inBank, onclick: () => handle(equip(it.uid), it.eq ? "Guardada." : "Equipada! Ela aparece na mão do personagem.") }, it.eq ? "Desequipar" : "Equipar"),
          inBank ? h("button", { type: "button", class: "btn s", onclick: () => handle(withdraw(it.uid), "Retirada do banco.") }, "Retirar do banco")
            : h("button", { type: "button", class: "btn g s", onclick: () => handle(deposit(it.uid), "Depositada no banco.") }, "Depositar no banco"),
          h("button", { type: "button", class: "btn s", disabled: inBank, onclick: () => handle(setShowcase(it.uid, !S.showcase[it.uid]), S.showcase[it.uid] ? "Tirada da vitrine." : "Exposta na vitrine.") }, S.showcase[it.uid] ? "Tirar da vitrine" : "Expor na vitrine"),
          h("button", { type: "button", class: "btn s", disabled: inBank, onclick: () => { UI.sel = it.uid; UI.open("workshop"); } }, "Oficina"),
          h("button", { type: "button", class: "btn r s", disabled: inBank, onclick: () => sellOne(it) }, `Vender ₵ ${fmt(def.value)}`),
        ]),
      ]),
    ]),
  ]);
  requestAnimationFrame(() => { if (cv.isConnected) UI.mountInspect(cv, it); });
  return box2;
}

PANELS.bank = {
  title: "🏦 Banco",
  render(b) {
    const t = now();
    settle(t);
    const items = bankItems(), slots = bankSlots(), cap = storageCap();
    const boost = currentBoost(t);
    const pend = h("div", { class: "bar", style: "margin:6px 0" }, h("i", { style: `width:${Math.min(100, (S.bank.pending / cap) * 100)}%` }));
    UI.live.pendBar = { el: h("span"), fn: () => { pend.firstChild.style.width = Math.min(100, (S.bank.pending / cap) * 100) + "%"; return ""; } };
    b.append(h("div", { class: "card sec" }, [
      h("div", { class: "row" }, [
        h("div", { class: "grow" }, [
          h("div", { class: "chunk", style: "font-size:22px;color:var(--mint)" }, ["+", live("rate", () => fmtRate(totalRate() * currentBoost(now()))), " créditos/s"]),
          h("div", { class: "muted" }, `Eficiência ${pct(efficiency() - 1)} • ${boost > 1 ? "bônus ativo ×" + boost.toLocaleString("pt-BR") + " • " : ""}produz até ${fmtTime(offlineCap())} fora do jogo`),
        ]),
        h("button", { type: "button", class: "btn g", onclick: () => handle(claimBank(), (r) => `Resgatado ₵ ${fmt(r.credits)}!`) }, "RESGATAR"),
      ]),
      pend,
      h("div", { class: "muted" }, ["Acumulado: ₵ ", live("pend", () => fmt(S.bank.pending)), ` / ₵ ${fmt(cap)} (cofre)`]),
    ]));
    const slotsEl = h("div", { class: "grid" });
    for (let i = 0; i < slots; i++) {
      const it = items[i];
      if (it) slotsEl.append(h("div", null, [itemCard(it, { onclick: () => handle(withdraw(it.uid), "Retirada do banco.") }), h("div", { class: "muted", style: "text-align:center;font-size:11px" }, "+" + fmtRate(itemIncome(it)) + "/s • toque p/ retirar")]));
      else slotsEl.append(h("div", { class: "card muted", style: "display:flex;align-items:center;justify-content:center;min-height:120px;border-style:dashed" }, "Vaga livre"));
    }
    b.append(h("div", { class: "sec" }, [h("h3", null, `Vagas (${items.length}/${slots})`), slotsEl]));
    const cands = Object.values(S.inv).filter((i) => i.loc !== "bank").sort((a, c) => itemIncome(c) - itemIncome(a)).slice(0, 12);
    if (cands.length) {
      const g = h("div", { class: "grid" });
      cands.forEach((it) => g.append(h("div", null, [itemCard(it, { onclick: () => handle(deposit(it.uid), "Depositada no banco.") }), h("div", { class: "muted", style: "text-align:center;font-size:11px" }, "+" + fmtRate(itemIncome(it)) + "/s")])));
      b.append(h("div", { class: "sec" }, [h("h3", null, "Depositar (melhores primeiro)"), g]));
    }
    const ups = h("div", { class: "list" });
    DATA.bank.order.forEach((id) => {
      const u = BANKUP[id], l = bankUp(id), maxed = l >= u.maxLevel;
      const cost = maxed ? 0 : upgradeCost(id, l), req = maxed ? 0 : u.requiredLevels[l];
      ups.append(h("div", { class: "card row" }, [
        h("div", { class: "grow" }, [h("b", null, `${u.displayName} `), h("span", { class: "tag" }, `${l}/${u.maxLevel}`), h("div", { class: "muted" }, u.description + (maxed ? "" : ` • requer nível ${req}`))]),
        h("button", { type: "button", class: "btn y s", disabled: maxed || S.level < req || S.credits < cost, onclick: () => handle(buyBankUpgrade(id), u.displayName + " melhorada!") }, maxed ? "MÁXIMO" : "₵ " + fmt(cost)),
      ]));
    });
    b.append(h("div", { class: "sec" }, [h("h3", null, "Melhorias do banco"), ups]));
  },
};

PANELS.workshop = {
  title: "🔧 Oficina",
  render(b) {
    b.append(h("div", { class: "row card", style: "margin-bottom:10px" }, Object.keys(MAT_NAMES).map((k) => h("span", { class: "tag", style: "font-size:13px" }, `${MAT_NAMES[k]}: ${S.materials[k] || 0}`)).concat([h("span", { class: "muted" }, "Materiais vêm da venda de skins, missões e presentes.")])));
    const sel = UI.sel && S.inv[UI.sel] && S.inv[UI.sel].loc !== "bank" ? S.inv[UI.sel] : null;
    if (sel) {
      const def = SKIN[sel.defId];
      const list = h("div", { class: "list" });
      DATA.recipes.forEach((r) => {
        const done = sel.up[r.id], low = tierOf(def.rarity) < r.minRarityTier;
        const cost = Math.floor(r.creditsBase + def.value * r.creditsValueFactor + 0.5);
        const mats = Object.keys(r.materials).map((k) => `${r.materials[k]} ${MAT_NAMES[k]}`).join(", ");
        list.append(h("div", { class: "card row" }, [
          h("div", { class: "grow" }, [h("b", null, r.displayName), h("div", { class: "muted" }, r.description), h("div", { class: "muted" }, `Custo: ₵ ${fmt(cost)} + ${mats}${low ? ` • requer ${rarityName(RORDER[r.minRarityTier - 1])} ou melhor` : ""}`)]),
          h("button", { type: "button", class: "btn g s", disabled: done || low, onclick: () => handle(applyUpgrade(sel.uid, r.id), r.displayName + " aplicada!") }, done ? "✔ Feita" : "Aplicar"),
        ]));
      });
      b.append(h("div", { class: "row", style: "align-items:flex-start;margin-bottom:12px" }, [h("div", { style: "width:150px" }, itemCard(sel)), h("div", { class: "grow" }, [h("p", { class: "muted" }, "Cada melhoria entrega o resultado garantido: nada é sorteado e a skin nunca é perdida."), list])]));
    }
    const items = Object.values(S.inv).filter((i) => i.loc !== "bank").sort((a, c) => SKIN[c.defId].value - SKIN[a.defId].value);
    const g = h("div", { class: "grid" });
    items.slice(0, 120).forEach((it) => g.append(itemCard(it, { sel: sel && sel.uid === it.uid, onclick: () => { UI.sel = it.uid; UI.render(); } })));
    b.append(h("h3", null, sel ? "Trocar de skin" : "Escolha uma skin"), items.length ? g : h("p", { class: "muted" }, "Abra caixas para ter skins para melhorar."));
  },
};

PANELS.index = {
  title: () => `📖 Coleção (${Object.keys(S.discovered).length}/${DATA.skins.length})`,
  render(b) {
    const mode = UI.tabs(b, "index", [["col", "Por coleção"], ["rar", "Ver por raridade"]]);
    if (mode === "col") {
      COLLECTIONS.sort((a, c) => a.order - c.order).forEach((c) => {
        const st = collectionStatus(c.id), rw = PROG.collectionRewards[c.id], claimed = S.collectionsClaimed[c.id];
        const g = h("div", { class: "grid" });
        DATA.skins.filter((s) => s.collection === c.id).forEach((s) => g.append(itemCard(s.id, { locked: !S.discovered[s.id], noValue: !S.discovered[s.id] })));
        b.append(h("div", { class: "card sec" }, [
          h("div", { class: "row", style: "margin-bottom:8px" }, [
            h("div", { class: "grow" }, [h("b", null, c.collectionName), " ", h("span", { class: "tag" }, `${st.found}/${st.total}`), h("div", { class: "muted" }, "Prêmio: " + rewardLine(rw))]),
            h("button", { type: "button", class: "btn g s", disabled: !st.complete || claimed, onclick: () => { const r = claimCollection(c.id); handle(r, () => "Coleção concluída: " + r.sum.join(", ")); } }, claimed ? "✔ Resgatado" : st.complete ? "RESGATAR" : "Incompleta"),
          ]),
          h("div", { class: "bar", style: "margin-bottom:8px" }, h("i", { style: `width:${(st.found / st.total) * 100}%` })),
          g,
        ]));
      });
    } else {
      RORDER.slice().reverse().forEach((r) => {
        const list = DATA.skins.filter((s) => s.rarity === r);
        const found = list.filter((s) => S.discovered[s.id]).length;
        const g = h("div", { class: "grid" });
        list.sort((a, c) => c.value - a.value).forEach((s) => g.append(itemCard(s.id, { locked: !S.discovered[s.id], noValue: !S.discovered[s.id] })));
        b.append(h("div", { class: "sec" }, [h("h3", { style: `color:${rc(r)}` }, `${rarityName(r)} — ${found}/${list.length}`), g]));
      });
    }
  },
};

function missionRow(d, prog, claimed, onClaim) {
  const done = prog >= d.target;
  return h("div", { class: "card row" }, [
    h("div", { class: "grow" }, [h("b", null, d.description), h("div", { class: "bar", style: "margin:6px 0" }, h("i", { style: `width:${Math.min(100, (prog / d.target) * 100)}%` })), h("div", { class: "muted" }, `${Math.min(prog, d.target)}/${d.target} • ${rewardLine(d.reward)}`)]),
    h("button", { type: "button", class: "btn g s", disabled: !done || claimed, onclick: onClaim }, claimed ? "✔" : done ? "RESGATAR" : "Em andamento"),
  ]);
}
PANELS.missions = {
  title: "🎯 Missões",
  render(b) {
    const t = now();
    refreshPeriods(t);
    const m = S.missions;
    const claim = (id) => { const r = claimMission(id); handle(r, () => "Missão concluída: " + r.sum.join(", ")); };
    b.append(h("div", { class: "sec" }, [h("h3", null, ["Diárias • renovam em ", live("dReset", () => fmtTime((dayIndex(now()) + 1) * DAY - now()))]), h("div", { class: "list" }, m.daily.map((id) => missionRow(MISSION[id], m.progress[id] || 0, m.claimed[id], () => claim(id))))]));
    b.append(h("div", { class: "sec" }, [h("h3", null, ["Semanais • renovam em ", live("wReset", () => fmtTime(MONDAY_EPOCH + (weekIndex(now()) + 1) * WEEK - now()))]), h("div", { class: "list" }, m.weekly.map((id) => missionRow(MISSION[id], m.progress[id] || 0, m.claimed[id], () => claim(id))))]));
    const ev = activeEvent(t);
    if (ev) {
      const ep = S.eventProgress;
      b.append(h("div", { class: "sec card", style: "border-color:#ff8a1f" }, [
        h("h3", null, ["🎃 ", ev.name, " • termina em ", live("evEnd", () => fmtTime(ev.endsAt - now()))]),
        h("p", { class: "muted" }, ev.description + " +3% de sorte enquanto o evento durar."),
        h("div", { class: "list" }, ev.challenges.map((c) => missionRow(c, ep.progress[c.id] || 0, ep.claimed[c.id], () => { const r = claimEventChallenge(c.id); handle(r, () => "Desafio concluído: " + r.sum.join(", ")); }))),
      ]));
    } else {
      const nx = nextEvent(t);
      if (nx) b.append(h("p", { class: "muted sec" }, `Próximo evento: ${nx.name}, em ${fmtTime(nx.startsAt - t)}.`));
    }
  },
};

PANELS.gifts = {
  title: "🎁 Presentes",
  render(b) {
    const t = now(), st = dailyStatus(t);
    const row = h("div", { class: "grid", style: "grid-template-columns:repeat(auto-fill,minmax(96px,1fr))" });
    PROG.dailyRewards.forEach((r, i) => {
      const day = i + 1, got = day <= st.streak && (!st.available || day < st.next), isNext = st.available && day === st.next;
      row.append(h("div", { class: "card", style: `text-align:center;${isNext ? "border-color:var(--gold)" : ""}${got ? "opacity:.6" : ""}` }, [h("div", { class: "chunk" }, "Dia " + day), h("div", { class: "muted", style: "font-size:11px" }, rewardLine(r)), got ? h("div", null, "✔") : null]));
    });
    b.append(h("div", { class: "sec" }, [
      h("div", { class: "row" }, [h("h3", { class: "grow" }, "Presente diário"), h("button", { type: "button", class: "btn g", disabled: !st.available, onclick: () => { const r = claimDaily(); handle(r, () => "Presente: " + r.sum.join(", ")); } }, st.available ? "RESGATAR" : ["Volte em ", live("dg", () => fmtTime((dayIndex(now()) + 1) * DAY - now()))])]),
      row,
    ]));
    const lv = h("div", { class: "list" });
    Object.keys(PROG.levelRewards).map(Number).sort((a, c) => a - c).forEach((l) => {
      const claimed = S.rewards.levelClaimed[l];
      if (l > S.level + 15 && !claimed) return;
      lv.append(h("div", { class: "card row" }, [h("div", { class: "grow" }, [h("b", null, "Nível " + l), h("div", { class: "muted" }, rewardLine(PROG.levelRewards[l]))]), h("button", { type: "button", class: "btn g s", disabled: claimed || S.level < l, onclick: () => { const r = claimLevel(l); handle(r, () => "Prêmio de nível: " + r.sum.join(", ")); } }, claimed ? "✔" : S.level >= l ? "RESGATAR" : "🔒")]));
    });
    b.append(h("div", { class: "sec" }, [h("h3", null, "Prêmios por nível"), lv]));
    const ach = h("div", { class: "list" });
    DATA.achievements.forEach((a) => {
      const v = statValue(a.stat), done = v >= a.target, claimed = S.achievementsClaimed[a.id];
      ach.append(h("div", { class: "card row" }, [
        h("div", { class: "grow" }, [h("b", null, a.name), " ", h("span", { class: "muted" }, a.description), h("div", { class: "bar", style: "margin:6px 0" }, h("i", { style: `width:${Math.min(100, (v / a.target) * 100)}%` })), h("div", { class: "muted" }, rewardLine(a.reward) + " • +120 XP")]),
        h("button", { type: "button", class: "btn g s", disabled: !done || claimed, onclick: () => { const r = claimAchievement(a.id); handle(r, () => "Conquista: " + r.sum.join(", ")); } }, claimed ? "✔" : done ? "RESGATAR" : fmt(Math.min(v, a.target)) + "/" + fmt(a.target)),
      ]));
    });
    b.append(h("div", { class: "sec" }, [h("h3", null, "Conquistas"), ach]));
  },
};

PANELS.attributes = {
  title: "⭐ Atributos",
  render(b) {
    const list = h("div", { class: "list" });
    DATA.attributes.forEach((a) => {
      const i = attrInfo(a.id), maxed = i.level >= i.max;
      list.append(h("div", { class: "card row" }, [
        h("div", { class: "grow" }, [h("b", null, a.displayName + " "), h("span", { class: "tag" }, `${i.level}/${i.max}`), h("div", { class: "muted" }, a.description), h("div", { style: "font-size:13px" }, ["Agora: ", h("b", null, i.benefit), i.next ? ["  →  ", h("b", { style: "color:var(--mint)" }, i.next)] : null].flat()), a.linkedBankUpgrade ? h("div", { class: "muted" }, "Mesma melhoria do Banco.") : null, !maxed ? h("div", { class: "muted" }, "Requer nível " + i.req) : null]),
        h("button", { type: "button", class: "btn y s", disabled: maxed || S.level < i.req || S.credits < i.cost, onclick: () => handle(buyAttribute(a.id), a.displayName + " melhorado!") }, maxed ? "MÁXIMO" : "₵ " + fmt(i.cost)),
      ]));
    });
    b.append(list);
  },
};

PANELS.potions = {
  title: "🧪 Poções",
  render(b) {
    const t = now();
    const list = h("div", { class: "list" });
    DATA.potions.order.forEach((id) => {
      const p = POT[id], end = S.activePotions[id] || 0;
      list.append(h("div", { class: "card row" }, [
        h("div", { class: "chunk", style: "font-size:34px" }, p.icon),
        h("div", { class: "grow" }, [h("b", null, `${p.displayName} `), h("span", { class: "tag" }, `${S.potions[id] || 0} guardadas`), h("div", { class: "muted" }, `${p.description} Dura ${fmtTime(p.duration)} (acumula até ${fmtTime(p.maxStack)}).`), end > t ? h("div", { style: "color:var(--mint)" }, ["Ativa: ", live("p" + id, () => fmtTime((S.activePotions[id] || 0) - now()))]) : null]),
        h("button", { type: "button", class: "btn g s", disabled: !(S.potions[id] > 0), onclick: () => handle(activatePotion(id), p.displayName + " ativada!") }, "USAR"),
      ]));
    });
    b.append(list);
    b.append(h("p", { class: "muted sec" }, "Poções vêm de prêmios de nível, presentes diários, missões e conquistas. Elas nunca são vendidas por Robux."));
    const nf = nextFlash(t), fl = flashAt(t);
    b.append(h("div", { class: "card sec" }, [h("h3", null, "Eventos 2X"), h("p", { class: "muted" }, `A cada 3 horas, por 20 minutos, um evento relâmpago dobra a sorte, o XP ou a renda do banco para todos. ${fl ? "Ativo agora: " + fl.name + "." : "Próximo: " + nf.name + " em " + fmtTime(nf.startsAt - t) + "."}`)]));
  },
};

PANELS.zones = {
  title: "🗺️ Zonas do mapa",
  render(b) {
    b.append(h("p", { class: "muted" }, ["Cada zona desbloqueada dá sorte extra enquanto você estiver dentro dela. Você está em: ", h("b", null, ZONE[W.zoneId].name), "."]));
    const list = h("div", { class: "list" });
    DATA.zones.forEach((z) => {
      const owned = S.zones[z.id], prevOk = !z.requires || S.zones[z.requires];
      const req = [];
      if (z.cost > 0) req.push("₵ " + fmt(z.cost));
      if (z.requiredLevel > 1) req.push("nível " + z.requiredLevel);
      if (z.requires) req.push("depois da " + ZONE[z.requires].name.split(" — ")[0]);
      list.append(h("div", { class: "card row", style: `border-color:${rgb(z.color)}` }, [
        h("div", { class: "grow" }, [h("b", null, z.name), z.luck > 0 ? h("span", { style: "color:var(--mint)" }, `  +${Math.round(z.luck * 100)}% sorte`) : null, h("div", { class: "muted" }, owned ? "✔ Desbloqueada" : "Requer: " + req.join(" • "))]),
        owned ? null : h("button", { type: "button", class: "btn y s", disabled: !prevOk || S.level < z.requiredLevel || S.credits < z.cost, onclick: () => handle(buyZone(z.id), z.name + " desbloqueada! A barreira sumiu.") }, "Desbloquear"),
      ]));
    });
    b.append(list);
  },
};

PANELS.luck = {
  title: "🍀 Sua sorte",
  render(b) {
    const L = activeLuck(now(), W.zoneId);
    b.append(h("p", null, ["Total: ", h("b", { style: "color:var(--mint)" }, "+" + pct(L.total, 1)), ` (limite +${pct(DATA.luck.max)}). A sorte só aumenta o peso de Raras ou melhores; as chances finais aparecem em cada caixa.`]));
    const list = h("div", { class: "list" });
    if (!L.list.length) list.append(h("div", { class: "card muted" }, "Nenhuma fonte de sorte ativa. Entre numa zona desbloqueada, use uma Poção da Sorte ou aguarde um 2X Evento de Trevo."));
    L.list.forEach((e) => list.append(h("div", { class: "card row" }, [h("span", { class: "grow" }, e.name), h("b", { style: "color:var(--mint)" }, "+" + pct(e.luck, 1))])));
    b.append(list);
  },
};

PANELS.rebirth = {
  title: "♻️ Renascer",
  render(b) {
    const p = rebirthPreview();
    b.append(h("div", { class: "card" }, [
      h("p", null, `Renascimentos: ${S.rebirths}. O próximo exige nível ${p.reqLevel} e patrimônio de ₵ ${fmt(p.reqWorth)} (você tem nível ${S.level} e ₵ ${fmt(p.worth)}).`),
      h("p", { class: "muted" }, `Você mantém ${p.keep} skins (Raras ou melhores e favoritas), a coleção, conquistas e zonas. Perde ${p.lose} skins comuns/incomuns, créditos, nível e melhorias do banco.`),
      h("p", { class: "muted" }, `Bônus permanentes: +${pct(RB.LuckPerRebirth)} de sorte e +${pct(RB.BankEfficiencyPerRebirth)} de renda por renascimento, +1 vaga no banco a cada ${RB.ExtraBankSlotEvery}.`),
      h("button", { type: "button", class: "btn r", disabled: !p.can, onclick: () => UI.confirm("Renascer", `Digite <b>${RB.ConfirmPhrase}</b> para confirmar. Não dá para desfazer.`, "Renascer", (ph) => handle(rebirth(ph), "Você renasceu! Bônus permanentes aplicados."), { danger: true, phrase: RB.ConfirmPhrase }) }, p.can ? "RENASCER" : "Requisitos não atingidos"),
    ]));
  },
};

PANELS.ranking = {
  title: "🏆 Ranking",
  render(b) {
    b.append(h("p", { class: "muted" }, "No Roblox, o ranking compara os jogadores do servidor. Nesta prévia só existe você, então aparecem os seus números."));
    const stats = [["Patrimônio", "₵ " + fmt(netWorth())], ["Renda do banco", fmtRate(totalRate()) + "/s"], ["Caixas abertas", fmt(S.stats.casesOpened)], ["Skins descobertas", `${Object.keys(S.discovered).length}/${DATA.skins.length}`], ["Melhor drop", "₵ " + fmt(S.stats.bestDropValue)], ["Nível", S.level], ["Renascimentos", S.rebirths]];
    b.append(h("div", { class: "list" }, stats.map(([k, v], i) => h("div", { class: "card row" }, [h("span", { class: "chunk", style: "width:28px;color:var(--gold)" }, "#1"), h("span", { class: "grow" }, k), h("b", { class: "num" }, String(v))]))));
  },
};

PANELS.showroom = {
  title: () => `🏛️ Vitrine (${Object.keys(S.showcase).length}/${ECO.ShowcaseSlots})`,
  render(b) {
    b.append(h("p", { class: "muted" }, "As skins expostas aparecem nos pedestais em frente ao prédio VITRINE. Escolha no inventário com “Expor na vitrine”."));
    const g = h("div", { class: "grid" });
    Object.keys(S.showcase).filter((u) => S.inv[u]).forEach((u) => g.append(itemCard(S.inv[u], { onclick: () => handle(setShowcase(u, false), "Tirada da vitrine.") })));
    b.append(g.children.length ? g : h("div", { class: "card muted" }, "Vitrine vazia."));
    b.append(h("div", { class: "row sec" }, [h("button", { type: "button", class: "btn", onclick: () => UI.open("inventory") }, "Abrir inventário")]));
  },
};

PANELS.settings = {
  title: "⚙️ Ajustes e teste",
  render(b) {
    const tog = (k, label) => h("button", { type: "button", class: "btn s " + (S.settings[k] ? "g" : ""), onclick: () => { S.settings[k] = !S.settings[k]; markDirty(); UI.render(true); } }, (S.settings[k] ? "✔ " : "") + label);
    b.append(h("div", { class: "sec" }, [h("h3", null, "Abertura"), h("div", { class: "row" }, [tog("fast", "Modo rápido"), tog("skip", "Pular animação"), tog("reduce", "Reduzir efeitos")])]));
    b.append(h("div", { class: "sec card" }, [
      h("h3", null, "Ferramentas de teste (só nesta prévia)"),
      h("p", { class: "muted" }, "Atalhos para testar sistemas avançados rapidamente. Não existem no jogo do Roblox."),
      h("div", { class: "row" }, [
        h("button", { type: "button", class: "btn y s", onclick: () => { S.credits += 10000; markDirty(); UI.changed(); toast("+₵ 10.000", "good"); } }, "+₵ 10.000"),
        h("button", { type: "button", class: "btn y s", onclick: () => { S.credits += 250000; markDirty(); UI.changed(); toast("+₵ 250.000", "good"); } }, "+₵ 250.000"),
        h("button", { type: "button", class: "btn s", onclick: () => { for (let i = 0; i < 5; i++) giveXp(xpNeeded(S.level) - S.xp, null, now()); markDirty(); UI.changed(); } }, "+5 níveis"),
        h("button", { type: "button", class: "btn s", onclick: () => { DATA.potions.order.forEach((k) => (S.potions[k] = (S.potions[k] || 0) + 1)); markDirty(); UI.changed(); toast("+1 de cada poção", "good"); } }, "+1 de cada poção"),
        h("button", { type: "button", class: "btn s", onclick: () => { S.bank.lastTick -= 3600; settle(now()); markDirty(); UI.changed(); toast("Banco avançou 1 hora.", "good"); } }, "Banco +1 hora"),
        h("button", { type: "button", class: "btn s", onclick: () => { const t = now(); const ty = F.types[(UI.flashI = ((UI.flashI || 0) + 1)) % F.types.length]; flashOverride = Object.assign({}, ty, { startsAt: t, endsAt: t + 120 }); UI.changed(); toast("Teste: " + ty.name + " por 2 minutos.", "good"); } }, "Forçar evento 2X (2 min)"),
        h("button", { type: "button", class: "btn r s", onclick: () => UI.confirm("Apagar progresso", "Apagar todo o progresso desta prévia e começar com ₵ 500?", "Apagar", () => { S = newProfile(); save(); W.pos.set(0, 0, 58); W.dirty = true; UI.close(); UI.hud(); toast("Progresso apagado.", "good"); }, { danger: true }) }, "Apagar progresso"),
      ]),
    ]));
    b.append(h("p", { class: "muted sec" }, "O progresso fica salvo só neste navegador. Bloqueados no projeto: apostas, troca entre jogadores, PvP, monstros e compra de sorte por Robux."));
  },
};

// ---------------------------------------------------------------- abertura com roleta
let spinning = false;
function doOpen(caseId, qty, useFree) {
  if (spinning) return;
  const res = openCases(caseId, qty, useFree, W.zoneId);
  if (!res.ok) { toast(res.msg, "bad"); if (UI.auto) stopAuto(); return; }
  W.dirty = true;
  UI.hud();
  playSpin(caseId, qty, res);
}
function playSpin(caseId, qty, res) {
  spinning = true;
  const sp = document.getElementById("spin");
  sp.innerHTML = ""; sp.hidden = false;
  const c = CASE[caseId];
  sp.append(h("div", { class: "chunk", style: "font-size:24px" }, `${c.name} ×${qty}${res.useFree ? " (grátis)" : ""}`));
  const animate = !S.settings.skip && qty <= ECO.Opening.MaxAnimatedStrips;
  const base = S.settings.fast ? ECO.Opening.FastSpinSeconds : qty > 1 ? ECO.Opening.MultiSpinSeconds : ECO.Opening.NormalSpinSeconds;
  const dur = base * speedFactor() * (UI.auto ? 0.6 : 1);
  const finish = () => showResults(caseId, qty, res);
  if (!animate) { sp.append(h("div", { class: "muted" }, "Sorteando…")); setTimeout(finish, 450); return; }
  const reels = h("div", { class: "reels" });
  sp.append(reels);
  const small = qty > 1;
  const cw = small ? 84 : innerWidth < 560 ? 104 : 140, gap = 6, WIN = 52;
  const strips = [];
  res.results.forEach((r) => {
    const reel = h("div", { class: "reel" + (small ? " sm" : "") }, [h("div", { class: "mark" })]);
    const strip = h("div", { class: "strip" });
    for (let i = 0; i < WIN + 6; i++) {
      const id = i === WIN ? r.defId : pickEntry(res.entries, Math.random()).skinId;
      strip.append(h("div", { class: "cell", style: `--rc:${rc(SKIN[id].rarity)}` }, iconCanvas(id, small ? 80 : 140, small ? 40 : 70)));
    }
    reel.append(strip); reels.append(reel); strips.push({ reel, strip });
  });
  sp.append(h("button", { type: "button", class: "btn s", onclick: () => { strips.forEach((s) => { s.strip.style.transition = "none"; }); clearTimeout(UI.spinT); finish(); } }, "Pular"));
  requestAnimationFrame(() => requestAnimationFrame(() => {
    strips.forEach(({ reel, strip }) => {
      const jitter = (Math.random() - 0.5) * cw * 0.7;
      const x = -(WIN * (cw + gap) + cw / 2 - reel.clientWidth / 2) + jitter;
      strip.style.transition = `transform ${dur}s cubic-bezier(.12,.72,.14,1)`;
      strip.style.transform = `translateX(${x}px)`;
    });
  }));
  UI.spinT = setTimeout(finish, dur * 1000 + 250);
}
function showResults(caseId, qty, res) {
  if (!spinning) return;
  const sp = document.getElementById("spin");
  sp.innerHTML = "";
  const its = res.results.map((r) => S.inv[r.uid]).filter(Boolean);
  const bestTier = Math.max.apply(null, res.results.map((r) => tierOf(SKIN[r.defId].rarity)));
  const total = its.reduce((a, i) => a + SKIN[i.defId].value, 0);
  const cost = res.cost;
  const bestR = RORDER[bestTier - 1];
  if (bestTier >= 4 && !S.settings.reduce) {
    sp.style.background = `radial-gradient(circle, color-mix(in srgb, ${rc(bestR)} 45%, transparent), rgba(5,9,26,.9) 70%)`;
  } else sp.style.background = "";
  sp.append(h("div", { class: "chunk burst", style: `font-size:${bestTier >= 5 ? 40 : 28}px;color:${rc(bestR)}` }, bestTier >= 6 ? "SECRETA!!!" : bestTier >= 5 ? "LENDÁRIA!" : bestTier >= 4 ? "ÉPICA!" : "Você ganhou"));
  sp.append(h("div", { class: "muted" }, `Valor obtido: ₵ ${fmt(total)} • gasto: ₵ ${fmt(cost)}`));
  const g = h("div", { class: "grid" });
  res.results.forEach((r) => { const it = S.inv[r.uid]; if (it) { const el = itemCard(it, { isNew: r.isNew }); if (tierOf(SKIN[it.defId].rarity) >= 4 && !S.settings.reduce) el.classList.add("hl", "burst"); g.append(el); } });
  sp.append(h("div", { id: "results" }, g));
  const cheap = its.filter((i) => tierOf(SKIN[i.defId].rarity) < ECO.ValuableConfirmTier && !i.fav);
  const cheapV = cheap.reduce((a, i) => a + SKIN[i.defId].value, 0);
  const done = () => { sp.hidden = true; sp.innerHTML = ""; sp.style.background = ""; spinning = false; UI.changed(); flushLevelUps(); };
  const c = CASE[caseId];
  const again = h("button", { type: "button", class: "btn g", onclick: () => { done(); doOpen(caseId, qty, (S.freeCases[caseId] || 0) >= qty); } }, `Abrir de novo ×${qty} • ₵ ${fmt(c.price * qty)}`);
  sp.append(h("div", { class: "row", style: "justify-content:center" }, [
    h("button", { type: "button", class: "btn", onclick: done }, "Guardar"),
    h("button", { type: "button", class: "btn y", disabled: !cheap.length, onclick: () => { handle(sellItems(cheap.map((i) => i.uid), false, false), (r) => `Vendidas ${r.sold} por ₵ ${fmt(r.credits)}.`); done(); } }, cheap.length === its.length ? `Vender tudo ₵ ${fmt(cheapV)}` : `Vender abaixo de Lendária ₵ ${fmt(cheapV)}`),
    again,
    UI.auto ? h("button", { type: "button", class: "btn r", onclick: () => { stopAuto("Abertura automática parada."); done(); } }, "PARAR AUTO") : null,
  ]));
  flushLevelUps();
  if (UI.auto) {
    UI.auto.count++;
    const a = UI.auto;
    const elapsed = now() - a.started;
    if (a.count >= ECO.Opening.AutoMaxOpensPerSession || elapsed >= ECO.Opening.AutoMaxSessionSeconds) { stopAuto(`Abertura automática pausada no limite (${a.count} caixas). Inicie de novo quando quiser.`); return; }
    if (bestTier >= 5) { stopAuto("Abertura automática parada: você tirou uma " + rarityName(bestR) + "!"); return; }
    UI.autoT = setTimeout(() => { if (!UI.auto) return; done(); doOpen(caseId, 1, (S.freeCases[caseId] || 0) >= 1); }, Math.max(ECO.Opening.AutoMinInterval, 1.1) * 1000);
  }
}
function startAuto(caseId) {
  UI.auto = { caseId, count: 0, started: now() };
  toast("Abertura automática ligada. Para sozinha em Lendária+, sem créditos ou no limite.", "good");
  doOpen(caseId, 1, (S.freeCases[caseId] || 0) >= 1);
}
function stopAuto(msg) {
  clearTimeout(UI.autoT);
  UI.auto = null;
  if (msg) toast(msg);
  if (UI.cur === "case") UI.render(true);
}
function flushLevelUps() {
  while (pendingLevelUps.length) {
    const l = pendingLevelUps.shift();
    toast(`⬆️ Nível ${l}!${PROG.levelRewards[String(l)] ? " Prêmio em Presentes." : ""}`, "good");
    W.dirty = true;
  }
}
