// ============================================================================
// Mundo 3D: lobby, zonas, prédios, caixas, personagem e câmera (three.js r128)
// ============================================================================

const W = {
  scene: null, camera: null, renderer: null, clock: null,
  player: null, held: null, nameTag: null,
  pos: new THREE.Vector3(0, 0, 58), vel: new THREE.Vector3(), yaw: Math.PI, onGround: true, walkT: 0,
  camYaw: 0, camPitch: 0.38, camDist: 22,
  colliders: [], interactables: [], zoneBarriers: {}, zoneSigns: {}, casePedestals: [], spinners: [], floaters: [],
  showroomSlots: [], keys: {}, joy: { x: 0, y: 0, active: false }, zoneId: "zone1", near: null,
};

// ---------------------------------------------------------------- utilidades de textura
function canvasTex(w, h, draw) {
  const c = document.createElement("canvas");
  c.width = w; c.height = h;
  draw(c.getContext("2d"), w, h);
  const t = new THREE.CanvasTexture(c);
  t.anisotropy = 4;
  return t;
}
function roundRect(g, x, y, w, h, r) {
  g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
}
// placa com texto em várias linhas: [{t, size, color}]
function signTexture(lines, bg, border, w, h) {
  return canvasTex(w || 512, h || 256, (g, W2, H2) => {
    g.fillStyle = border || "#0b1230"; roundRect(g, 0, 0, W2, H2, 34); g.fill();
    g.fillStyle = bg || "#2a3a80"; roundRect(g, 10, 10, W2 - 20, H2 - 20, 26); g.fill();
    const total = lines.reduce((a, l) => a + l.size * 1.12, 0);
    let y = H2 / 2 - total / 2;
    g.textAlign = "center"; g.textBaseline = "top";
    lines.forEach((l) => {
      g.font = `${l.size}px "Lilita One", "Trebuchet MS", sans-serif`;
      g.lineWidth = Math.max(4, l.size / 7); g.strokeStyle = "#0b1230"; g.lineJoin = "round";
      g.strokeText(l.t, W2 / 2, y, W2 - 40);
      g.fillStyle = l.color || "#fff"; g.fillText(l.t, W2 / 2, y, W2 - 40);
      y += l.size * 1.12;
    });
  });
}
function makeSprite(tex, sx, sy) {
  const m = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false });
  const s = new THREE.Sprite(m);
  s.scale.set(sx, sy, 1);
  return s;
}
function mat(color, opts) { return new THREE.MeshStandardMaterial(Object.assign({ color, roughness: 0.75, metalness: 0.05 }, opts || {})); }
function box(w, h, d, m, x, y, z, parent) {
  const me = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m);
  me.position.set(x || 0, y || 0, z || 0);
  me.castShadow = true; me.receiveShadow = true;
  if (parent) parent.add(me);
  return me;
}
const col3 = (c) => new THREE.Color(c[0] / 255, c[1] / 255, c[2] / 255);

// ---------------------------------------------------------------- arma 3D (inspeção, mão, vitrine)
function patternTexture(v) {
  return canvasTex(128, 64, (g, w, h) => {
    g.fillStyle = rgb(v.primary); g.fillRect(0, 0, w, h);
    g.fillStyle = rgb(v.secondary);
    if (v.pattern === "bands") for (let x = 0; x < w; x += 32) g.fillRect(x, 0, 12, h);
    else if (v.pattern === "stripes") { g.save(); g.translate(w / 2, h / 2); g.rotate(-0.6); for (let x = -w; x < w; x += 22) g.fillRect(x, -h, 9, h * 2); g.restore(); }
    else if (v.pattern === "panels") { for (let x = 0; x < w; x += 32) for (let y = 0; y < h; y += 32) if (((x + y) / 32) % 2 === 0) g.fillRect(x + 3, y + 3, 26, 26); }
    g.fillStyle = rgb(v.accent); g.fillRect(0, h - 6, w, 6);
  });
}
function buildWeapon(skin, up) {
  up = up || {};
  const v = skin.visual;
  const g = new THREE.Group();
  const metal = up.finish ? { metalness: 0.65, roughness: 0.25 } : { metalness: 0.15, roughness: 0.6 };
  const emi = v.glow || up.holo ? { emissive: col3(v.accent), emissiveIntensity: up.holo ? 0.55 : 0.35 } : {};
  const body = mat(0xffffff, Object.assign({ map: patternTexture(v) }, metal, emi));
  const sec = mat(col3(v.secondary), metal);
  const acc = up.gold ? mat(0xffc93c, { metalness: 0.9, roughness: 0.2 }) : mat(col3(v.accent), Object.assign({}, metal, emi));
  const dark = mat(0x22252e, { metalness: 0.5, roughness: 0.4 });
  const cat = skin.category;
  if (cat === "Pistol") {
    box(2.0, 0.45, 0.34, body, 0.2, 0.35, 0, g);
    box(0.7, 0.12, 0.2, dark, 1.4, 0.35, 0, g);
    const grip = box(0.5, 1.1, 0.3, sec, -0.45, -0.25, 0, g); grip.rotation.z = -0.25;
    box(0.5, 0.08, 0.2, acc, 0.15, -0.05, 0, g);
  } else if (cat === "Rifle") {
    box(2.6, 0.55, 0.36, body, 0, 0.2, 0, g);
    box(1.5, 0.14, 0.14, dark, 2.0, 0.28, 0, g);
    box(1.1, 0.5, 0.3, sec, -1.8, 0.05, 0, g);
    const mag = box(0.35, 0.9, 0.24, acc, 0.4, -0.45, 0, g); mag.rotation.z = 0.25;
    const grip = box(0.32, 0.7, 0.26, sec, -0.5, -0.35, 0, g); grip.rotation.z = -0.3;
    box(0.9, 0.12, 0.18, acc, 0.2, 0.55, 0, g);
  } else if (cat === "SMG") {
    box(2.0, 0.6, 0.36, body, 0, 0.2, 0, g);
    box(0.8, 0.14, 0.14, dark, 1.4, 0.3, 0, g);
    box(0.7, 0.22, 0.2, sec, -1.3, 0.25, 0, g);
    box(0.28, 1.0, 0.22, acc, 0.3, -0.55, 0, g);
    const grip = box(0.3, 0.65, 0.26, sec, -0.4, -0.3, 0, g); grip.rotation.z = -0.3;
  } else if (cat === "Sniper") {
    box(3.2, 0.48, 0.34, body, 0, 0.2, 0, g);
    box(2.4, 0.12, 0.12, dark, 2.8, 0.25, 0, g);
    box(1.4, 0.55, 0.3, sec, -2.2, 0.05, 0, g);
    const sc = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.17, 1.5, 14), acc);
    sc.rotation.z = Math.PI / 2; sc.position.set(0.1, 0.68, 0); sc.castShadow = true; g.add(sc);
    const grip = box(0.3, 0.65, 0.26, sec, -0.8, -0.3, 0, g); grip.rotation.z = -0.3;
    box(0.3, 0.6, 0.22, acc, 0.5, -0.3, 0, g);
  } else {
    const shape = new THREE.Shape();
    shape.moveTo(0, -0.22); shape.lineTo(2.1, -0.08); shape.quadraticCurveTo(2.5, 0.05, 2.3, 0.28); shape.lineTo(0, 0.26); shape.lineTo(0, -0.22);
    const blade = new THREE.Mesh(new THREE.ExtrudeGeometry(shape, { depth: 0.08, bevelEnabled: true, bevelSize: 0.03, bevelThickness: 0.02, bevelSegments: 1 }), body);
    blade.position.set(0, 0, -0.04); blade.castShadow = true; g.add(blade);
    box(0.14, 0.75, 0.3, acc, -0.05, 0.02, 0, g);
    box(1.1, 0.34, 0.26, sec, -0.65, 0.02, 0, g);
  }
  if (up.particles) {
    const n = 40, pos = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) { pos[i * 3] = (Math.random() - 0.5) * 4; pos[i * 3 + 1] = (Math.random() - 0.5) * 1.6; pos[i * 3 + 2] = (Math.random() - 0.5) * 1; }
    const geo = new THREE.BufferGeometry(); geo.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    const pts = new THREE.Points(geo, new THREE.PointsMaterial({ color: col3(v.accent), size: 0.12, transparent: true, opacity: 0.9 }));
    pts.userData.sparkle = true; g.add(pts);
  }
  if (up.holo) g.userData.holo = body;
  return g;
}

