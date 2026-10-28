// ============================================================================
// Inicialização e laço principal
// ============================================================================
function start() {
  S = loadProfile();
  refreshPeriods(now());
  settle(now()); // produção offline desde a última visita (limitada como no jogo)
  buildWorld();
  buildSide();
  setupControls();
  W.dirty = true;
  if (window.claude && window.claude.hot && window.claude.hot.snapshot) {
    try { window.claude.hot.snapshot(() => ({ S })); } catch (e) {}
  }
  let acc = 0, saveAcc = 0, lastT = 0;
  const loop = () => {
    const dt = Math.min(0.05, W.clock.getDelta());
    const t = W.clock.elapsedTime;
    stepPlayer(dt);
    animateWorld(dt, t);
    acc += dt; saveAcc += dt;
    if (acc >= 0.25) {
      acc = 0;
      if (t - lastT >= 1) { lastT = t; settle(now()); }
      if (W.dirty) {
        W.dirty = false;
        refreshCaseLabels(); refreshZones(); refreshShowroom(); refreshPlayerLook();
      }
      UI.hud();
    }
    if (saveAcc >= 4 || saveTimer) { if (saveAcc >= 1) { saveAcc = 0; saveTimer = 0; save(); } }
    W.renderer.render(W.scene, W.camera);
    requestAnimationFrame(loop);
  };
  loop();
  toast("Bem-vindo! Ande até uma caixa ou prédio e aperte E (ou o botão verde).", "good");
  window.addEventListener("beforeunload", save);
  document.addEventListener("visibilitychange", () => { if (document.hidden) save(); });
}
if (typeof THREE === "undefined") {
  document.getElementById("game").innerHTML = '<div style="padding:40px;text-align:center;font-family:sans-serif">Não foi possível carregar o motor 3D. Verifique a conexão e recarregue a página.</div>';
} else {
  // espera a fonte das placas (até 1,5 s) para os letreiros 3D saírem com a letra certa
  const boot = () => {
    let done = false;
    const go = () => { if (!done) { done = true; start(); } };
    setTimeout(go, 1500);
    if (document.fonts && document.fonts.load) document.fonts.load('40px "Lilita One"').then(go, go); else go();
  };
  if (window.claude && window.claude.hot && window.claude.hot.ready) window.claude.hot.ready(boot); else boot();
}
