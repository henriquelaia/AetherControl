(() => {
  const cpuHistory = [];
  const gpuHistory = [];
  let cpuHoverIdx = -1;
  let gpuHoverIdx = -1;
  let curveHoverTempC = null;

  let currentLang = localStorage.getItem('aether_lang') || 'pt-PT';
  let currentTheme = localStorage.getItem('aether_theme') || 'dark';
  let currentConfig = null;
  let draggingNodeIdx = -1;
  let hoveredNodeIdx = -1;
  let latestTelemetry = null;
  let pollingTimer = null;

  // Theme toggle
  function applyTheme(theme) {
    currentTheme = theme;
    localStorage.setItem('aether_theme', theme);
    document.documentElement.setAttribute('data-theme', theme);
    if (latestTelemetry) updateDashboard(latestTelemetry);
    else renderFanCurve();
  }

  document.getElementById('btn-theme-toggle').addEventListener('click', () => {
    applyTheme(currentTheme === 'dark' ? 'light' : 'dark');
  });

  // Card hover coordinates & segmented tabs
  document.addEventListener('pointermove', (e) => {
    document.querySelectorAll('.bento-card').forEach((card) => {
      const rect = card.getBoundingClientRect();
      card.style.setProperty('--mouse-x', `${e.clientX - rect.left}px`);
      card.style.setProperty('--mouse-y', `${e.clientY - rect.top}px`);
    });
  });

  function syncSegmentedThumb(barEl) {
    if (!barEl) return;
    const thumb = barEl.querySelector('.seg-thumb');
    const activeBtn = barEl.querySelector('.seg-pill-btn.active');
    if (!thumb || !activeBtn) return;
    const pad = barEl.classList.contains('compact-seg') ? 2 : 3;
    thumb.style.width = `${activeBtn.offsetWidth}px`;
    thumb.style.transform = `translateX(${activeBtn.offsetLeft - pad}px)`;
  }

  function syncAllSegmentedThumbs() {
    document.querySelectorAll('.segmented-bar').forEach(syncSegmentedThumb);
  }

  window.addEventListener('resize', () => {
    syncAllSegmentedThumbs();
    renderFanCurve();
  });
  setTimeout(syncAllSegmentedThumbs, 50);

  document.querySelectorAll('#right-panel-tabs .seg-pill-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#right-panel-tabs .seg-pill-btn').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      syncSegmentedThumb(document.getElementById('right-panel-tabs'));

      const targetTab = btn.getAttribute('data-tab');
      document.querySelectorAll('.tab-pane').forEach((pane) => {
        pane.style.display = pane.id === targetTab ? 'flex' : 'none';
      });
    });
  });

  const advBtn = document.getElementById('btn-toggle-advanced');
  const advDrawer = document.getElementById('advanced-curve-drawer');
  if (advBtn && advDrawer) {
    advBtn.addEventListener('click', () => {
      const isHidden = advDrawer.style.display === 'none';
      advDrawer.style.display = isHidden ? 'flex' : 'none';
      advBtn.classList.toggle('active', isHidden);
    });
  }

  function setupSliderDetents(sliderId, snapTolerance = 0.5) {
    const slider = document.getElementById(sliderId);
    if (!slider) return;
    const wrap = slider.closest('.detent-slider-wrap');
    if (!wrap) return;
    const ticks = Array.from(wrap.querySelectorAll('.detent-ticks span'));
    const detentValues = ticks.map(t => parseFloat(t.getAttribute('data-val')));

    function updateTicks(val) {
      ticks.forEach((tick, i) => {
        const dVal = detentValues[i];
        tick.classList.toggle('passed', val >= dVal);
        tick.classList.toggle('snapped', Math.abs(val - dVal) < 0.25);
      });
    }

    slider.addEventListener('input', () => {
      let val = parseFloat(slider.value);
      for (const dVal of detentValues) {
        if (Math.abs(val - dVal) <= snapTolerance) {
          val = dVal;
          slider.value = dVal;
          break;
        }
      }
      updateTicks(val);
    });

    updateTicks(parseFloat(slider.value));
  }

  setupSliderDetents('acoustic-db-slider', 0.45);

  // Localization (PT-PT & EN)
  const i18n = {
    'pt-PT': {
      pre_silent: 'Silencioso',
      pre_bal: 'Equilibrado',
      pre_game: 'Gaming',
      pre_comp: 'Trabalho',
      pre_max: 'Máximo',
      btn_stop: 'Sair',
      btn_copy: 'Copiar',
      btn_copied: 'Copiado',
      cpu_kicker: 'Processador',
      m_pkg_power: 'Consumo',
      m_peak_clock: 'Relógio',
      m_core_volt: 'Tensão',
      gpu_kicker: 'Placa Gráfica',
      m_board_pwr: 'Potência',
      m_hotspot: 'Hotspot',
      m_vram_used: 'VRAM',
      hist_60s: 'Últimos 60s',
      liq_kicker: 'Sistema de Água (AIO)',
      water_active: 'Fluxo Ativo',
      water_purging: 'A Purgar Ar',
      pump_silent: 'Calmo',
      pump_bal: 'Normal',
      pump_ext: 'Máx',
      m_pump_spd: 'Bomba',
      m_amb_delta: 'Acima Amb.',
      m_eq_sat: 'Saturação Térmica da Água',
      lbl_sync_coolant: 'Guiar pela água',
      btn_airlock: 'Purgar Bolhas',
      btn_airlock_active: 'A Purgar...',
      bn_tag: 'Saúde & Equilíbrio',
      bn_m_thread: 'Processador (CPU)',
      bn_m_gpu: 'Placa Gráfica (GPU)',
      bn_m_vram: 'Memória Gráfica (VRAM)',
      curve_kicker: 'Controlo Inteligente',
      curve_title: 'Curva de Velocidade das Ventoinhas',
      btn_advanced: 'Opções',
      lbl_temp_src: 'Guiar por',
      opt_max: 'Mais Quente (CPU/GPU)',
      opt_liq: 'Temperatura da Água',
      opt_cpu: 'Apenas Processador',
      opt_gpu: 'Apenas Placa Gráfica',
      lbl_hyst: 'Suavização',
      guard_floor: 'Evitar Paragem GPU',
      lbl_manual: 'Velocidade Fixa',
      tab_twin: 'Gémeo 3D',
      tab_fans: 'Ventoinhas',
      tab_quiet: 'Silêncio',
      tab_games: 'Jogos',
      tab_eco: 'Comunidade',
      twin_heat: 'Heatmap',
      twin_flow: 'Fluxo Ar',
      twin_wire: 'Wireframe',
      eco_profiles: 'Perfis da Comunidade',
      eco_plugins: 'Plugins API',
      btn_apply_prof: 'Aplicar',
      btn_applied: 'Ativo',
      lbl_max_db: 'Limite de Ruído Máximo',
      ac_desc: 'Mantém o PC silencioso até atingir 84°C de segurança.',
      m_est_noise: 'Atual:',
      m_max_pwm_cap: 'Limite:',
      btn_cal: 'Calibrar Ruído das Ventoinhas (10s)',
      cal_running: 'A testar ventoinhas (20% → 100%)...',
      pred_desc_short: 'Acelera o arrefecimento assim que um jogo abre',
      pick_running: '+ Escolher app aberta',
      standby_badge: 'Pronto',
      engaged_prefix: 'Ativo · ',
      acoustic_cap_svg: 'Teto Silencioso',
      floor_lbl: 'Mín',
      state_nominal: 'Normal',
      state_warn: 'Quente',
      state_crit: 'Crítico',
      hw_modal_kicker: 'Deteção Automática',
      hw_modal_title: 'Componentes do Seu Computador',
      btn_rescan: 'Atualizar',
      lbl_startup: 'Iniciar com Windows',
      btn_export: 'Exportar',
      btn_import: 'Importar',
      btn_test_fan: 'Testar',
      btn_testing_fan: '100%...',
      noise_footer: 'Ruído:',
      bn_BALANCED_title: 'Sistema Equilibrado',
      bn_BALANCED_sum: (cpuT, gpu) => `Sem gargalos · CPU ${cpuT}% · GPU ${gpu}%`,
      bn_THERMAL_title: 'Temperatura Elevada',
      bn_THERMAL_sum: () => `Arrefecimento máximo ativado automaticamente`,
      bn_GPU_BOUND_title: 'Modo Jogo Ideal',
      bn_GPU_BOUND_sum: (cpuT, gpu) => `Placa gráfica a ${gpu}% com margem no CPU (${cpuT}%)`,
      bn_CPU_SINGLE_title: 'Carga Alta no CPU',
      bn_CPU_SINGLE_sum: (cpuT, gpu) => `Processador a ${cpuT}% · Placa gráfica a ${gpu}%`
    },
    'en': {
      pre_silent: 'Silent',
      pre_bal: 'Balanced',
      pre_game: 'Gaming',
      pre_comp: 'Workstation',
      pre_max: 'Maximum',
      btn_stop: 'Quit',
      btn_copy: 'Copy',
      btn_copied: 'Copied',
      cpu_kicker: 'Processor',
      m_pkg_power: 'Power',
      m_peak_clock: 'Clock',
      m_core_volt: 'Voltage',
      gpu_kicker: 'Graphics Card',
      m_board_pwr: 'Power',
      m_hotspot: 'Hotspot',
      m_vram_used: 'VRAM',
      hist_60s: 'Last 60s',
      liq_kicker: 'Water System (AIO)',
      water_active: 'Active Flow',
      water_purging: 'Purging Air',
      pump_silent: 'Quiet',
      pump_bal: 'Normal',
      pump_ext: 'Max',
      m_pump_spd: 'Pump',
      m_amb_delta: 'Above Amb.',
      m_eq_sat: 'Water Thermal Saturation',
      lbl_sync_coolant: 'Sync to water',
      btn_airlock: 'Purge Bubbles',
      btn_airlock_active: 'Purging...',
      bn_tag: 'System Health',
      bn_m_thread: 'Processor (CPU)',
      bn_m_gpu: 'Graphics Card (GPU)',
      bn_m_vram: 'Video Memory (VRAM)',
      curve_kicker: 'Smart Cooling',
      curve_title: 'Fan Speed Curve',
      btn_advanced: 'Options',
      lbl_temp_src: 'Guide by',
      opt_max: 'Hottest (CPU/GPU)',
      opt_liq: 'Water Temperature',
      opt_cpu: 'Processor Only',
      opt_gpu: 'Graphics Card Only',
      lbl_hyst: 'Smoothing',
      guard_floor: 'Prevent GPU Fan Stop',
      lbl_manual: 'Fixed Speed',
      tab_twin: '3D Twin',
      tab_fans: 'Fans',
      tab_quiet: 'Silence',
      tab_games: 'Games',
      tab_eco: 'Community',
      twin_heat: 'Heatmap',
      twin_flow: 'Airflow',
      twin_wire: 'Wireframe',
      eco_profiles: 'Community Profiles',
      eco_plugins: 'Plugin API',
      btn_apply_prof: 'Apply',
      btn_applied: 'Applied',
      lbl_max_db: 'Maximum Noise Limit',
      ac_desc: 'Keeps your PC whisper-quiet up to the 84°C safety threshold.',
      m_est_noise: 'Current:',
      m_max_pwm_cap: 'Ceiling:',
      btn_cal: 'Calibrate Fan Acoustics (10s)',
      cal_running: 'Testing fan sweep (20% → 100%)...',
      pred_desc_short: 'Automatically boosts cooling as soon as a game launches',
      pick_running: '+ Pick running app',
      standby_badge: 'Ready',
      engaged_prefix: 'Active · ',
      acoustic_cap_svg: 'Silent Cap',
      floor_lbl: 'Min',
      state_nominal: 'Normal',
      state_warn: 'Warm',
      state_crit: 'Critical',
      hw_modal_kicker: 'Auto-Discovery',
      hw_modal_title: 'Detected System Hardware',
      btn_rescan: 'Refresh',
      lbl_startup: 'Start with Windows',
      btn_export: 'Export',
      btn_import: 'Import',
      btn_test_fan: 'Test',
      btn_testing_fan: '100%...',
      noise_footer: 'Noise:',
      bn_BALANCED_title: 'System Balanced',
      bn_BALANCED_sum: (cpuT, gpu) => `Zero bottlenecks · CPU ${cpuT}% · GPU ${gpu}%`,
      bn_THERMAL_title: 'High Temperature',
      bn_THERMAL_sum: () => `Fans automatically boosting to protect hardware`,
      bn_GPU_BOUND_title: 'Optimal Gaming Load',
      bn_GPU_BOUND_sum: (cpuT, gpu) => `GPU at ${gpu}% full power · CPU at ${cpuT}%`,
      bn_CPU_SINGLE_title: 'Heavy Processor Load',
      bn_CPU_SINGLE_sum: (cpuT, gpu) => `CPU primary thread at ${cpuT}% · GPU at ${gpu}%`
    }
  };

  function t(key) {
    return (i18n[currentLang] && i18n[currentLang][key]) || i18n['pt-PT'][key] || key;
  }

  function applyLanguage(lang) {
    currentLang = lang;
    localStorage.setItem('aether_lang', lang);
    document.getElementById('btn-lang-pt').classList.toggle('active', lang === 'pt-PT');
    document.getElementById('btn-lang-en').classList.toggle('active', lang === 'en');

    document.querySelectorAll('[data-i18n]').forEach(el => {
      const k = el.getAttribute('data-i18n');
      if (i18n[lang] && typeof i18n[lang][k] === 'string') {
        el.textContent = i18n[lang][k];
      }
    });

    if (latestTelemetry) updateDashboard(latestTelemetry);
    loadPredictiveRules();
    loadEcosystemData();
    setTimeout(syncAllSegmentedThumbs, 20);
  }

  document.getElementById('btn-lang-pt').addEventListener('click', () => applyLanguage('pt-PT'));
  document.getElementById('btn-lang-en').addEventListener('click', () => applyLanguage('en'));

  // Hardware scan modal
  const hwBackdrop = document.getElementById('hw-scan-backdrop');
  const hwBody = document.getElementById('hw-scan-body');

  async function openHardwareScanModal(forceRescan = false) {
    hwBackdrop.style.display = 'grid';
    hwBody.innerHTML = `<div class="hw-scan-item full-span"><span class="hw-scan-sub mono">A analisar componentes do computador...</span></div>`;
    try {
      const res = await fetch(forceRescan ? '/api/hardware/scan?refresh=1' : '/api/hardware/scan');
      const hw = await res.json();
      renderHardwareScanReport(hw);
    } catch {}
  }

  function renderHardwareScanReport(hw) {
    const startupChk = document.getElementById('chk-startup-windows');
    if (startupChk && hw.os && typeof hw.os.startupEnabled === 'boolean') {
      startupChk.checked = hw.os.startupEnabled;
    }

    const storageText = hw.storage?.name
      ? `${hw.storage.name} (${hw.storage.tempC || '--'}°C)`
      : 'NVMe SSD';

    hwBody.innerHTML = `
      <div class="hw-scan-item">
        <span class="hw-scan-lbl">PROCESSADOR (CPU)</span>
        <span class="hw-scan-val">${hw.cpu?.name || '--'}</span>
        <span class="hw-scan-sub mono">${hw.cpu?.cores || '--'} Núcleos / ${hw.cpu?.threads || '--'} Threads · ~${hw.cpu?.maxClockMhz || '--'} MHz</span>
      </div>
      <div class="hw-scan-item">
        <span class="hw-scan-lbl">PLACA GRÁFICA (GPU)</span>
        <span class="hw-scan-val">${hw.gpu?.name || '--'}</span>
        <span class="hw-scan-sub mono">${hw.gpu?.vramMb || '--'} MB VRAM · ${hw.gpu?.driver || '--'}</span>
      </div>
      <div class="hw-scan-item">
        <span class="hw-scan-lbl">MOTHERBOARD & SENSORES</span>
        <span class="hw-scan-val">${hw.motherboard?.name || '--'}</span>
        <span class="hw-scan-sub mono">Chip: ${hw.motherboard?.superIoChip || '--'} · BIOS ${hw.motherboard?.biosVersion || 'UEFI'}</span>
      </div>
      <div class="hw-scan-item">
        <span class="hw-scan-lbl">SISTEMA DE ARREFECIMENTO</span>
        <span class="hw-scan-val">${hw.cooling?.controller || '--'}</span>
        <span class="hw-scan-sub mono">${hw.cooling?.fanCount || 4} Canais de Ventoinha Ativos</span>
      </div>
      <div class="hw-scan-item full-span">
        <span class="hw-scan-lbl">MEMÓRIA RAM, DISCO & SISTEMA OPERATIVO</span>
        <span class="hw-scan-val">${hw.memory?.totalGb || '--'} GB RAM (${hw.memory?.speedMhz || '--'} MHz) · ${storageText}</span>
        <span class="hw-scan-sub mono">${hw.os?.caption || '--'}</span>
      </div>
    `;
  }

  const startupChkEl = document.getElementById('chk-startup-windows');
  if (startupChkEl) {
    startupChkEl.addEventListener('change', async (e) => {
      try {
        const res = await fetch('/api/system/startup', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ enabled: e.target.checked })
        });
        const data = await res.json();
        e.target.checked = Boolean(data.enabled);
      } catch {}
    });
  }

  async function exportUserProfile() {
    try {
      const res = await fetch('/api/profile/export');
      if (!res.ok) return;
      const profile = await res.json();
      const blob = new Blob([JSON.stringify(profile, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'aether-profile.json';
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch {}
  }

  const exportBtn = document.getElementById('btn-export-profile');
  const importBtn = document.getElementById('btn-import-profile');
  const importInput = document.getElementById('file-import-profile');

  if (exportBtn) exportBtn.addEventListener('click', exportUserProfile);
  if (importBtn && importInput) {
    importBtn.addEventListener('click', () => importInput.click());
    importInput.addEventListener('change', async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      try {
        const text = await file.text();
        const res = await fetch('/api/profile/import', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: text
        });
        if (res.ok) {
          currentConfig = await res.json();
          renderFanCurve();
          loadPredictiveRules();
        }
      } catch {}
      importInput.value = '';
    });
  }

  async function triggerFanIdentify(fanId) {
    if (!fanId) return;
    try {
      await fetch(`/api/fan/identify/${encodeURIComponent(fanId)}`, { method: 'POST' });
    } catch {}
  }

  document.querySelectorAll('.btn-fan-test').forEach((btn) => {
    btn.addEventListener('click', () => triggerFanIdentify(btn.getAttribute('data-fan-id')));
  });

  document.getElementById('btn-open-hw-scan').addEventListener('click', () => openHardwareScanModal(false));
  document.getElementById('btn-rescan-now').addEventListener('click', () => openHardwareScanModal(true));
  document.getElementById('btn-close-hw-modal').addEventListener('click', () => { hwBackdrop.style.display = 'none'; });
  hwBackdrop.addEventListener('click', (e) => { if (e.target === hwBackdrop) hwBackdrop.style.display = 'none'; });

  // Clipboard summary & daemon shutdown
  const copyBtn = document.getElementById('btn-copy-telemetry');
  if (copyBtn) {
    copyBtn.addEventListener('click', async () => {
      if (!latestTelemetry) return;
      const s = latestTelemetry;
      const text = `${s.identity.cpuName} (${s.cpuTempC.toFixed(0)}°C, ${s.cpuPowerWatts.toFixed(0)}W) | ${s.identity.gpuName} (${s.gpuTempC.toFixed(0)}°C, ${s.gpuPowerWatts.toFixed(0)}W) | Água AIO: ${s.liquidCooling?.coolantTempC.toFixed(1)}°C`;
      try { await navigator.clipboard.writeText(text); } catch {}
      copyBtn.classList.add('copied');
      const span = copyBtn.querySelector('span');
      if (span) span.textContent = t('btn_copied');
      setTimeout(() => {
        copyBtn.classList.remove('copied');
        if (span) span.textContent = t('btn_copy');
      }, 1500);
    });
  }

  const stopBtn = document.getElementById('btn-stop-daemon');
  let holdTimer = null;

  async function executeDaemonShutdown() {
    const lbl = document.getElementById('stop-btn-label');
    if (lbl) lbl.textContent = 'Offline';
    if (pollingTimer) {
      clearInterval(pollingTimer);
      pollingTimer = null;
    }
    try {
      await fetch('/api/daemon/shutdown', { method: 'POST' });
    } catch {}
    document.getElementById('bn-verdict').textContent = 'Serviço Desligado';
    setTimeout(() => {
      try { window.close(); } catch {}
    }, 500);
  }

  if (stopBtn) {
    stopBtn.addEventListener('pointerdown', () => {
      stopBtn.classList.add('holding');
      holdTimer = setTimeout(executeDaemonShutdown, 450);
    });
    const cancelHold = () => {
      stopBtn.classList.remove('holding');
      if (holdTimer) {
        clearTimeout(holdTimer);
        holdTimer = null;
      }
    };
    stopBtn.addEventListener('pointerup', cancelHold);
    stopBtn.addEventListener('pointerleave', cancelHold);
    stopBtn.addEventListener('click', executeDaemonShutdown);
  }

  // Command palette (Ctrl+K)
  const cmdBackdrop = document.getElementById('cmd-backdrop');
  const cmdInput = document.getElementById('cmd-search-input');
  const cmdList = document.getElementById('cmd-results-list');
  let cmdSelectedIdx = 0;

  function switchRightTab(tabId) {
    const tabsBar = document.getElementById('right-panel-tabs');
    if (!tabsBar) return;
    tabsBar.querySelectorAll('.seg-pill-btn').forEach((b) => {
      b.classList.toggle('active', b.getAttribute('data-tab') === tabId);
    });
    syncSegmentedThumb(tabsBar);
    document.querySelectorAll('.tab-pane').forEach((pane) => {
      pane.style.display = pane.id === tabId ? 'flex' : 'none';
    });
  }

  const commandActions = [
    { label: () => `Tema: Alternar Modo Claro (White) / Modo Escuro (Dark)`, tag: 'Aparência', run: () => applyTheme(currentTheme === 'dark' ? 'light' : 'dark') },
    { label: () => `Gémeo 3D: Ver Heatmap Térmico e Fluxo de Ar 3D`, tag: '3D Twin', run: () => switchRightTab('tab-twin') },
    { label: () => `Ventoinhas: Ver e Testar Canais Físicos`, tag: 'Ventoinhas', run: () => switchRightTab('tab-fans') },
    { label: () => `Comunidade: Perfis Populares e Plugins`, tag: 'Ecosistema', run: () => switchRightTab('tab-ecosystem') },
    { label: () => `${t('pre_silent')} — Modo Silencioso`, tag: 'Perfil', run: () => triggerPreset('Silent') },
    { label: () => `${t('pre_bal')} — Modo Equilibrado`, tag: 'Perfil', run: () => triggerPreset('Balanced') },
    { label: () => `${t('pre_game')} — Modo Gaming`, tag: 'Perfil', run: () => triggerPreset('Predictive Gaming') },
    { label: () => `${t('pre_max')} — Velocidade Máxima (100%)`, tag: 'Perfil', run: () => triggerPreset('Max Cooling') },
    { label: () => `Purgar Bolhas do Sistema de Água (AIO)`, tag: 'Água AIO', run: () => document.getElementById('btn-airlock-pulse').click() },
    { label: () => `Exportar Perfil de Ventoinhas (.json)`, tag: 'Perfil', run: exportUserProfile },
    { label: () => `Importar Perfil de Ventoinhas (.json)`, tag: 'Perfil', run: () => document.getElementById('file-import-profile')?.click() },
    { label: () => `Inspecionar Componentes do PC`, tag: 'Hardware', run: () => openHardwareScanModal(true) },
    { label: () => `Idioma: Alternar Português / English`, tag: 'Idioma', run: () => applyLanguage(currentLang === 'pt-PT' ? 'en' : 'pt-PT') },
    { label: () => t('btn_stop'), tag: 'Sistema', run: executeDaemonShutdown }
  ];

  function openCmdPalette() {
    cmdBackdrop.style.display = 'grid';
    cmdInput.value = '';
    cmdSelectedIdx = 0;
    renderCmdList();
    setTimeout(() => cmdInput.focus(), 20);
  }

  function closeCmdPalette() {
    cmdBackdrop.style.display = 'none';
  }

  function getFilteredCommands() {
    const q = cmdInput.value.trim().toLowerCase();
    return commandActions.filter(c => c.label().toLowerCase().includes(q) || c.tag.toLowerCase().includes(q));
  }

  function renderCmdList() {
    const filtered = getFilteredCommands();
    if (cmdSelectedIdx >= filtered.length) cmdSelectedIdx = Math.max(0, filtered.length - 1);
    cmdList.innerHTML = filtered.map((item, idx) => `
      <div class="cmd-item ${idx === cmdSelectedIdx ? 'selected' : ''}" data-cmd-idx="${idx}">
        <span>${item.label()}</span>
        <span class="cmd-item-tag mono">${item.tag}</span>
      </div>
    `).join('');

    cmdList.querySelectorAll('.cmd-item').forEach(el => {
      el.addEventListener('click', () => {
        const idx = parseInt(el.getAttribute('data-cmd-idx'), 10);
        if (filtered[idx]) {
          filtered[idx].run();
          closeCmdPalette();
        }
      });
    });
  }

  document.getElementById('btn-open-cmd').addEventListener('click', openCmdPalette);
  cmdBackdrop.addEventListener('click', (e) => { if (e.target === cmdBackdrop) closeCmdPalette(); });
  cmdInput.addEventListener('input', () => { cmdSelectedIdx = 0; renderCmdList(); });

  window.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      if (cmdBackdrop.style.display === 'none') openCmdPalette();
      else closeCmdPalette();
    } else if (e.key === 'Escape') {
      closeCmdPalette();
      hwBackdrop.style.display = 'none';
    } else if (cmdBackdrop.style.display !== 'none') {
      const filtered = getFilteredCommands();
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        cmdSelectedIdx = (cmdSelectedIdx + 1) % Math.max(1, filtered.length);
        renderCmdList();
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        cmdSelectedIdx = (cmdSelectedIdx - 1 + Math.max(1, filtered.length)) % Math.max(1, filtered.length);
        renderCmdList();
      } else if (e.key === 'Enter' && filtered[cmdSelectedIdx]) {
        e.preventDefault();
        filtered[cmdSelectedIdx].run();
        closeCmdPalette();
      }
    }
  });

  // Gauges & sparklines
  const svg = document.getElementById('fan-curve-svg');
  const tempSourceSelect = document.getElementById('temp-source-select');
  const hysteresisInput = document.getElementById('hysteresis-input');
  const manualToggle = document.getElementById('manual-override-toggle');
  const manualSlider = document.getElementById('manual-pwm-slider');
  const manualLabel = document.getElementById('manual-pwm-label');

  function updateRadialLoadRing(ringId, labelId, loadPct, temp) {
    const circle = document.getElementById(ringId);
    const lbl = document.getElementById(labelId);
    if (lbl) lbl.textContent = `${Math.round(loadPct)}%`;
    if (!circle) return;
    const circumference = 194.8;
    const pct = Math.min(1, Math.max(0.04, loadPct / 100));
    circle.style.strokeDashoffset = (circumference * (1 - pct)).toFixed(1);

    const nominalStroke = currentTheme === 'light' ? '#0F172A' : '#FAFAFA';
    if (temp >= 82) circle.style.stroke = '#F43F5E';
    else if (temp >= 68) circle.style.stroke = '#F59E0B';
    else circle.style.stroke = nominalStroke;
  }

  function updateThermalCardState(cardId, chipId, temp) {
    const card = document.getElementById(cardId);
    const chip = document.getElementById(chipId);
    if (!card || !chip) return;

    card.classList.remove('thermal-warn', 'thermal-crit');
    chip.classList.remove('nominal', 'warning', 'critical');

    if (temp >= 82) {
      card.classList.add('thermal-crit');
      chip.classList.add('critical');
      chip.textContent = t('state_crit');
    } else if (temp >= 68) {
      card.classList.add('thermal-warn');
      chip.classList.add('warning');
      chip.textContent = t('state_warn');
    } else {
      chip.classList.add('nominal');
      chip.textContent = t('state_nominal');
    }
  }

  function updateProgressBar(barId, pct) {
    const bar = document.getElementById(barId);
    if (!bar) return;
    bar.style.width = `${Math.min(100, Math.max(0, pct))}%`;
    bar.classList.remove('load-warn', 'load-crit');
    if (pct >= 90) bar.classList.add('load-crit');
    else if (pct >= 75) bar.classList.add('load-warn');
  }

  function setupSparklineHover(canvasId, setHoverIdx) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    canvas.addEventListener('pointermove', (e) => {
      const rect = canvas.getBoundingClientRect();
      const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / Math.max(1, rect.width)));
      setHoverIdx(Math.round(ratio * 59));
    });
    canvas.addEventListener('pointerleave', () => setHoverIdx(-1));
  }

  setupSparklineHover('cpu-sparkline', (idx) => { cpuHoverIdx = idx; });
  setupSparklineHover('gpu-sparkline', (idx) => { gpuHoverIdx = idx; });

  function drawSmoothSparkline(canvasId, minmaxId, data, strokeColor, gradTopColor, hoverIdx) {
    const canvas = document.getElementById(canvasId);
    if (!canvas || data.length === 0) return;

    const dpr = window.devicePixelRatio || 1;
    const cssW = canvas.clientWidth || 240;
    const cssH = 42;
    if (canvas.width !== Math.round(cssW * dpr) || canvas.height !== Math.round(cssH * dpr)) {
      canvas.width = Math.round(cssW * dpr);
      canvas.height = Math.round(cssH * dpr);
    }

    const ctx = canvas.getContext('2d');
    ctx.save();
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, cssW, cssH);

    const rawMin = Math.min(...data);
    const rawMax = Math.max(...data);
    const minmaxEl = document.getElementById(minmaxId);
    if (minmaxEl) {
      minmaxEl.textContent = `${rawMin.toFixed(0)}°C – ${rawMax.toFixed(0)}°C`;
    }

    const min = Math.floor(rawMin - 3.5);
    const max = Math.ceil(Math.max(rawMax + 3.5, min + 8));

    const padR = 6;
    const plotW = cssW - padR;
    const step = plotW / Math.max(1, data.length - 1);

    const pts = data.map((v, i) => ({
      x: i * step,
      y: cssH - ((Math.min(max, Math.max(min, v)) - min) / (max - min)) * (cssH - 12) - 6,
      val: v
    }));

    const grad = ctx.createLinearGradient(0, 0, 0, cssH);
    grad.addColorStop(0, gradTopColor);
    grad.addColorStop(1, 'rgba(0, 0, 0, 0.0)');

    ctx.beginPath();
    ctx.moveTo(pts[0].x, pts[0].y);
    for (let i = 0; i < pts.length - 1; i++) {
      const xc = (pts[i].x + pts[i + 1].x) / 2;
      const yc = (pts[i].y + pts[i + 1].y) / 2;
      ctx.quadraticCurveTo(pts[i].x, pts[i].y, xc, yc);
    }
    const last = pts[pts.length - 1];
    ctx.lineTo(last.x, last.y);

    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = 1.8;
    ctx.stroke();

    ctx.lineTo(last.x, cssH);
    ctx.lineTo(pts[0].x, cssH);
    ctx.closePath();
    ctx.fillStyle = grad;
    ctx.fill();

    ctx.beginPath();
    ctx.arc(last.x, last.y, 2.8, 0, Math.PI * 2);
    ctx.fillStyle = strokeColor;
    ctx.fill();

    if (hoverIdx >= 0 && hoverIdx < pts.length) {
      const hp = pts[hoverIdx];
      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(hp.x, 0);
      ctx.lineTo(hp.x, cssH);
      ctx.stroke();

      const label = `${hp.val.toFixed(1)}°C`;
      ctx.font = '600 10px "JetBrains Mono", monospace';
      const tw = ctx.measureText(label).width + 10;
      const tx = Math.min(cssW - tw - 2, Math.max(2, hp.x - tw / 2));
      ctx.fillStyle = currentTheme === 'light' ? '#0F172A' : '#FAFAFA';
      ctx.fillRect(tx, 2, tw, 15);
      ctx.fillStyle = currentTheme === 'light' ? '#FFFFFF' : '#09090B';
      ctx.fillText(label, tx + 5, 12.5);
    }

    ctx.restore();
  }

  // Fan speed curve SVG editor
  function interpolateCurvePwm(temp, pts) {
    if (!pts || pts.length === 0) return 50;
    if (temp <= pts[0].tempC) return pts[0].pwmPercent;
    if (temp >= pts[pts.length - 1].tempC) return pts[pts.length - 1].pwmPercent;
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = pts[i];
      const p1 = pts[i + 1];
      if (temp >= p0.tempC && temp <= p1.tempC) {
        const r = (temp - p0.tempC) / Math.max(0.1, p1.tempC - p0.tempC);
        const smoothR = r * r * (3 - 2 * r);
        return p0.pwmPercent + smoothR * (p1.pwmPercent - p0.pwmPercent);
      }
    }
    return pts[pts.length - 1].pwmPercent;
  }

  function buildSmoothSvgPath(points) {
    if (points.length < 2) return '';
    let d = `M ${points[0].x.toFixed(1)} ${points[0].y.toFixed(1)}`;
    for (let i = 0; i < points.length - 1; i++) {
      const p0 = points[i];
      const p1 = points[i + 1];
      const cpx1 = p0.x + (p1.x - p0.x) * 0.45;
      const cpy1 = p0.y;
      const cpx2 = p0.x + (p1.x - p0.x) * 0.55;
      const cpy2 = p1.y;
      d += ` C ${cpx1.toFixed(1)} ${cpy1.toFixed(1)}, ${cpx2.toFixed(1)} ${cpy2.toFixed(1)}, ${p1.x.toFixed(1)} ${p1.y.toFixed(1)}`;
    }
    return d;
  }

  function getCurveGeometry() {
    const W = Math.max(460, svg.clientWidth || 680);
    const H = 220;
    const padL = 40, padR = 18, padT = 18, padB = 24;
    const plotW = W - padL - padR;
    const plotH = H - padT - padB;
    return { W, H, padL, padR, padT, padB, plotW, plotH };
  }

  function renderFanCurve() {
    if (!currentConfig || !currentConfig.curvePoints) return;
    const { W, H, padL, padR, padT, padB, plotW, plotH } = getCurveGeometry();
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);

    const isLight = currentTheme === 'light';
    const primaryStroke = isLight ? '#0F172A' : '#FAFAFA';
    const mutedSpline = isLight ? 'rgba(15, 23, 42, 0.25)' : 'rgba(255, 255, 255, 0.25)';
    const cardBg = isLight ? '#FFFFFF' : '#101014';
    const gridColor = isLight ? 'rgba(15, 23, 42, 0.06)' : 'rgba(255, 255, 255, 0.055)';
    const labelColor = isLight ? '#64748B' : '#71717A';

    const tempToX = (temp) => padL + ((Math.min(100, Math.max(20, temp)) - 20) / 80) * plotW;
    const pwmToY = (p) => padT + (1 - Math.min(100, Math.max(0, p)) / 100) * plotH;

    let liveTemp = 50;
    let displayTemp = 50;
    if (latestTelemetry) {
      const syncWater = (currentConfig.temperatureSource === 'LIQUID_COOLANT') ||
        (latestTelemetry.liquidCooling && latestTelemetry.liquidCooling.radiatorFanSyncToCoolant);
      if (syncWater && latestTelemetry.liquidCooling) {
        displayTemp = latestTelemetry.liquidCooling.coolantTempC;
        liveTemp = (displayTemp - 24.0) * 2.4 + 30.0;
      } else if (currentConfig.temperatureSource === 'CPU') {
        liveTemp = latestTelemetry.cpuTempC;
        displayTemp = liveTemp;
      } else if (currentConfig.temperatureSource === 'GPU') {
        liveTemp = latestTelemetry.gpuTempC;
        displayTemp = liveTemp;
      } else {
        liveTemp = Math.max(latestTelemetry.cpuTempC, latestTelemetry.gpuTempC);
        displayTemp = liveTemp;
      }
    }
    const liveX = tempToX(liveTemp);

    let html = `
      <defs>
        <linearGradient id="curveGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#06B6D4" stop-opacity="${isLight ? '0.16' : '0.22'}"/>
          <stop offset="100%" stop-color="#06B6D4" stop-opacity="0.0"/>
        </linearGradient>
        <linearGradient id="activeLineGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stop-color="#06B6D4"/>
          <stop offset="100%" stop-color="#10B981"/>
        </linearGradient>
        <clipPath id="activeTempClip">
          <rect x="${padL}" y="0" width="${Math.max(0, liveX - padL).toFixed(1)}" height="${H}"/>
        </clipPath>
      </defs>
    `;

    for (let p = 0; p <= 100; p += 25) {
      const y = pwmToY(p);
      const dash = p === 0 ? '' : 'stroke-dasharray="4,4"';
      html += `<line x1="${padL}" y1="${y.toFixed(1)}" x2="${W - padR}" y2="${y.toFixed(1)}" stroke="${gridColor}" stroke-width="1" ${dash}/>`;
      html += `<text x="${padL - 8}" y="${(y + 3.5).toFixed(1)}" text-anchor="end" fill="${labelColor}" font-size="10" font-family="JetBrains Mono, monospace">${p}%</text>`;
    }

    for (let temp = 20; temp <= 100; temp += 20) {
      const x = tempToX(temp);
      html += `<text x="${x.toFixed(1)}" y="${H - 5}" text-anchor="middle" fill="${labelColor}" font-size="10" font-family="JetBrains Mono, monospace">${temp}°C</text>`;
    }

    if (latestTelemetry && latestTelemetry.acoustic && latestTelemetry.acoustic.enabled) {
      const capPct = latestTelemetry.acoustic.computedMaxPwmCapPercent;
      const capY = pwmToY(capPct);
      html += `<line x1="${padL}" y1="${capY.toFixed(1)}" x2="${W - padR}" y2="${capY.toFixed(1)}" stroke="#F59E0B" stroke-dasharray="3,5" stroke-width="1" opacity="0.65"/>`;
      html += `<text x="${W - padR - 2}" y="${Math.max(12, capY - 5)}" text-anchor="end" fill="#F59E0B" font-size="9.5" font-weight="600" font-family="Plus Jakarta Sans, sans-serif">${t('acoustic_cap_svg')} ${capPct.toFixed(0)}%</text>`;
    }

    const pts = currentConfig.curvePoints;
    if (pts.length >= 2) {
      const screenPts = pts.map(pt => ({ x: tempToX(pt.tempC), y: pwmToY(pt.pwmPercent), raw: pt }));
      const splinePath = buildSmoothSvgPath(screenPts);
      const areaPath = `${splinePath} L ${screenPts[screenPts.length - 1].x.toFixed(1)} ${H - padB} L ${screenPts[0].x.toFixed(1)} ${H - padB} Z`;

      html += `<path d="${areaPath}" fill="url(#curveGrad)" opacity="0.45"/>`;
      html += `<path d="${areaPath}" fill="url(#curveGrad)" clip-path="url(#activeTempClip)"/>`;
      html += `<path d="${splinePath}" fill="none" stroke="${mutedSpline}" stroke-width="2.2" stroke-linecap="round"/>`;
      html += `<path d="${splinePath}" fill="none" stroke="url(#activeLineGrad)" stroke-width="3" stroke-linecap="round" clip-path="url(#activeTempClip)"/>`;

      if (latestTelemetry) {
        const targetPwmNow = latestTelemetry.fanChannels && latestTelemetry.fanChannels.length > 1
          ? latestTelemetry.fanChannels[1].targetPwmPercent
          : interpolateCurvePwm(liveTemp, pts);
        const ty = pwmToY(targetPwmNow);

        html += `<line x1="${liveX.toFixed(1)}" y1="${ty.toFixed(1)}" x2="${liveX.toFixed(1)}" y2="${H - padB}" stroke="#10B981" stroke-width="1.2" stroke-dasharray="2,3" opacity="0.7"/>`;
        html += `<circle cx="${liveX.toFixed(1)}" cy="${ty.toFixed(1)}" r="8" fill="rgba(16,185,129,0.2)"/>`;
        html += `<circle cx="${liveX.toFixed(1)}" cy="${ty.toFixed(1)}" r="4" fill="#10B981" stroke="${cardBg}" stroke-width="2"/>`;

        const estRpm = Math.round(520 + (targetPwmNow / 100) * 1450);
        const hudTempEl = document.getElementById('hud-live-temp');
        const hudOutEl = document.getElementById('hud-target-out');
        const hudNoiseEl = document.getElementById('hud-live-noise');
        if (hudTempEl) hudTempEl.textContent = `${displayTemp.toFixed(0)}°C`;
        if (hudOutEl) hudOutEl.textContent = `${targetPwmNow.toFixed(0)}% · ${estRpm} RPM`;
        if (hudNoiseEl && latestTelemetry.acoustic) {
          hudNoiseEl.textContent = `${t('noise_footer')} ${latestTelemetry.acoustic.estimatedFanDb.toFixed(1)} dBA`;
        }
      }

      screenPts.forEach((sp, idx) => {
        const isActive = idx === draggingNodeIdx || idx === hoveredNodeIdx;
        const nodeStroke = sp.x <= liveX ? '#06B6D4' : primaryStroke;

        html += `<circle cx="${sp.x.toFixed(1)}" cy="${sp.y.toFixed(1)}" r="${isActive ? 13 : 8}" fill="${nodeStroke}" fill-opacity="${isActive ? '0.2' : '0.06'}" pointer-events="none"/>`;
        html += `<circle data-idx="${idx}" cx="${sp.x.toFixed(1)}" cy="${sp.y.toFixed(1)}" r="${isActive ? 6.5 : 5}" fill="${cardBg}" stroke="${nodeStroke}" stroke-width="2.4" style="cursor:${draggingNodeIdx === idx ? 'grabbing' : 'grab'}"/>`;
      });

      const activeIdx = draggingNodeIdx >= 0 ? draggingNodeIdx : hoveredNodeIdx;
      if (activeIdx >= 0 && screenPts[activeIdx]) {
        const sp = screenPts[activeIdx];
        const pillW = 104;
        const pillX = Math.min(W - padR - pillW, Math.max(padL, sp.x - pillW / 2));
        const pillY = sp.y < padT + 28 ? sp.y + 14 : sp.y - 30;
        html += `<rect x="${pillX.toFixed(1)}" y="${pillY.toFixed(1)}" width="${pillW}" height="20" rx="6" fill="${primaryStroke}"/>`;
        html += `<text x="${(pillX + pillW / 2).toFixed(1)}" y="${(pillY + 13.5).toFixed(1)}" text-anchor="middle" fill="${cardBg}" font-size="10.5" font-weight="600" font-family="JetBrains Mono, monospace">P${activeIdx + 1}: ${Math.round(sp.raw.tempC)}°C · ${Math.round(sp.raw.pwmPercent)}%</text>`;
      } else if (curveHoverTempC !== null) {
        const hx = tempToX(curveHoverTempC);
        const hPwm = interpolateCurvePwm(curveHoverTempC, pts);
        const hy = pwmToY(hPwm);
        html += `<circle cx="${hx.toFixed(1)}" cy="${hy.toFixed(1)}" r="3.5" fill="${primaryStroke}" pointer-events="none"/>`;
      }

      const stripEl = document.getElementById('curve-points-strip');
      if (stripEl) {
        stripEl.innerHTML = pts.map((pt, idx) => `
          <div class="curve-node-pill ${idx === activeIdx ? 'active-node' : ''}">
            <span class="pt-idx">P${idx + 1}</span>
            <span>${Math.round(pt.tempC)}°C · <strong>${Math.round(pt.pwmPercent)}%</strong></span>
          </div>
        `).join('');
      }
    }

    svg.innerHTML = html;
  }

  svg.addEventListener('pointerdown', (e) => {
    const idx = e.target.getAttribute('data-idx');
    if (idx !== null) {
      draggingNodeIdx = parseInt(idx, 10);
      svg.setPointerCapture(e.pointerId);
      renderFanCurve();
    }
  });

  svg.addEventListener('pointermove', (e) => {
    const rect = svg.getBoundingClientRect();
    const { padL, padT, plotW, plotH } = getCurveGeometry();
    const relX = e.clientX - rect.left;
    const relY = e.clientY - rect.top;

    if (draggingNodeIdx >= 0 && currentConfig) {
      let newTemp = Math.round(20 + ((relX - padL) / plotW) * 80);
      let newPwm = Math.round((1 - (relY - padT) / plotH) * 100);

      newTemp = Math.max(20, Math.min(100, newTemp));
      newPwm = Math.max(10, Math.min(100, newPwm));

      const pts = currentConfig.curvePoints;
      if (draggingNodeIdx > 0) newTemp = Math.max(pts[draggingNodeIdx - 1].tempC + 2, newTemp);
      if (draggingNodeIdx < pts.length - 1) newTemp = Math.min(pts[draggingNodeIdx + 1].tempC - 2, newTemp);

      pts[draggingNodeIdx] = { tempC: newTemp, pwmPercent: newPwm };
      currentConfig.activePreset = 'Custom';
      renderFanCurve();
    } else {
      const idxAttr = e.target.getAttribute('data-idx');
      hoveredNodeIdx = idxAttr !== null ? parseInt(idxAttr, 10) : -1;
      const hoverT = 20 + ((relX - padL) / plotW) * 80;
      curveHoverTempC = (hoverT >= 20 && hoverT <= 100) ? Math.round(hoverT) : null;
      renderFanCurve();
    }
  });

  svg.addEventListener('pointerleave', () => {
    if (draggingNodeIdx < 0) {
      hoveredNodeIdx = -1;
      curveHoverTempC = null;
      renderFanCurve();
    }
  });

  svg.addEventListener('pointerup', async () => {
    if (draggingNodeIdx >= 0) {
      draggingNodeIdx = -1;
      renderFanCurve();
      await pushFanConfig();
    }
  });

  async function pushFanConfig() {
    if (!currentConfig) return;
    currentConfig.temperatureSource = tempSourceSelect.value;
    currentConfig.hysteresisDeadbandC = parseFloat(hysteresisInput.value) || 3.0;
    currentConfig.manualOverrideEnabled = manualToggle.checked;
    currentConfig.manualOverridePercent = parseFloat(manualSlider.value) || 50;

    await fetch('/api/fan/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(currentConfig)
    });
  }

  tempSourceSelect.addEventListener('change', pushFanConfig);
  hysteresisInput.addEventListener('change', pushFanConfig);
  manualToggle.addEventListener('change', () => {
    manualSlider.disabled = !manualToggle.checked;
    pushFanConfig();
  });
  manualSlider.addEventListener('input', () => {
    manualLabel.textContent = `${manualSlider.value}%`;
    pushFanConfig();
  });

  async function triggerPreset(presetName) {
    document.querySelectorAll('.btn-preset').forEach(b => {
      b.classList.toggle('active', b.getAttribute('data-preset') === presetName);
    });
    syncSegmentedThumb(document.getElementById('preset-segmented'));
    const res = await fetch(`/api/fan/preset/${encodeURIComponent(presetName)}`, { method: 'POST' });
    currentConfig = await res.json();
    manualToggle.checked = false;
    manualSlider.disabled = true;
    renderFanCurve();
  }

  document.querySelectorAll('.btn-preset').forEach(btn => {
    btn.addEventListener('click', () => triggerPreset(btn.getAttribute('data-preset')));
  });

  document.querySelectorAll('[data-pump]').forEach(btn => {
    btn.addEventListener('click', async () => {
      document.querySelectorAll('[data-pump]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      syncSegmentedThumb(document.getElementById('pump-segmented'));
      const mode = btn.getAttribute('data-pump');
      await fetch('/api/liquid/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pumpMode: mode })
      });
    });
  });

  document.getElementById('chk-sync-coolant').addEventListener('change', async (e) => {
    const syncWater = e.target.checked;
    if (tempSourceSelect) {
      tempSourceSelect.value = syncWater ? 'LIQUID_COOLANT' : 'MAX_CPU_GPU';
    }
    if (currentConfig) {
      currentConfig.temperatureSource = syncWater ? 'LIQUID_COOLANT' : 'MAX_CPU_GPU';
    }
    await fetch('/api/liquid/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ radiatorFanSyncToCoolant: syncWater })
    });
    await pushFanConfig();
    renderFanCurve();
  });

  document.getElementById('btn-airlock-pulse').addEventListener('click', async () => {
    await fetch('/api/liquid/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ triggerAntiAirlockPulse: true })
    });
  });

  async function pushGpuGuardConfig() {
    await fetch('/api/gpuguard/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        antiZeroRpmChatterEnabled: document.getElementById('chk-gpu-guard').checked,
        minimumActiveFanFloorPct: parseFloat(document.getElementById('num-gpu-guard-pct').value) || 32
      })
    });
  }
  document.getElementById('chk-gpu-guard').addEventListener('change', pushGpuGuardConfig);
  document.getElementById('num-gpu-guard-pct').addEventListener('change', pushGpuGuardConfig);

  async function loadPredictiveRules() {
    try {
      const [rulesRes, appsRes] = await Promise.all([
        fetch('/api/predictive/rules'),
        fetch('/api/predictive/running-apps')
      ]);
      if (!rulesRes.ok || !appsRes.ok) return;
      const rules = await rulesRes.json();
      const apps = await appsRes.json();

      const picker = document.getElementById('running-exe-picker');
      picker.innerHTML = `<option value="">${t('pick_running')} (${apps.length})...</option>` +
        apps.map(a => `<option value="${a}">${a}</option>`).join('');

      renderRulesList(rules);
    } catch {}
  }

  function renderRulesList(rules) {
    const container = document.getElementById('predictive-rules-list');
    const activeExe = latestTelemetry?.activePredictiveRule?.executableName?.toLowerCase();

    container.innerHTML = rules.map(r => {
      const isEngaged = activeExe && r.executableName.toLowerCase() === activeExe;
      return `
        <div class="rule-row ${isEngaged ? 'active-rule' : ''}">
          <div>
            <strong>${r.displayName}</strong>
            <span class="mono text-muted" style="margin-left:6px; font-size:11px;">${r.executableName}</span>
          </div>
          <div style="display:flex; align-items:center; gap:10px;">
            <span class="mono">${t('floor_lbl')} ${r.preChargePwmFloorPercent}%</span>
            <button class="btn-del" data-exe="${r.executableName}" title="Remover">&times;</button>
          </div>
        </div>
      `;
    }).join('');

    container.querySelectorAll('.btn-del').forEach(btn => {
      btn.addEventListener('click', async () => {
        const exe = btn.getAttribute('data-exe');
        const res = await fetch(`/api/predictive/rules/${encodeURIComponent(exe)}`, { method: 'DELETE' });
        renderRulesList(await res.json());
      });
    });
  }

  document.getElementById('running-exe-picker').addEventListener('change', (e) => {
    if (e.target.value) {
      document.getElementById('new-rule-exe').value = e.target.value;
    }
  });

  document.getElementById('btn-add-rule').addEventListener('click', async () => {
    const exeInput = document.getElementById('new-rule-exe');
    const pwmInput = document.getElementById('new-rule-pwm');
    const exe = exeInput.value.trim();
    if (!exe) return;

    const res = await fetch('/api/predictive/rules', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        executableName: exe,
        displayName: exe.replace(/\.exe$/i, ''),
        profilePreset: 'Predictive Gaming',
        preChargePwmFloorPercent: parseFloat(pwmInput.value) || 55,
        cooldownPurgeSeconds: 25
      })
    });
    exeInput.value = '';
    renderRulesList(await res.json());
  });

  const acousticToggle = document.getElementById('acoustic-enabled-toggle');
  const acousticSlider = document.getElementById('acoustic-db-slider');
  const acousticLabel = document.getElementById('acoustic-db-label');

  async function pushAcousticConfig() {
    acousticLabel.textContent = `${parseFloat(acousticSlider.value).toFixed(1)} dBA`;
    await fetch('/api/acoustic/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        enabled: acousticToggle.checked,
        maxAllowedDbCeiling: parseFloat(acousticSlider.value)
      })
    });
  }

  acousticToggle.addEventListener('change', pushAcousticConfig);
  acousticSlider.addEventListener('input', pushAcousticConfig);

  document.getElementById('btn-calibrate-acoustic').addEventListener('click', async () => {
    await fetch('/api/acoustic/calibrate', { method: 'POST' });
  });

  function getShortHwName(rawName, fallback) {
    if (!rawName) return fallback;
    return rawName
      .replace(/\(R\)|\(TM\)|Processor|8-Core|6-Core|12-Core|16-Core|NVIDIA GeForce |AMD Radeon |Gigabyte Technology Co\., Ltd\. /gi, '')
      .trim();
  }

  // Dashboard telemetry update
  function updateDashboard(snap) {
    latestTelemetry = snap;
    if (!currentConfig) {
      currentConfig = snap.activeFanConfig;
      renderFanCurve();
    }

    const isLight = currentTheme === 'light';
    const cpuShort = snap.identity.cpuShortName || getShortHwName(snap.identity.cpuName, 'CPU');
    const gpuShort = snap.identity.gpuShortName || getShortHwName(snap.identity.gpuName, 'GPU');
    const moboShort = snap.identity.moboShortName || getShortHwName(snap.identity.motherboardName, 'Motherboard');

    const hwSumEl = document.getElementById('hw-summary');
    hwSumEl.textContent = `${cpuShort} · ${gpuShort}`;
    hwSumEl.title = `${snap.identity.cpuName} | ${snap.identity.gpuName} | ${snap.identity.motherboardName}`;

    if (snap.energy) {
      const suffix = currentLang === 'pt-PT' ? '€/mês' : '€/mo';
      document.getElementById('energy-pill').textContent =
        `${snap.energy.totalSystemWatts.toFixed(0)} W · ${snap.energy.estimatedMonthlyEur.toFixed(2)} ${suffix}`;
    }

    document.getElementById('cpu-name').textContent = cpuShort;
    document.getElementById('cpu-temp').textContent = `${snap.cpuTempC.toFixed(0)}°C`;
    updateRadialLoadRing('cpu-ring', 'cpu-load-ring', snap.cpuTotalLoadPercent, snap.cpuTempC);
    updateThermalCardState('card-cpu', 'cpu-state-chip', snap.cpuTempC);
    document.getElementById('cpu-power').textContent = `${snap.cpuPowerWatts.toFixed(0)} W`;
    document.getElementById('cpu-clock').textContent = `${(snap.cpuClockMhz / 1000).toFixed(2)} GHz`;
    document.getElementById('cpu-volt').textContent = `${snap.cpuVoltageV.toFixed(2)} V`;

    if (cpuHistory.length === 0) {
      for (let i = 0; i < 60; i++) cpuHistory.push(snap.cpuTempC + (Math.sin(i * 0.25) * 0.6));
    } else {
      cpuHistory.push(snap.cpuTempC);
      if (cpuHistory.length > 60) cpuHistory.shift();
    }
    const nominalLine = isLight ? '#0F172A' : '#FAFAFA';
    const nominalFill = isLight ? 'rgba(15, 23, 42, 0.08)' : 'rgba(250, 250, 250, 0.12)';
    const cpuStroke = snap.cpuTempC >= 82 ? '#F43F5E' : snap.cpuTempC >= 68 ? '#F59E0B' : nominalLine;
    const cpuFill = snap.cpuTempC >= 82 ? 'rgba(244, 63, 94, 0.18)' : snap.cpuTempC >= 68 ? 'rgba(245, 158, 11, 0.18)' : nominalFill;
    drawSmoothSparkline('cpu-sparkline', 'cpu-minmax', cpuHistory, cpuStroke, cpuFill, cpuHoverIdx);

    document.getElementById('gpu-name').textContent = gpuShort;
    document.getElementById('gpu-temp').textContent = `${snap.gpuTempC.toFixed(0)}°C`;
    updateRadialLoadRing('gpu-ring', 'gpu-load-ring', snap.gpuCoreLoadPercent, snap.gpuTempC);
    updateThermalCardState('card-gpu', 'gpu-state-chip', snap.gpuTempC);
    document.getElementById('gpu-power').textContent = `${snap.gpuPowerWatts.toFixed(0)} W`;
    document.getElementById('gpu-hotspot').textContent = `${snap.gpuHotspotTempC.toFixed(0)} °C`;
    document.getElementById('gpu-vram').textContent = `${(snap.gpuVramUsedMb / 1024).toFixed(1)} GB`;

    if (gpuHistory.length === 0) {
      for (let i = 0; i < 60; i++) gpuHistory.push(snap.gpuTempC + (Math.cos(i * 0.25) * 0.5));
    } else {
      gpuHistory.push(snap.gpuTempC);
      if (gpuHistory.length > 60) gpuHistory.shift();
    }
    const gpuStroke = snap.gpuTempC >= 82 ? '#F43F5E' : snap.gpuTempC >= 68 ? '#F59E0B' : '#10B981';
    const gpuFill = snap.gpuTempC >= 82 ? 'rgba(244, 63, 94, 0.18)' : snap.gpuTempC >= 68 ? 'rgba(245, 158, 11, 0.18)' : 'rgba(16, 185, 129, 0.14)';
    drawSmoothSparkline('gpu-sparkline', 'gpu-minmax', gpuHistory, gpuStroke, gpuFill, gpuHoverIdx);

    if (snap.liquidCooling) {
      const lq = snap.liquidCooling;
      const coolantC = Number(lq.coolantTempC ?? 31.8);
      const pumpRpmVal = Number(lq.pumpRpm ?? 2400);
      const deltaAmb = Number(lq.coolantDeltaOverAmbientC ?? lq.ambientDeltaC ?? Math.max(2.0, coolantC - 25.5));

      document.getElementById('liquid-ctrl-name').textContent = lq.controllerName || 'Aether HydroLoop AIO';
      document.getElementById('coolant-temp').textContent = `${coolantC.toFixed(1)}°C`;
      document.getElementById('pump-rpm').textContent = `${pumpRpmVal.toFixed(0)} RPM`;
      document.getElementById('coolant-delta').textContent = `+${deltaAmb.toFixed(1)}°C`;

      const satPct = Math.round(lq.thermalEquilibriumPct ?? Math.min(100, Math.max(12, ((coolantC - 24) / 22) * 100)));
      document.getElementById('water-sat-pct').textContent = `${satPct}%`;
      document.getElementById('bar-water-sat').style.width = `${satPct}%`;

      const waterChip = document.getElementById('water-state-chip');
      const airBtn = document.getElementById('btn-airlock-pulse');
      const airTxt = document.getElementById('airlock-btn-text');
      if (lq.antiAirlockPulseActive) {
        waterChip.textContent = t('water_purging');
        airBtn.classList.add('pulsing');
        if (airTxt) airTxt.textContent = t('btn_airlock_active');
      } else {
        waterChip.textContent = t('water_active');
        airBtn.classList.remove('pulsing');
        if (airTxt) airTxt.textContent = t('btn_airlock');
      }
    }

    const bn = snap.bottleneck;
    const code = bn.code || 'BALANCED';
    const titleFn = i18n[currentLang][`bn_${code}_title`];
    const sumFn = i18n[currentLang][`bn_${code}_sum`];

    document.getElementById('bn-verdict').textContent = titleFn || bn.primaryLimiter;
    document.getElementById('bn-summary').textContent =
      typeof sumFn === 'function'
        ? sumFn(bn.cpuFastestThreadPercent.toFixed(0), bn.gpuCoreLoadPercent.toFixed(0))
        : bn.technicalSummary;

    document.getElementById('bn-cpu-thread').textContent = `${bn.cpuFastestThreadPercent.toFixed(0)}%`;
    updateProgressBar('bar-cpu-thread', bn.cpuFastestThreadPercent);
    document.getElementById('bn-gpu-core').textContent = `${bn.gpuCoreLoadPercent.toFixed(0)}%`;
    updateProgressBar('bar-gpu-core', bn.gpuCoreLoadPercent);
    document.getElementById('bn-vram').textContent = `${bn.vramUsagePercent.toFixed(0)}%`;
    updateProgressBar('bar-vram', bn.vramUsagePercent);

    document.getElementById('mobo-name').textContent = moboShort;
    const primaryPwm = snap.fanChannels.length > 1 ? snap.fanChannels[1].targetPwmPercent : 0;
    document.getElementById('target-pwm-badge').textContent = `${primaryPwm.toFixed(0)}% PWM`;

    const fanList = document.getElementById('fan-channels-list');
    if (fanList.children.length !== snap.fanChannels.length) {
      fanList.innerHTML = snap.fanChannels.map((f, i) => `
        <div class="fan-item" id="fan-row-${i}">
          <div class="fan-item-top">
            <span class="fan-rotor-wrap">
              <svg class="rotor-svg" id="fan-rotor-${i}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="3"/>
                <path d="M12 2v7M12 15v7M2 12h7M15 12h7"/>
              </svg>
              <span id="fan-name-${i}">${f.name}</span>
            </span>
            <span class="fan-right-cluster">
              <span class="mono" id="fan-rpm-${i}">-- RPM · --%</span>
              <button class="btn-fan-test press-depth" id="fan-test-${i}" data-fan-id="${f.id}">${t('btn_test_fan')}</button>
            </span>
          </div>
          <div class="progress-rail"><div class="progress-fill" id="fan-bar-${i}"></div></div>
        </div>
      `).join('');

      fanList.querySelectorAll('.btn-fan-test').forEach((btn) => {
        btn.addEventListener('click', () => triggerFanIdentify(btn.getAttribute('data-fan-id')));
      });
    }

    snap.fanChannels.forEach((f, i) => {
      const spinSec = Math.max(0.22, Math.min(2.5, 1800 / Math.max(300, f.currentRpm))).toFixed(2);
      const rotorEl = document.getElementById(`fan-rotor-${i}`);
      const nameEl = document.getElementById(`fan-name-${i}`);
      const rpmEl = document.getElementById(`fan-rpm-${i}`);
      const barEl = document.getElementById(`fan-bar-${i}`);
      const testBtn = document.getElementById(`fan-test-${i}`);
      const isTesting = Boolean(f.controlSource && f.controlSource.includes('Identify'));

      if (rotorEl) rotorEl.style.animationDuration = `${spinSec}s`;
      if (nameEl) nameEl.textContent = f.name;
      if (rpmEl) rpmEl.textContent = `${Number(f.currentRpm || 0).toFixed(0)} RPM · ${Number(f.currentPwmPercent || 0).toFixed(0)}%`;
      if (barEl) barEl.style.width = `${Math.min(100, Number(f.currentPwmPercent || 0))}%`;
      if (testBtn) {
        testBtn.setAttribute('data-fan-id', f.id);
        testBtn.classList.toggle('testing', isTesting);
        testBtn.textContent = isTesting ? t('btn_testing_fan') : t('btn_test_fan');
      }
    });

    const predBadge = document.getElementById('predictive-status-badge');
    if (snap.activePredictiveRule) {
      predBadge.className = 'status-pill warning mono';
      predBadge.textContent = `${t('engaged_prefix')}${snap.activePredictiveRule.executableName}`;
    } else {
      predBadge.className = 'status-pill nominal mono';
      predBadge.textContent = t('standby_badge');
    }

    const ac = snap.acoustic;
    document.getElementById('acoustic-current-db').textContent = `${ac.estimatedFanDb.toFixed(1)} dBA`;
    document.getElementById('acoustic-cap-pwm').textContent = `${ac.computedMaxPwmCapPercent.toFixed(0)}%`;

    const calWrap = document.getElementById('calibration-progress-wrap');
    if (ac.isCalibrating) {
      calWrap.style.display = 'flex';
      document.getElementById('cal-pct').textContent = `${ac.calibrationProgressPercent}%`;
      document.getElementById('cal-bar').style.width = `${ac.calibrationProgressPercent}%`;
    } else {
      calWrap.style.display = 'none';
    }

    if (draggingNodeIdx < 0 && curveHoverTempC === null) renderFanCurve();
  }

  // Community Profiles & Modular Plugin API
  let cachedCommunityProfiles = [];
  let cachedPlugins = [];

  async function loadEcosystemData() {
    try {
      const [profRes, plugRes] = await Promise.all([
        fetch('/api/community/profiles'),
        fetch('/api/plugins')
      ]);
      if (profRes.ok) {
        cachedCommunityProfiles = await profRes.json();
        renderCommunityProfiles();
      }
      if (plugRes.ok) {
        cachedPlugins = await plugRes.json();
        renderPluginsList();
      }
    } catch {}
  }

  function renderCommunityProfiles() {
    const listEl = document.getElementById('community-profiles-list');
    if (!listEl) return;
    const isEn = currentLang === 'en';
    const activePreset = currentConfig?.activePreset || '';

    listEl.innerHTML = cachedCommunityProfiles.map((p) => {
      const isApplied = activePreset === p.name;
      const desc = isEn ? (p.descriptionEn || p.descriptionPt) : p.descriptionPt;
      return `
        <div class="eco-card">
          <div class="eco-card-top">
            <div>
              <span class="eco-title">${p.name}</span>
              <span class="eco-meta mono"> · @${p.author} · ★ ${p.stars}</span>
            </div>
            <button class="btn-fan-test press-depth ${isApplied ? 'testing' : ''}" data-prof-id="${p.id}">
              ${isApplied ? t('btn_applied') : t('btn_apply_prof')}
            </button>
          </div>
          <div class="eco-desc">${desc} <span class="mono text-muted">(${p.targetNoiseDb} dBA · ${p.category})</span></div>
        </div>
      `;
    }).join('');

    listEl.querySelectorAll('[data-prof-id]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-prof-id');
        try {
          const res = await fetch(`/api/community/profiles/apply/${encodeURIComponent(id)}`, { method: 'POST' });
          if (res.ok) {
            const data = await res.json();
            currentConfig = data.fanConfig;
            renderFanCurve();
            renderCommunityProfiles();
          }
        } catch {}
      });
    });
  }

  function renderPluginsList() {
    const listEl = document.getElementById('plugins-list');
    const badgeEl = document.getElementById('eco-count-badge');
    if (!listEl) return;
    const isEn = currentLang === 'en';
    const enabledCount = cachedPlugins.filter(p => p.enabled).length;
    if (badgeEl) {
      badgeEl.textContent = isEn ? `${enabledCount} Active` : `${enabledCount} Ativos`;
    }

    listEl.innerHTML = cachedPlugins.map((pl) => {
      const desc = isEn ? (pl.descriptionEn || pl.descriptionPt) : pl.descriptionPt;
      return `
        <div class="eco-card">
          <div class="eco-card-top">
            <div>
              <span class="eco-title">${pl.name}</span>
              <span class="eco-meta mono"> v${pl.version} · ${pl.statusText}</span>
            </div>
            <label class="fluent-switch">
              <input type="checkbox" data-plugin-id="${pl.id}" ${pl.enabled ? 'checked' : ''} />
              <span class="fluent-track"></span>
            </label>
          </div>
          <div class="eco-desc">${desc}</div>
        </div>
      `;
    }).join('');

    listEl.querySelectorAll('[data-plugin-id]').forEach((chk) => {
      chk.addEventListener('change', async () => {
        const id = chk.getAttribute('data-plugin-id');
        try {
          const res = await fetch(`/api/plugins/toggle/${encodeURIComponent(id)}`, { method: 'POST' });
          if (res.ok) {
            cachedPlugins = await res.json();
            renderPluginsList();
          }
        } catch {}
      });
    });
  }

  document.querySelectorAll('.btn-eco-sub').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.btn-eco-sub').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const mode = btn.getAttribute('data-eco');
      document.getElementById('community-profiles-list').style.display = mode === 'profiles' ? 'flex' : 'none';
      document.getElementById('plugins-list').style.display = mode === 'plugins' ? 'flex' : 'none';
    });
  });

  // 3D Interactive Digital Twin (Zero-Allocation Thermal Heatmap & Airflow Engine)
  const twinCanvas = document.getElementById('digital-twin-canvas');
  const twinHoverPill = document.getElementById('twin-hover-pill');
  const twinFpsBadge = document.getElementById('twin-fps-badge');
  let twinMode = 'heatmap';
  let twinYaw = -0.52;
  let twinPitch = 0.32;
  let twinDragging = false;
  let twinLastX = 0;
  let twinLastY = 0;
  let twinPointerX = -1;
  let twinPointerY = -1;
  let twinRotorAngleCpu = 0;
  let twinRotorAngleGpu = 0;
  let twinRotorAngleSys = 0;
  let twinFrameCount = 0;
  let twinLastFpsUpdate = performance.now();
  let twinLastFrameTime = performance.now();

  // Pre-allocated particle pools (zero GC allocations during animation)
  const airflowPool = Array.from({ length: 26 }, (_, i) => ({
    x: -95 + (i * 7.5) % 190,
    y: -55 + ((i * 23) % 110),
    z: -35 + ((i * 17) % 70),
    speed: 0.85 + (i % 5) * 0.14
  }));

  const coolantPool = Array.from({ length: 10 }, (_, i) => ({
    t: i / 10
  }));

  const chassisCorners = [
    [-105, -75, -52], [105, -75, -52], [105, 75, -52], [-105, 75, -52],
    [-105, -75,  52], [105, -75,  52], [105, 75,  52], [-105, 75,  52]
  ];
  const chassisEdges = [
    [0,1],[1,2],[2,3],[3,0],
    [4,5],[5,6],[6,7],[7,4],
    [0,4],[1,5],[2,6],[3,7]
  ];

  document.querySelectorAll('.btn-twin-mode').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.btn-twin-mode').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      twinMode = btn.getAttribute('data-twin-mode') || 'heatmap';
    });
  });

  if (twinCanvas) {
    twinCanvas.addEventListener('pointerdown', (e) => {
      twinDragging = true;
      twinLastX = e.clientX;
      twinLastY = e.clientY;
      twinCanvas.setPointerCapture(e.pointerId);
    });

    twinCanvas.addEventListener('pointermove', (e) => {
      const rect = twinCanvas.getBoundingClientRect();
      twinPointerX = e.clientX - rect.left;
      twinPointerY = e.clientY - rect.top;
      if (twinDragging) {
        const dx = e.clientX - twinLastX;
        const dy = e.clientY - twinLastY;
        twinLastX = e.clientX;
        twinLastY = e.clientY;
        twinYaw += dx * 0.0085;
        twinPitch = Math.max(-0.65, Math.min(0.85, twinPitch + dy * 0.0075));
      }
    });

    twinCanvas.addEventListener('pointerup', () => { twinDragging = false; });
    twinCanvas.addEventListener('pointerleave', () => {
      twinDragging = false;
      twinPointerX = -1;
      twinPointerY = -1;
      if (twinHoverPill) twinHoverPill.style.display = 'none';
    });
  }

  function tempToThermalRgb(tempC) {
    const t = Math.max(25, Math.min(92, tempC));
    if (t <= 48) {
      const r = (t - 25) / 23;
      return [
        Math.round(6 + r * (16 - 6)),
        Math.round(182 + r * (185 - 182)),
        Math.round(212 + r * (129 - 212))
      ];
    } else if (t <= 68) {
      const r = (t - 48) / 20;
      return [
        Math.round(16 + r * (245 - 16)),
        Math.round(185 + r * (158 - 185)),
        Math.round(129 + r * (11 - 129))
      ];
    } else {
      const r = (t - 68) / 24;
      return [
        Math.round(245 + r * (244 - 245)),
        Math.round(158 + r * (63 - 158)),
        Math.round(11 + r * (94 - 11))
      ];
    }
  }

  function project3D(x, y, z, cx, cy, cosY, sinY, cosP, sinP) {
    const rx = x * cosY - z * sinY;
    const rz1 = x * sinY + z * cosY;
    const ry = y * cosP - rz1 * sinP;
    const rz = y * sinP + rz1 * cosP;
    const fov = 440;
    const scale = fov / Math.max(120, fov + rz + 210);
    return {
      sx: cx + rx * scale,
      sy: cy + ry * scale,
      scale,
      depth: rz
    };
  }

  function draw3DFanRotor(ctx, x, y, z, radius, angle, bladeColor, ringColor, cx, cy, cosY, sinY, cosP, sinP, plane) {
    const center = project3D(x, y, z, cx, cy, cosY, sinY, cosP, sinP);
    ctx.strokeStyle = ringColor;
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    const segs = 20;
    for (let i = 0; i <= segs; i++) {
      const a = (i / segs) * Math.PI * 2;
      const dx = Math.cos(a) * radius;
      const dy = Math.sin(a) * radius;
      const pt = plane === 'yz'
        ? project3D(x, y + dy, z + dx, cx, cy, cosY, sinY, cosP, sinP)
        : plane === 'xz'
          ? project3D(x + dx, y, z + dy, cx, cy, cosY, sinY, cosP, sinP)
          : project3D(x + dx, y + dy, z, cx, cy, cosY, sinY, cosP, sinP);
      if (i === 0) ctx.moveTo(pt.sx, pt.sy);
      else ctx.lineTo(pt.sx, pt.sy);
    }
    ctx.stroke();

    const blades = 7;
    ctx.strokeStyle = bladeColor;
    ctx.lineWidth = 1.8;
    for (let b = 0; b < blades; b++) {
      const ba = angle + (b * Math.PI * 2) / blades;
      const dx = Math.cos(ba) * (radius * 0.86);
      const dy = Math.sin(ba) * (radius * 0.86);
      const tip = plane === 'yz'
        ? project3D(x, y + dy, z + dx, cx, cy, cosY, sinY, cosP, sinP)
        : plane === 'xz'
          ? project3D(x + dx, y, z + dy, cx, cy, cosY, sinY, cosP, sinP)
          : project3D(x + dx, y + dy, z, cx, cy, cosY, sinY, cosP, sinP);
      ctx.beginPath();
      ctx.moveTo(center.sx, center.sy);
      ctx.lineTo(tip.sx, tip.sy);
      ctx.stroke();
    }

    ctx.fillStyle = bladeColor;
    ctx.beginPath();
    ctx.arc(center.sx, center.sy, 3.2 * center.scale, 0, Math.PI * 2);
    ctx.fill();
    return center;
  }

  function stepDigitalTwin(now) {
    requestAnimationFrame(stepDigitalTwin);

    const twinPane = document.getElementById('tab-twin');
    if (!twinCanvas || !twinPane || twinPane.style.display === 'none' || document.hidden) {
      twinLastFrameTime = now;
      return;
    }

    const dt = Math.min(0.05, Math.max(0.001, (now - twinLastFrameTime) / 1000));
    twinLastFrameTime = now;
    twinFrameCount++;

    if (now - twinLastFpsUpdate >= 500) {
      const fps = Math.min(60, Math.round((twinFrameCount * 1000) / (now - twinLastFpsUpdate)));
      if (twinFpsBadge) twinFpsBadge.textContent = `${fps} FPS · 3D`;
      twinFrameCount = 0;
      twinLastFpsUpdate = now;
    }

    if (!twinDragging) {
      twinYaw = -0.52 + Math.sin(now * 0.00055) * 0.16;
    }

    const dpr = window.devicePixelRatio || 1;
    const cssW = twinCanvas.clientWidth || 440;
    const cssH = twinCanvas.clientHeight || 235;
    if (twinCanvas.width !== Math.round(cssW * dpr) || twinCanvas.height !== Math.round(cssH * dpr)) {
      twinCanvas.width = Math.round(cssW * dpr);
      twinCanvas.height = Math.round(cssH * dpr);
    }

    const ctx = twinCanvas.getContext('2d');
    ctx.save();
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, cssW, cssH);

    const isLight = currentTheme === 'light';
    const cx = cssW * 0.5;
    const cy = cssH * 0.52;
    const cosY = Math.cos(twinYaw), sinY = Math.sin(twinYaw);
    const cosP = Math.cos(twinPitch), sinP = Math.sin(twinPitch);

    const cpuTemp = latestTelemetry?.cpuTempC ?? 52;
    const gpuTemp = latestTelemetry?.gpuTempC ?? 46;
    const coolantTemp = latestTelemetry?.liquidCooling?.coolantTempC ?? 31.6;
    const pumpRpm = latestTelemetry?.liquidCooling?.pumpRpm ?? 2600;
    const cpuRpm = latestTelemetry?.fanChannels?.[1]?.currentRpm ?? 1180;
    const sysRpm = latestTelemetry?.fanChannels?.[2]?.currentRpm ?? 980;
    const gpuRpm = latestTelemetry?.fanChannels?.[3]?.currentRpm ?? 1320;

    twinRotorAngleCpu += (cpuRpm / 60) * dt * 0.45;
    twinRotorAngleSys += (sysRpm / 60) * dt * 0.45;
    twinRotorAngleGpu += (gpuRpm / 60) * dt * 0.45;

    const [cpuR, cpuG, cpuB] = tempToThermalRgb(cpuTemp);
    const [gpuR, gpuG, gpuB] = tempToThermalRgb(gpuTemp);
    const [liqR, liqG, liqB] = tempToThermalRgb(coolantTemp + 6);

    const wireStroke = isLight ? 'rgba(15, 23, 42, 0.18)' : 'rgba(255, 255, 255, 0.16)';
    const projCorners = chassisCorners.map(([x, y, z]) => project3D(x, y, z, cx, cy, cosY, sinY, cosP, sinP));

    // 1. 3D Chassis Frame
    ctx.strokeStyle = wireStroke;
    ctx.lineWidth = 1.1;
    chassisEdges.forEach(([i, j]) => {
      ctx.beginPath();
      ctx.moveTo(projCorners[i].sx, projCorners[i].sy);
      ctx.lineTo(projCorners[j].sx, projCorners[j].sy);
      ctx.stroke();
    });

    // 2. 3D CPU Thermal Zone & Waterblock
    const cpuPos = project3D(-22, -22, -18, cx, cy, cosY, sinY, cosP, sinP);
    if (twinMode === 'heatmap') {
      const cpuGrad = ctx.createRadialGradient(cpuPos.sx, cpuPos.sy, 2, cpuPos.sx, cpuPos.sy, 46 * cpuPos.scale);
      cpuGrad.addColorStop(0, `rgba(${cpuR}, ${cpuG}, ${cpuB}, 0.55)`);
      cpuGrad.addColorStop(1, `rgba(${cpuR}, ${cpuG}, ${cpuB}, 0.0)`);
      ctx.fillStyle = cpuGrad;
      ctx.beginPath();
      ctx.arc(cpuPos.sx, cpuPos.sy, 46 * cpuPos.scale, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.strokeStyle = `rgb(${cpuR}, ${cpuG}, ${cpuB})`;
    ctx.fillStyle = isLight ? 'rgba(255,255,255,0.85)' : 'rgba(16,16,20,0.88)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(cpuPos.sx, cpuPos.sy, 16 * cpuPos.scale, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // 3. 3D AIO Liquid Tubes & Flowing Coolant Droplets (CPU Block -> Top Radiator)
    const radPortA = project3D(-35, -68, -5, cx, cy, cosY, sinY, cosP, sinP);
    const radPortB = project3D(25, -68, -5, cx, cy, cosY, sinY, cosP, sinP);
    ctx.strokeStyle = `rgba(${liqR}, ${liqG}, ${liqB}, 0.65)`;
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(cpuPos.sx, cpuPos.sy);
    ctx.quadraticCurveTo(cpuPos.sx + 22, cpuPos.sy - 18, radPortB.sx, radPortB.sy);
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(cpuPos.sx - 6, cpuPos.sy - 4);
    ctx.quadraticCurveTo(cpuPos.sx - 24, cpuPos.sy - 26, radPortA.sx, radPortA.sy);
    ctx.stroke();

    const pumpSpeedFactor = (pumpRpm / 2400) * dt * 0.55;
    ctx.fillStyle = `rgb(${liqR}, ${liqG}, ${liqB})`;
    for (let i = 0; i < coolantPool.length; i++) {
      coolantPool[i].t = (coolantPool[i].t + pumpSpeedFactor) % 1;
      const u = coolantPool[i].t;
      const inv = 1 - u;
      const dx = inv * inv * cpuPos.sx + 2 * inv * u * (cpuPos.sx + 22) + u * u * radPortB.sx;
      const dy = inv * inv * cpuPos.sy + 2 * inv * u * (cpuPos.sy - 18) + u * u * radPortB.sy;
      ctx.beginPath();
      ctx.arc(dx, dy, 2.2, 0, Math.PI * 2);
      ctx.fill();
    }

    // 4. 3D GPU Card & Dual-Axial Rotors
    const gpuCenter = project3D(-10, 26, 8, cx, cy, cosY, sinY, cosP, sinP);
    if (twinMode === 'heatmap') {
      const gpuGrad = ctx.createRadialGradient(gpuCenter.sx, gpuCenter.sy, 4, gpuCenter.sx, gpuCenter.sy, 64 * gpuCenter.scale);
      gpuGrad.addColorStop(0, `rgba(${gpuR}, ${gpuG}, ${gpuB}, 0.52)`);
      gpuGrad.addColorStop(1, `rgba(${gpuR}, ${gpuG}, ${gpuB}, 0.0)`);
      ctx.fillStyle = gpuGrad;
      ctx.beginPath();
      ctx.arc(gpuCenter.sx, gpuCenter.sy, 64 * gpuCenter.scale, 0, Math.PI * 2);
      ctx.fill();
    }

    const gpuBox = [
      project3D(-72, 14, -18, cx, cy, cosY, sinY, cosP, sinP),
      project3D( 48, 14, -18, cx, cy, cosY, sinY, cosP, sinP),
      project3D( 48, 36,  28, cx, cy, cosY, sinY, cosP, sinP),
      project3D(-72, 36,  28, cx, cy, cosY, sinY, cosP, sinP)
    ];
    ctx.strokeStyle = `rgb(${gpuR}, ${gpuG}, ${gpuB})`;
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(gpuBox[0].sx, gpuBox[0].sy);
    gpuBox.forEach(p => ctx.lineTo(p.sx, p.sy));
    ctx.closePath();
    ctx.stroke();

    draw3DFanRotor(ctx, -38, 28, 12, 19, twinRotorAngleGpu, `rgb(${gpuR}, ${gpuG}, ${gpuB})`, wireStroke, cx, cy, cosY, sinY, cosP, sinP, 'xy');
    draw3DFanRotor(ctx,  14, 28, 12, 19, -twinRotorAngleGpu, `rgb(${gpuR}, ${gpuG}, ${gpuB})`, wireStroke, cx, cy, cosY, sinY, cosP, sinP, 'xy');

    // 5. Top 240mm AIO Radiator Fans & Front Intake Fans
    const topFan1 = draw3DFanRotor(ctx, -35, -72, 0, 22, twinRotorAngleCpu, '#06B6D4', wireStroke, cx, cy, cosY, sinY, cosP, sinP, 'xz');
    draw3DFanRotor(ctx,  25, -72, 0, 22, twinRotorAngleCpu, '#06B6D4', wireStroke, cx, cy, cosY, sinY, cosP, sinP, 'xz');
    const frontFan1 = draw3DFanRotor(ctx, 102, -26, 0, 24, twinRotorAngleSys, '#10B981', wireStroke, cx, cy, cosY, sinY, cosP, sinP, 'yz');
    draw3DFanRotor(ctx, 102,  28, 0, 24, twinRotorAngleSys, '#10B981', wireStroke, cx, cy, cosY, sinY, cosP, sinP, 'yz');

    // 6. Volumetric 3D Airflow Streamlines
    if (twinMode !== 'wireframe') {
      const flowSpeed = (sysRpm / 1000) * 65 * dt;
      for (let i = 0; i < airflowPool.length; i++) {
        const p = airflowPool[i];
        p.x -= flowSpeed * p.speed;
        p.y -= flowSpeed * 0.28;
        if (p.x < -98 || p.y < -70) {
          p.x = 98;
          p.y = -45 + ((i * 19) % 95);
        }
        const pt = project3D(p.x, p.y, p.z, cx, cy, cosY, sinY, cosP, sinP);
        const warmRatio = Math.max(0, Math.min(1, (98 - p.x) / 196));
        const pr = Math.round(6 + warmRatio * (cpuR - 6));
        const pg = Math.round(182 + warmRatio * (cpuG - 182));
        const pb = Math.round(212 + warmRatio * (cpuB - 212));
        ctx.fillStyle = `rgba(${pr}, ${pg}, ${pb}, ${twinMode === 'airflow' ? 0.85 : 0.45})`;
        ctx.beginPath();
        ctx.arc(pt.sx, pt.sy, twinMode === 'airflow' ? 2.4 : 1.7, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // 7. Interactive 3D Component Raycast Hover
    if (twinPointerX >= 0 && twinHoverPill) {
      const hits = [
        { name: 'CPU Block', sx: cpuPos.sx, sy: cpuPos.sy, r: 26, text: `CPU: ${cpuTemp.toFixed(0)}°C · ${(latestTelemetry?.cpuPowerWatts ?? 45).toFixed(0)}W` },
        { name: 'GPU Dual-Axial', sx: gpuCenter.sx, sy: gpuCenter.sy, r: 36, text: `GPU: ${gpuTemp.toFixed(0)}°C · ${gpuRpm.toFixed(0)} RPM` },
        { name: 'AIO 240mm Radiator', sx: topFan1.sx, sy: topFan1.sy, r: 30, text: `AIO: ${coolantTemp.toFixed(1)}°C · ${pumpRpm.toFixed(0)} RPM` },
        { name: 'Front Intake', sx: frontFan1.sx, sy: frontFan1.sy, r: 30, text: `Intake: ${sysRpm.toFixed(0)} RPM` }
      ];
      const matched = hits.find(h => Math.hypot(twinPointerX - h.sx, twinPointerY - h.sy) <= h.r);
      if (matched) {
        twinHoverPill.style.display = 'block';
        twinHoverPill.textContent = matched.text;
      } else {
        twinHoverPill.style.display = 'none';
      }
    }

    ctx.restore();
  }

  requestAnimationFrame(stepDigitalTwin);

  let activeWs = null;

  function startHttpPollingFallback() {
    if (pollingTimer) return;
    pollingTimer = setInterval(async () => {
      try {
        const res = await fetch('/api/telemetry');
        if (res.ok) updateDashboard(await res.json());
      } catch {}
    }, 280);
  }

  function stopHttpPollingFallback() {
    if (pollingTimer) {
      clearInterval(pollingTimer);
      pollingTimer = null;
    }
  }

  function connectWebSocket() {
    try {
      const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
      activeWs = new WebSocket(`${proto}//${location.host}/ws/telemetry`);

      activeWs.addEventListener('open', () => {
        stopHttpPollingFallback();
      });

      activeWs.addEventListener('message', (event) => {
        try {
          const snap = JSON.parse(event.data);
          updateDashboard(snap);
        } catch {}
      });

      activeWs.addEventListener('close', () => {
        startHttpPollingFallback();
        setTimeout(connectWebSocket, 3000);
      });

      activeWs.addEventListener('error', () => {
        startHttpPollingFallback();
      });
    } catch {
      startHttpPollingFallback();
    }
  }

  applyTheme(currentTheme);
  applyLanguage(currentLang);
  startHttpPollingFallback();
  connectWebSocket();
})();