// ---------------------------------------------------------------- ícone 2D (cartões)
const iconCache = {};
function weaponIcon(skinId) {
  if (iconCache[skinId]) return iconCache[skinId];
  const s = SKIN[skinId], v = s.visual;
  const c = document.createElement("canvas"); c.width = 200; c.height = 100;
  const g = c.getContext("2d");
  g.translate(100, 52);
  const pat = g.createPattern(patternTexture(v).image, "repeat");
  const P = pat || rgb(v.primary), S2 = rgb(v.secondary), A = rgb(v.accent), D = "#23262f";
  const r = (x, y, w, h, f, rot) => { g.save(); g.translate(x, y); if (rot) g.rotate(rot); g.fillStyle = f; g.fillRect(-w / 2, -h / 2, w, h); g.strokeStyle = "rgba(0,0,0,.45)"; g.lineWidth = 2; g.strokeRect(-w / 2, -h / 2, w, h); g.restore(); };
  const k = s.category;
  if (k === "Pistol") { r(-26, 18, 20, 40, S2, 0.25); r(6, -6, 92, 22, P); r(60, -6, 22, 6, D); r(2, 8, 24, 5, A); }
  else if (k === "Rifle") { r(-70, -2, 44, 22, S2); r(-4, -6, 104, 24, P); r(66, -4, 46, 6, D); r(12, 22, 14, 34, A, 0.25); r(-22, 18, 12, 26, S2, -0.3); r(4, -22, 36, 6, A); }
  else if (k === "SMG") { r(-58, -6, 30, 10, S2); r(0, -4, 80, 28, P); r(52, -4, 30, 7, D); r(10, 26, 12, 38, A); r(-16, 16, 12, 24, S2, -0.3); }
  else if (k === "Sniper") { r(-74, -2, 40, 20, S2); r(-8, -4, 96, 18, P); r(70, -3, 54, 5, D); r(-4, -22, 50, 12, A); r(-28, 14, 12, 24, S2, -0.3); r(14, 14, 10, 22, A); }
  else {
    g.save(); g.beginPath(); g.moveTo(-10, -12); g.lineTo(72, -4); g.quadraticCurveTo(90, 2, 82, 12); g.lineTo(-10, 12); g.closePath();
    g.fillStyle = P; g.fill(); g.strokeStyle = "rgba(0,0,0,.45)"; g.lineWidth = 2; g.stroke(); g.restore();
    r(-14, 0, 6, 32, A); r(-44, 0, 50, 16, S2);
  }
  iconCache[skinId] = c;
  return c;
}
function iconCanvas(skinId, w, h) {
  const c = document.createElement("canvas"); c.width = w || 160; c.height = h || 80;
  c.getContext("2d").drawImage(weaponIcon(skinId), 0, 0, c.width, c.height);
  return c;
}

// ---------------------------------------------------------------- cenário
function buildWorld() {
  const host = document.getElementById("game");
  const r = new THREE.WebGLRenderer({ antialias: true });
  r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  r.setSize(host.clientWidth, host.clientHeight);
  r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
  host.appendChild(r.domElement);
  W.renderer = r;
  const sc = new THREE.Scene();
  W.scene = sc;
  sc.background = canvasTex(4, 256, (g) => { const gr = g.createLinearGradient(0, 0, 0, 256); gr.addColorStop(0, "#3f8fe6"); gr.addColorStop(0.6, "#9fd6ff"); gr.addColorStop(1, "#dff3ff"); g.fillStyle = gr; g.fillRect(0, 0, 4, 256); });
  sc.fog = new THREE.Fog(0xcde9ff, 160, 520);
  W.camera = new THREE.PerspectiveCamera(60, host.clientWidth / host.clientHeight, 0.5, 1200);
  W.clock = new THREE.Clock();

  sc.add(new THREE.HemisphereLight(0xdff1ff, 0x5c7a3a, 0.75));
  const sun = new THREE.DirectionalLight(0xfff4dc, 0.95);
  sun.position.set(60, 120, 40); sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  const sh = sun.shadow.camera; sh.left = -90; sh.right = 90; sh.top = 90; sh.bottom = -90; sh.far = 400;
  sc.add(sun); sc.add(sun.target);
  W.sun = sun;

  // chão
  const grass = canvasTex(256, 256, (g) => {
    g.fillStyle = "#62b746"; g.fillRect(0, 0, 256, 256);
    g.fillStyle = "#5aad3f"; for (let x = 0; x < 256; x += 64) for (let y = 0; y < 256; y += 64) if ((x + y) % 128 === 0) g.fillRect(x, y, 64, 64);
  });
  grass.wrapS = grass.wrapT = THREE.RepeatWrapping; grass.repeat.set(40, 40);
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(700, 700), mat(0xffffff, { map: grass }));
  ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; sc.add(ground);

  // praça e caminhos
  const stone = canvasTex(256, 256, (g) => {
    g.fillStyle = "#c9c3b4"; g.fillRect(0, 0, 256, 256);
    g.strokeStyle = "#ada694"; g.lineWidth = 4;
    for (let x = 0; x <= 256; x += 64) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, 256); g.stroke(); g.beginPath(); g.moveTo(0, x); g.lineTo(256, x); g.stroke(); }
  });
  stone.wrapS = stone.wrapT = THREE.RepeatWrapping; stone.repeat.set(16, 16);
  const plaza = new THREE.Mesh(new THREE.CircleGeometry(72, 64), mat(0xffffff, { map: stone }));
  plaza.rotation.x = -Math.PI / 2; plaza.position.y = 0.02; plaza.receiveShadow = true; sc.add(plaza);
  const pathMat = mat(0xd8cfb8);
  [[115, 0, 100, 16], [-115, 0, 100, 16], [0, -115, 16, 100], [0, 110, 16, 90]].forEach((p) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(p[2], p[3]), pathMat);
    m.rotation.x = -Math.PI / 2; m.position.set(p[0], 0.015, p[1]); m.receiveShadow = true; sc.add(m);
  });

  // fonte central
  const basin = new THREE.Mesh(new THREE.CylinderGeometry(9, 10, 1.6, 40), mat(0xb9b2a2)); basin.position.y = 0.8; basin.castShadow = basin.receiveShadow = true; sc.add(basin);
  const water = new THREE.Mesh(new THREE.CylinderGeometry(8.2, 8.2, 0.3, 40), mat(0x4fb7ff, { roughness: 0.15, metalness: 0.2, transparent: true, opacity: 0.85 })); water.position.y = 1.5; sc.add(water);
  const col = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.6, 6, 16), mat(0xb9b2a2)); col.position.y = 3.5; col.castShadow = true; sc.add(col);
  const top = new THREE.Mesh(new THREE.OctahedronGeometry(2.2), mat(0xffcc3d, { metalness: 0.6, roughness: 0.25, emissive: 0x553300, emissiveIntensity: 0.4 }));
  top.position.y = 9; top.castShadow = true; sc.add(top); W.spinners.push({ o: top, s: 0.8 });
  W.colliders.push({ x: 0, z: 0, r: 10.5 });
  const title = makeSprite(signTexture([{ t: "CASE STRIKE", size: 74, color: "#ffcc3d" }, { t: "Skin Empire", size: 40, color: "#bfe6ff" }], "#24336e"), 22, 11);
  title.position.set(0, 16, 0); sc.add(title); W.floaters.push({ o: title, y: 16, a: 0.6 });

  buildCases();
  buildBuildings();
  buildZones();
  buildDecor();
  buildPlayer();

  window.addEventListener("resize", () => {
    const w = host.clientWidth, h = host.clientHeight;
    W.renderer.setSize(w, h); W.camera.aspect = w / h; W.camera.updateProjectionMatrix();
  });
}

// caixas em anel ao redor da fonte (como a vitrine de caixas do vídeo)
function caseTexture(c) {
  return canvasTex(256, 256, (g) => {
    g.fillStyle = rgb(c.color); g.fillRect(0, 0, 256, 256);
    g.fillStyle = "rgba(255,255,255,.12)"; g.fillRect(0, 0, 256, 90);
    g.strokeStyle = rgb(c.trim); g.lineWidth = 26; g.strokeRect(13, 13, 230, 230);
    g.fillStyle = rgb(c.trim); g.fillRect(100, 0, 56, 256);
    g.fillStyle = "#0b1230"; roundRect(g, 92, 104, 72, 52, 10); g.fill();
    g.fillStyle = rgb(c.trim); roundRect(g, 104, 114, 48, 32, 6); g.fill();
  });
}
function caseLabelTex(c) {
  const locked = S.level < c.requiredLevel;
  const left = c.stockPerDay ? stockLeft(c, now()) : null;
  const lines = [{ t: c.name.replace("Caixa ", ""), size: 54, color: "#fff" }];
  lines.push({ t: locked ? "🔒 Nível " + c.requiredLevel : "₵ " + fmt(c.price), size: 44, color: locked ? "#ff9aa0" : "#ffcc3d" });
  if (left !== null) lines.push({ t: left > 0 ? `Estoque: ${left}/${c.stockPerDay}` : "Esgotada hoje", size: 32, color: "#9ff0c4" });
  else if (S.freeCases[c.id]) lines.push({ t: `${S.freeCases[c.id]} grátis`, size: 32, color: "#9ff0c4" });
  return signTexture(lines, rgb(c.color.map((x) => Math.floor(x * 0.55))), "#0b1230", 512, 256);
}
function buildCases() {
  const list = DATA.cases.slice().sort((a, b) => a.order - b.order);
  const R = 30;
  list.forEach((c, i) => {
    const a = (i / list.length) * Math.PI * 2 + Math.PI / list.length;
    const x = Math.sin(a) * R, z = Math.cos(a) * R;
    const g = new THREE.Group(); g.position.set(x, 0, z); W.scene.add(g);
    const ped = new THREE.Mesh(new THREE.CylinderGeometry(2.4, 2.8, 1.6, 20), mat(0x2b3566)); ped.position.y = 0.8; ped.castShadow = ped.receiveShadow = true; g.add(ped);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(2.5, 0.16, 8, 32), mat(col3(c.trim), { emissive: col3(c.color), emissiveIntensity: 0.6 })); ring.rotation.x = Math.PI / 2; ring.position.y = 1.65; g.add(ring);
    const cube = new THREE.Mesh(new THREE.BoxGeometry(2.6, 2.6, 2.6), mat(0xffffff, { map: caseTexture(c), roughness: 0.4, metalness: 0.2 }));
    cube.position.y = 3.6; cube.castShadow = true; g.add(cube);
    W.spinners.push({ o: cube, s: 0.6 + (i % 3) * 0.1 }); W.floaters.push({ o: cube, y: 3.6, a: 0.25, ph: i });
    const lab = makeSprite(caseLabelTex(c), 7, 3.5); lab.position.y = 7.4; g.add(lab);
    W.casePedestals.push({ c, label: lab, key: "" });
    W.colliders.push({ x, z, r: 2.9 });
    W.interactables.push({ x, z, r: 7.5, label: () => (S.level < c.requiredLevel ? `${c.name} (nível ${c.requiredLevel})` : `Abrir ${c.name}`), act: () => UI.openCase(c.id) });
  });
}
function refreshCaseLabels() {
  W.casePedestals.forEach((p) => {
    const c = p.c;
    const key = [S.level >= c.requiredLevel, c.stockPerDay ? stockLeft(c, now()) : "", S.freeCases[c.id] || 0].join("|");
    if (key === p.key) return;
    p.key = key;
    if (p.label.material.map) p.label.material.map.dispose();
    p.label.material.map = caseLabelTex(c); p.label.material.needsUpdate = true;
  });
}

// prédios: ao chegar perto do tapete da porta, aparece o botão para abrir o painel
const BUILDINGS = [
  { id: "bank", name: "BANCO", sub: "Renda passiva", x: 82, z: -82, w: 26, d: 20, h: 14, color: 0x2f7d4f, roof: 0xffcc3d, panel: "bank" },
  { id: "workshop", name: "OFICINA", sub: "Melhorias", x: -82, z: -82, w: 24, d: 20, h: 12, color: 0x8a5a2b, roof: 0x3b4fa0, panel: "workshop" },
  { id: "index", name: "COLEÇÃO", sub: "Índice de skins", x: -108, z: 42, w: 24, d: 18, h: 12, color: 0x6b3fa0, roof: 0xff8ad8, panel: "index" },
  { id: "missions", name: "MISSÕES", sub: "Diárias e semanais", x: 108, z: 42, w: 22, d: 18, h: 12, color: 0x2a5fb0, roof: 0x59c8ff, panel: "missions" },
  { id: "gifts", name: "PRESENTES", sub: "Diário e nível", x: -52, z: 108, w: 20, d: 16, h: 11, color: 0xc0392b, roof: 0xffffff, panel: "gifts" },
  { id: "attrs", name: "ATRIBUTOS", sub: "Sorte, XP, velocidade", x: 52, z: 108, w: 20, d: 16, h: 11, color: 0x1f8a8a, roof: 0xb6ffe8, panel: "attributes" },
  { id: "potions", name: "POÇÕES", sub: "Sorte, XP, renda", x: 0, z: 150, w: 16, d: 14, h: 10, color: 0x7b2fbf, roof: 0x9cff6a, panel: "potions" },
  { id: "showroom", name: "VITRINE", sub: "Suas melhores skins", x: 140, z: -42, w: 24, d: 18, h: 11, color: 0x34405e, roof: 0xffcc3d, panel: "showroom" },
  { id: "rank", name: "RANKING", sub: "Patrimônio e renda", x: -140, z: -42, w: 20, d: 16, h: 11, color: 0x4a4a5a, roof: 0xffcc3d, panel: "ranking" },
  { id: "rebirth", name: "RENASCER", sub: "Bônus permanentes", x: -42, z: -150, w: 20, d: 16, h: 12, color: 0x2b2b4f, roof: 0xff5a64, panel: "rebirth" },
  { id: "battle", name: "BATALHAS", sub: "EM BREVE", x: 42, z: -150, w: 20, d: 16, h: 12, color: 0x444444, roof: 0x777777, panel: "soon" },
];
function buildBuildings() {
  BUILDINGS.forEach((b) => {
    const g = new THREE.Group(); g.position.set(b.x, 0, b.z);
    const face = Math.atan2(-b.x, -b.z); // porta virada para o centro
    g.rotation.y = face; W.scene.add(g);
    box(b.w, b.h, b.d, mat(b.color), 0, b.h / 2, 0, g);
    box(b.w + 2, 1.2, b.d + 2, mat(b.roof), 0, b.h + 0.6, 0, g);
    const roof = new THREE.Mesh(new THREE.ConeGeometry(Math.max(b.w, b.d) * 0.62, 6, 4), mat(b.roof)); roof.rotation.y = Math.PI / 4; roof.position.y = b.h + 4; roof.scale.z = b.d / b.w; roof.castShadow = true; g.add(roof);
    box(6, 8, 0.6, mat(0x1b2240), 0, 4, b.d / 2 + 0.1, g);
    box(7, 0.8, 1, mat(b.roof), 0, 8.4, b.d / 2 + 0.3, g);
    for (let i = -1; i <= 1; i += 2) box(3, 3, 0.4, mat(0xbfe6ff, { emissive: 0x3a7fbf, emissiveIntensity: 0.25 }), i * (b.w / 2 - 4), b.h * 0.55, b.d / 2 + 0.05, g);
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(14, 5), new THREE.MeshBasicMaterial({ map: signTexture([{ t: b.name, size: 86, color: "#fff" }, { t: b.sub, size: 40, color: b.panel === "soon" ? "#ffcc3d" : "#bfe6ff" }], "#24336e"), transparent: true }));
    sign.position.set(0, b.h - 2.2, b.d / 2 + 0.4); g.add(sign);
    const pad = new THREE.Mesh(new THREE.CylinderGeometry(3, 3, 0.25, 28), mat(0x4ee39a, { emissive: 0x1f9c5a, emissiveIntensity: 0.7, transparent: true, opacity: 0.85 }));
    pad.position.set(0, 0.13, b.d / 2 + 4.5); g.add(pad); W.floaters.push({ o: pad, y: 0.13, a: 0.06 });
    const padW = new THREE.Vector3(); pad.getWorldPosition(padW);
    // colisão (caixa alinhada ao prédio girado → usa círculos ao longo do comprimento)
    const n = Math.ceil(b.w / Math.min(b.w, b.d));
    for (let i = 0; i < n; i++) {
      const lx = -b.w / 2 + (b.w / n) * (i + 0.5);
      const v = new THREE.Vector3(lx, 0, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), face);
      W.colliders.push({ x: b.x + v.x, z: b.z + v.z, r: Math.max(b.w / n, b.d) / 2 * 1.08 });
    }
    W.interactables.push({ x: padW.x, z: padW.z, r: 5, label: () => (b.panel === "soon" ? "Batalhas — EM BREVE" : "Entrar: " + b.name.charAt(0) + b.name.slice(1).toLowerCase()), act: () => UI.open(b.panel) });
    if (b.id === "showroom") buildShowroomSlots(g, b);
  });
}
function buildShowroomSlots(g, b) {
  for (let i = 0; i < ECO.ShowcaseSlots; i++) {
    const s = new THREE.Group();
    const lx = -12 + i * 4.8;
    s.position.set(lx, 0, b.d / 2 + 10); g.add(s);
    const ped = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.4, 2.2, 16), mat(0x24336e)); ped.position.y = 1.1; ped.castShadow = true; s.add(ped);
    const glass = new THREE.Mesh(new THREE.BoxGeometry(2.4, 2.4, 2.4), new THREE.MeshStandardMaterial({ color: 0xbfe6ff, transparent: true, opacity: 0.18, roughness: 0.05 })); glass.position.y = 3.5; s.add(glass);
    const wp = new THREE.Vector3(); s.getWorldPosition(wp);
    W.colliders.push({ x: wp.x, z: wp.z, r: 1.6 });
    W.showroomSlots.push({ g: s, key: "", mesh: null });
  }
}
function refreshShowroom() {
  const uids = Object.keys(S.showcase).filter((u) => S.inv[u]);
  W.showroomSlots.forEach((slot, i) => {
    const it = S.inv[uids[i]];
    const key = it ? it.uid + JSON.stringify(it.up) : "";
    if (key === slot.key) return;
    slot.key = key;
    if (slot.mesh) { slot.g.remove(slot.mesh); slot.mesh = null; }
    if (it) {
      const m = buildWeapon(SKIN[it.defId], it.up); m.scale.setScalar(0.45); m.position.y = 3.5;
      slot.g.add(m); slot.mesh = m; W.spinners.push({ o: m, s: 0.7, slot: true });
    }
  });
}

// zonas: chão temático, decoração, barreiras e placa no portão
function buildZones() {
  DATA.zones.forEach((z) => {
    if (!z.area) return;
    const [cx, cz] = z.area.center, [sx, sz] = z.area.size;
    const tint = z.id === "zone2" ? "#f3d36b" : z.id === "zone3" ? "#4b3a6b" : "#bfeaff";
    const tex = canvasTex(128, 128, (g) => {
      g.fillStyle = tint; g.fillRect(0, 0, 128, 128);
      g.fillStyle = "rgba(0,0,0,.06)"; for (let x = 0; x < 128; x += 32) for (let y = 0; y < 128; y += 32) if ((x + y) % 64 === 0) g.fillRect(x, y, 32, 32);
    });
    tex.wrapS = tex.wrapT = THREE.RepeatWrapping; tex.repeat.set(sx / 12, sz / 12);
    const fl = new THREE.Mesh(new THREE.PlaneGeometry(sx, sz), mat(0xffffff, { map: tex }));
    fl.rotation.x = -Math.PI / 2; fl.position.set(cx, 0.03, cz); fl.receiveShadow = true; W.scene.add(fl);
    // decoração temática
    const rnd = mulberry(z.order * 97);
    for (let i = 0; i < 26; i++) {
      const x = cx + (rnd() - 0.5) * (sx - 14), zz = cz + (rnd() - 0.5) * (sz - 14);
      if (Math.abs(x - cx) < 10 && Math.abs(zz - cz) < 10) continue;
      let m;
      if (z.id === "zone2") {
        m = new THREE.Group();
        box(0.3, 2, 0.3, mat(0x3f8f3a), 0, 1, 0, m);
        const fcol = [0xff6fa8, 0xffd84a, 0xff8a3d, 0xffffff][i % 4];
        const fh = new THREE.Mesh(new THREE.SphereGeometry(0.9, 10, 8), mat(fcol)); fh.position.y = 2.3; fh.castShadow = true; m.add(fh);
        m.scale.setScalar(1 + rnd());
      } else if (z.id === "zone3") {
        m = new THREE.Group();
        if (i % 3 === 0) { const p = new THREE.Mesh(new THREE.SphereGeometry(1.3, 12, 10), mat(0xff8a1f, { emissive: 0x7a2a00, emissiveIntensity: 0.5 })); p.scale.y = 0.8; p.position.y = 1; p.castShadow = true; m.add(p); box(0.3, 0.6, 0.3, mat(0x3f6b2a), 0, 2.1, 0, m); }
        else { box(0.8, 7, 0.8, mat(0x3b2a2a), 0, 3.5, 0, m); const br = box(4, 0.5, 0.5, mat(0x3b2a2a), 1, 5.5, 0, m); br.rotation.z = 0.5; }
      } else {
        const cr = new THREE.Mesh(new THREE.OctahedronGeometry(1.6 + rnd() * 1.5), mat(0x7fe3ff, { emissive: 0x1a7fa8, emissiveIntensity: 0.6, roughness: 0.15, metalness: 0.3, transparent: true, opacity: 0.9 }));
        cr.scale.y = 2; cr.position.y = 3; cr.castShadow = true; m = cr; W.spinners.push({ o: cr, s: 0.3 });
      }
      m.position.x = x; m.position.z = zz; W.scene.add(m);
    }
    // barreira (some quando a zona é desbloqueada)
    const bm = new THREE.MeshBasicMaterial({ color: col3(z.color), transparent: true, opacity: 0.32, side: THREE.DoubleSide, depthWrite: false });
    const bar = new THREE.Group();
    [[cx, cz - sz / 2, sx, 0], [cx, cz + sz / 2, sx, 0], [cx - sx / 2, cz, sz, 1], [cx + sx / 2, cz, sz, 1]].forEach((w) => {
      const p = new THREE.Mesh(new THREE.PlaneGeometry(w[2], 14), bm); p.position.set(w[0], 7, w[1]); if (w[3]) p.rotation.y = Math.PI / 2; bar.add(p);
    });
    W.scene.add(bar);
    W.zoneBarriers[z.id] = { group: bar, mat: bm, rect: [cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2] };
    // placa no lado voltado para a praça
    const dir = new THREE.Vector2(-cx, -cz).normalize();
    const gx = cx + dir.x * (Math.abs(dir.x) > 0.5 ? sx / 2 : 0) + dir.x * 5;
    const gz = cz + dir.y * (Math.abs(dir.y) > 0.5 ? sz / 2 : 0) + dir.y * 5;
    const post = new THREE.Group(); post.position.set(gx, 0, gz); post.rotation.y = Math.atan2(dir.x, dir.y); W.scene.add(post);
    box(0.6, 12, 0.6, mat(0x5a3a1f), -7, 6, 0, post); box(0.6, 12, 0.6, mat(0x5a3a1f), 7, 6, 0, post);
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(15, 7.5), new THREE.MeshBasicMaterial({ transparent: true }));
    sign.position.set(0, 13, 0); post.add(sign);
    const back = sign.clone(); back.rotation.y = Math.PI; back.position.z = -0.05; post.add(back);
    W.zoneSigns[z.id] = { front: sign, back, key: "" };
    W.interactables.push({ x: gx, z: gz, r: 7, label: () => (S.zones[z.id] ? z.name : `Desbloquear ${z.name.split(" — ")[0]} (₵ ${fmt(z.cost)})`), act: () => UI.open("zones") });
  });
}
function refreshZones() {
  DATA.zones.forEach((z) => {
    if (!z.area) return;
    const owned = !!S.zones[z.id];
    W.zoneBarriers[z.id].group.visible = !owned;
    const s = W.zoneSigns[z.id];
    const key = owned + "|" + (S.level >= z.requiredLevel);
    if (s.key === key) return;
    s.key = key;
    const [num, nm] = z.name.split(" — ");
    const lines = [{ t: num.toUpperCase(), size: 70, color: "#fff" }, { t: nm, size: 40, color: "#e8eeff" }, { t: `+ ${Math.round(z.luck * 100)}% SORTE`, size: 56, color: "#7dff9e" }];
    lines.push(owned ? { t: "✔ Desbloqueada", size: 36, color: "#bfffd2" } : { t: `₵ ${fmt(z.cost)} • Nível ${z.requiredLevel}`, size: 36, color: "#ffcc3d" });
    const tex = signTexture(lines, rgb(z.color.map((x) => Math.floor(x * 0.45))), "#0b1230", 512, 256);
    s.front.material.map = tex; s.front.material.needsUpdate = true;
    s.back.material = s.front.material;
  });
}
function zoneAt(x, z) {
  for (const zn of DATA.zones) {
    if (!zn.area) continue;
    const [cx, cz] = zn.area.center, [sx, sz] = zn.area.size;
    if (Math.abs(x - cx) <= sx / 2 && Math.abs(z - cz) <= sz / 2) return zn.id;
  }
  return "zone1";
}
function mulberry(a) { return function () { a |= 0; a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

function buildDecor() {
  const rnd = mulberry(7);
  const trunk = mat(0x7a4a24), leaf = mat(0x3f9a3a), leaf2 = mat(0x2f8a4a);
  let placed = 0;
  for (let i = 0; i < 400 && placed < 70; i++) {
    const x = (rnd() - 0.5) * 600, z = (rnd() - 0.5) * 600;
    if (Math.hypot(x, z) < 80) continue;
    if (zoneAt(x, z) !== "zone1") continue;
    if (Math.abs(x) < 14 || Math.abs(z) < 14) continue;
    if (BUILDINGS.some((b) => Math.hypot(b.x - x, b.z - z) < 26)) continue;
    let near = false;
    for (const zn of DATA.zones) if (zn.area && Math.abs(x - zn.area.center[0]) < zn.area.size[0] / 2 + 12 && Math.abs(z - zn.area.center[1]) < zn.area.size[1] / 2 + 12) near = true;
    if (near) continue;
    const t = new THREE.Group(); t.position.set(x, 0, z);
    box(1.2, 5, 1.2, trunk, 0, 2.5, 0, t);
    const c1 = new THREE.Mesh(new THREE.ConeGeometry(4, 7, 8), placed % 2 ? leaf : leaf2); c1.position.y = 7; c1.castShadow = true; t.add(c1);
    const c2 = new THREE.Mesh(new THREE.ConeGeometry(3, 5, 8), placed % 2 ? leaf : leaf2); c2.position.y = 10; c2.castShadow = true; t.add(c2);
    t.scale.setScalar(0.8 + rnd() * 0.6);
    W.scene.add(t); W.colliders.push({ x, z, r: 1.6 }); placed++;
  }
  // postes de luz na praça
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2 + Math.PI / 8, x = Math.sin(a) * 60, z = Math.cos(a) * 60;
    const p = new THREE.Group(); p.position.set(x, 0, z);
    box(0.5, 8, 0.5, mat(0x2b2f3a), 0, 4, 0, p);
    const l = new THREE.Mesh(new THREE.SphereGeometry(0.9, 12, 10), mat(0xfff2c0, { emissive: 0xffd27a, emissiveIntensity: 0.9 })); l.position.y = 8.4; p.add(l);
    W.scene.add(p); W.colliders.push({ x, z, r: 0.8 });
  }
  // cerca
  const fm = mat(0xf0e6d0);
  [[0, -312, 624, 1], [0, 312, 624, 1], [-312, 0, 1, 624], [312, 0, 1, 624]].forEach((f) => box(f[2], 3, f[3], fm, f[0], 1.5, f[1], W.scene));
}

// ---------------------------------------------------------------- personagem
function faceTex() {
  return canvasTex(64, 64, (g) => {
    g.fillStyle = "#ffd59e"; g.fillRect(0, 0, 64, 64);
    g.fillStyle = "#1b1b1b"; g.fillRect(18, 22, 7, 10); g.fillRect(39, 22, 7, 10);
    g.lineWidth = 4; g.strokeStyle = "#1b1b1b"; g.beginPath(); g.arc(32, 36, 12, 0.2 * Math.PI, 0.8 * Math.PI); g.stroke();
  });
}
function buildPlayer() {
  const p = new THREE.Group();
  const skin = mat(0xffd59e), shirt = mat(0x3a6ff0), pants = mat(0x2b2f4a);
  const torso = box(2, 2, 1, shirt, 0, 3, 0, p);
  const headMats = [skin, skin, skin, skin, mat(0xffffff, { map: faceTex() }), skin];
  const head = new THREE.Mesh(new THREE.BoxGeometry(1.25, 1.25, 1.25), headMats); head.position.y = 4.65; head.castShadow = true; p.add(head);
  const mkLimb = (m, x, y) => { const piv = new THREE.Group(); piv.position.set(x, y, 0); const l = box(0.95, 2, 0.95, m, 0, -1, 0, piv); p.add(piv); return piv; };
  W.armL = mkLimb(skin, -1.48, 4); W.armR = mkLimb(skin, 1.48, 4);
  W.legL = mkLimb(pants, -0.5, 2); W.legR = mkLimb(pants, 0.5, 2);
  box(2.02, 0.5, 1.02, mat(0x1b1f33), 0, 2.2, 0, p);
  W.scene.add(p);
  W.player = p;
  const tag = makeSprite(signTexture([{ t: "Você", size: 60 }], "#24336e"), 4.2, 2.1);
  tag.position.y = 6.6; p.add(tag); W.nameTag = tag; W.nameKey = "";
  // sombra do personagem
  const blob = new THREE.Mesh(new THREE.CircleGeometry(1.4, 20), new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.25, depthWrite: false }));
  blob.rotation.x = -Math.PI / 2; blob.position.y = 0.05; W.scene.add(blob); W.blob = blob;
}
function refreshPlayerLook() {
  const eq = Object.values(S.inv).find((i) => i.eq && i.loc !== "bank");
  const key = eq ? eq.uid + JSON.stringify(eq.up) : "";
  if (key !== W.heldKey) {
    W.heldKey = key;
    if (W.held) { W.armR.remove(W.held); W.held = null; }
    if (eq) {
      const m = buildWeapon(SKIN[eq.defId], eq.up);
      m.scale.setScalar(0.62); m.rotation.set(0, -Math.PI / 2, -Math.PI / 2); m.position.set(0, -2.0, 0.6);
      W.armR.add(m); W.held = m;
    }
  }
  const title = PROG.titles[S.title] ? PROG.titles[S.title].displayName : "";
  const nk = S.level + "|" + title;
  if (nk !== W.nameKey) {
    W.nameKey = nk;
    W.nameTag.material.map = signTexture([{ t: "Você • Nv " + S.level, size: 56 }, { t: title, size: 40, color: "#ffcc3d" }], "#24336e");
    W.nameTag.material.needsUpdate = true;
  }
}

// ---------------------------------------------------------------- controles
function setupControls() {
  const el = W.renderer.domElement;
  window.addEventListener("keydown", (e) => {
    if (e.target && (e.target.tagName === "INPUT")) return;
    if (UI.isOpen()) { if (e.key === "Escape") UI.close(); return; }
    W.keys[e.code] = true;
    if (e.code === "KeyE" && W.near) { W.near.act(); e.preventDefault(); }
    if (e.code === "Space") e.preventDefault();
  });
  window.addEventListener("keyup", (e) => { W.keys[e.code] = false; });
  window.addEventListener("blur", () => { W.keys = {}; });
  let drag = null;
  el.addEventListener("pointerdown", (e) => { drag = { id: e.pointerId, x: e.clientX, y: e.clientY }; el.setPointerCapture(e.pointerId); });
  el.addEventListener("pointermove", (e) => {
    if (!drag || drag.id !== e.pointerId) return;
    W.camYaw -= (e.clientX - drag.x) * 0.006;
    W.camPitch = Math.max(0.05, Math.min(1.25, W.camPitch + (e.clientY - drag.y) * 0.005));
    drag.x = e.clientX; drag.y = e.clientY;
  });
  const end = (e) => { if (drag && drag.id === e.pointerId) drag = null; };
  el.addEventListener("pointerup", end); el.addEventListener("pointercancel", end);
  el.addEventListener("wheel", (e) => { W.camDist = Math.max(8, Math.min(60, W.camDist + e.deltaY * 0.03)); e.preventDefault(); }, { passive: false });

  // joystick de toque
  const joy = document.getElementById("joy"), knob = joy.querySelector(".knob");
  let jid = null;
  const jmove = (e) => {
    const r = joy.getBoundingClientRect();
    let dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
    const m = Math.hypot(dx, dy), max = r.width / 2 - 10;
    if (m > max) { dx = (dx / m) * max; dy = (dy / m) * max; }
    knob.style.transform = `translate(${dx}px, ${dy}px)`;
    W.joy.x = dx / max; W.joy.y = dy / max;
  };
  joy.addEventListener("pointerdown", (e) => { jid = e.pointerId; joy.setPointerCapture(jid); W.joy.active = true; jmove(e); });
  joy.addEventListener("pointermove", (e) => { if (e.pointerId === jid) jmove(e); });
  const jend = (e) => { if (e.pointerId !== jid) return; jid = null; W.joy = { x: 0, y: 0, active: false }; knob.style.transform = ""; };
  joy.addEventListener("pointerup", jend); joy.addEventListener("pointercancel", jend);
  document.getElementById("jump").addEventListener("pointerdown", (e) => { W.keys.Space = true; setTimeout(() => (W.keys.Space = false), 120); e.preventDefault(); });
  window.addEventListener("touchstart", () => document.body.classList.add("touch"), { once: true, passive: true });
  if (matchMedia("(pointer: coarse)").matches) document.body.classList.add("touch");
}

// ---------------------------------------------------------------- simulação por quadro
function stepPlayer(dt) {
  let ix = 0, iz = 0;
  if (!UI.isOpen()) {
    const k = W.keys;
    if (k.KeyW || k.ArrowUp) iz -= 1;
    if (k.KeyS || k.ArrowDown) iz += 1;
    if (k.KeyA || k.ArrowLeft) ix -= 1;
    if (k.KeyD || k.ArrowRight) ix += 1;
    if (W.joy.active) { ix += W.joy.x; iz += W.joy.y; }
  }
  const mag = Math.min(1, Math.hypot(ix, iz));
  const run = W.keys.ShiftLeft || W.keys.ShiftRight ? 1.45 : 1;
  const speed = 24 * run;
  let mx = 0, mz = 0;
  if (mag > 0.05) {
    // direção relativa à câmera
    const a = Math.atan2(ix, iz) + W.camYaw;
    mx = Math.sin(a) * mag * speed; mz = Math.cos(a) * mag * speed;
    const target = Math.atan2(mx, mz);
    let d = target - W.yaw; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2;
    W.yaw += d * Math.min(1, dt * 12);
    W.walkT += dt * 9 * mag * run;
  } else W.walkT *= 0.85;
  if (W.keys.Space && W.onGround && !UI.isOpen()) { W.vel.y = 26; W.onGround = false; }
  W.vel.y -= 70 * dt;
  const p = W.pos;
  p.x += mx * dt; p.z += mz * dt; p.y += W.vel.y * dt;
  if (p.y <= 0) { p.y = 0; W.vel.y = 0; W.onGround = true; }
  // colisões circulares
  const R = 1.3;
  for (const c of W.colliders) {
    const dx = p.x - c.x, dz = p.z - c.z, d = Math.hypot(dx, dz), m = c.r + R;
    if (d < m && d > 0.0001) { p.x = c.x + (dx / d) * m; p.z = c.z + (dz / d) * m; }
  }
  // barreiras das zonas bloqueadas
  for (const id in W.zoneBarriers) {
    if (S.zones[id]) continue;
    const [x1, z1, x2, z2] = W.zoneBarriers[id].rect;
    if (p.x > x1 - R && p.x < x2 + R && p.z > z1 - R && p.z < z2 + R) {
      const pen = [p.x - (x1 - R), x2 + R - p.x, p.z - (z1 - R), z2 + R - p.z];
      const i = pen.indexOf(Math.min.apply(null, pen));
      if (i === 0) p.x = x1 - R; else if (i === 1) p.x = x2 + R; else if (i === 2) p.z = z1 - R; else p.z = z2 + R;
      if (!W.lastBlockToast || performance.now() - W.lastBlockToast > 2500) { W.lastBlockToast = performance.now(); toast(`${ZONE[id].name.split(" — ")[0]} bloqueada. Desbloqueie na placa ou no painel Zonas.`, "bad"); }
    }
  }
  p.x = Math.max(-308, Math.min(308, p.x)); p.z = Math.max(-308, Math.min(308, p.z));
  const pl = W.player;
  pl.position.copy(p); pl.rotation.y = W.yaw;
  const sw = Math.sin(W.walkT) * 0.7 * Math.min(1, mag + 0.001);
  W.legL.rotation.x = sw; W.legR.rotation.x = -sw;
  W.armL.rotation.x = -sw; W.armR.rotation.x = W.held ? -0.9 : sw;
  if (!W.onGround) { W.legL.rotation.x = 0.4; W.legR.rotation.x = -0.2; }
  W.blob.position.set(p.x, 0.05, p.z);
  // câmera
  const cam = W.camera, d = W.camDist;
  const tx = p.x, ty = p.y + 4.5, tz = p.z;
  cam.position.set(tx + Math.sin(W.camYaw) * Math.cos(W.camPitch) * d, ty + Math.sin(W.camPitch) * d, tz + Math.cos(W.camYaw) * Math.cos(W.camPitch) * d);
  cam.lookAt(tx, ty, tz);
  W.sun.position.set(p.x + 60, 120, p.z + 40); W.sun.target.position.set(p.x, 0, p.z);
  // zona atual
  const z = zoneAt(p.x, p.z);
  if (z !== W.zoneId) { W.zoneId = z; UI.zoneChanged(z); }
  // interação mais próxima
  let best = null, bd = 1e9;
  for (const it of W.interactables) {
    const dd = Math.hypot(p.x - it.x, p.z - it.z);
    if (dd < it.r && dd < bd) { bd = dd; best = it; }
  }
  W.near = UI.isOpen() ? null : best;
}
function animateWorld(dt, t) {
  W.spinners.forEach((s) => (s.o.rotation.y += s.s * dt));
  W.floaters.forEach((f) => (f.o.position.y = f.y + Math.sin(t * 2 + (f.ph || 0)) * f.a));
  for (const id in W.zoneBarriers) W.zoneBarriers[id].mat.opacity = 0.22 + Math.sin(t * 2.4) * 0.08;
  W.scene.traverse((o) => { if (o.userData && o.userData.sparkle) o.rotation.y += dt * 1.5; if (o.userData && o.userData.holo) o.userData.holo.emissive.setHSL((t * 0.15) % 1, 0.8, 0.5); });
}
