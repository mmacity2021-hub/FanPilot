const { invoke } = window.__TAURI__.core;

async function log(level, module, message) {
    console.log(`[${level}] [${module}] ${message}`);
    try { await invoke('log_event', { level, module, message: String(message) }); } catch(e) { console.error("Log fail", e); }
}

window.addEventListener('error', (e) => log('ERROR', 'Frontend', e.message));
window.addEventListener('unhandledrejection', (e) => log('ERROR', 'Frontend-Promise', e.reason));

let previousTab = 'monitor';
let isManualActive = false;

document.addEventListener('DOMContentLoaded', async () => {
    log('INFO', 'App', 'DOM chargé');

    // ---- Installation polkit ----
    try {
        const ok = await invoke('is_polkit_installed');
        const banner = document.getElementById('polkit-banner');
        if (banner && ok) banner.classList.add('hidden');
        log('INFO', 'Polkit', `Installé: ${ok}`);
    } catch(e) { log('ERROR', 'Polkit', `${e}`); }

    const btnInstallPolkit = document.getElementById('btn-install-polkit');
    if (btnInstallPolkit) {
        btnInstallPolkit.addEventListener('click', async () => {
            if (!confirm('Installer les permissions système ?\n\nLe mot de passe sera demandé UNE SEULE FOIS.\nEnsuite, plus aucune demande n\'apparaîtra.')) return;
            log('INFO', 'Polkit', 'Installation...');
            try {
                await invoke('install_polkit');
                document.getElementById('polkit-banner').classList.add('hidden');
                alert('✓ Permissions installées. Plus aucun mot de passe ne sera demandé.');
                log('INFO', 'Polkit', 'Installation réussie');
            } catch(e) {
                alert(`Erreur: ${e}`);
                log('ERROR', 'Polkit', `Install: ${e}`);
            }
        });
    }

    // Prérequis mbpfan
    try {
        const installed = await invoke('is_mbpfan_installed');
        const badge = document.getElementById('mbpfan-status');
        if (badge) {
            if (installed) { badge.textContent = '✅ Installé'; badge.className = 'badge ok'; }
            else { badge.textContent = '❌ Non installé'; badge.className = 'badge error'; log('WARN', 'App', 'mbpfan manquant'); }
        }
    } catch(e) { log('ERROR', 'App', `${e}`); }

    const btnCopy = document.getElementById('btn-copy-cmd');
    if (btnCopy) {
        btnCopy.addEventListener('click', () => {
            const cmd = document.getElementById('install-cmd').innerText;
            navigator.clipboard.writeText(cmd).then(() => {
                btnCopy.innerText = '✅ Copié !';
                setTimeout(() => btnCopy.innerText = '📋 Copier', 2000);
            });
        });
    }

    // ---- Navigation avec auto-restauration du contrôle ----
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
            const newTab = btn.dataset.tab;
            
            // Si on quitte "Contrôle manuel" ET que le mode manuel était actif
            // → on redémarre mbpfan automatiquement
            if (previousTab === 'manual' && newTab !== 'manual' && isManualActive) {
                log('INFO', 'AutoRestore', 'Sortie de Contrôle manuel → restauration automatique');
                try {
                    await invoke('restart_mbpfan');
                    isManualActive = false;
                    await refreshAll();
                    await loadConfig();
                    log('INFO', 'AutoRestore', 'mbpfan redémarré automatiquement');
                } catch(e) {
                    log('ERROR', 'AutoRestore', `${e}`);
                }
            }
            
            document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            btn.classList.add('active');
            const target = document.getElementById(`tab-${newTab}`);
            if (target) target.classList.add('active');
            
            previousTab = newTab;
            log('INFO', 'UI', `Onglet: ${newTab}`);
        });
    });

    // ---- Clic sur un profil ----
    // Clic sur un profil = application IMMÉDIATE (comme le tray)
    // ============ PROFILS PERSONNALISABLES ============
    async function loadProfiles() {
        try {
            const profiles = await invoke('get_profiles');
            document.querySelectorAll('.profile-card').forEach(card => {
                const name = card.dataset.profile;
                if (profiles[name]) {
                    const low = profiles[name].low;
                    const high = profiles[name].high;
                    const max = profiles[name].max;
                    card.dataset.low = low;
                    card.dataset.high = high;
                    card.dataset.max = max;
                    const p = card.querySelector('.profile-values');
                    if (p) p.textContent = `low ${low} / high ${high} / max ${max}`;
                }
            });
            log('INFO', 'Profiles', 'Profils chargés depuis JSON');
        } catch(e) {
            log('ERROR', 'Profiles', `Chargement: ${e}`);
        }
    }

    // Écoute des modifications des champs → met à jour en temps réel le profil appliqué
    ['cfg-low-temp', 'cfg-high-temp', 'cfg-max-temp'].forEach(id => {
        const el = document.getElementById(id);
        if (!el) return;
        el.addEventListener('input', () => {
            const appliedCard = document.querySelector('.profile-card.applied');
            if (!appliedCard) return;
            const low = parseInt(document.getElementById('cfg-low-temp').value);
            const high = parseInt(document.getElementById('cfg-high-temp').value);
            const max = parseInt(document.getElementById('cfg-max-temp').value);
            if (isNaN(low) || isNaN(high) || isNaN(max)) return;
            if (!(low < high && high < max)) return;
            appliedCard.dataset.low = low;
            appliedCard.dataset.high = high;
            appliedCard.dataset.max = max;
            const p = appliedCard.querySelector('.profile-values');
            if (p) p.textContent = `low ${low} / high ${high} / max ${max}`;
            log('INFO', 'Profiles', `Édition en cours du profil '${appliedCard.dataset.profile}' : ${low}/${high}/${max}`);
        });
    });

    document.querySelectorAll('.profile-card').forEach(card => {
        card.addEventListener('click', async () => {
            const low = parseInt(card.dataset.low);
            const high = parseInt(card.dataset.high);
            const max = parseInt(card.dataset.max);

            // Pré-remplir les champs pour cohérence visuelle
            document.getElementById('cfg-low-temp').value = low;
            document.getElementById('cfg-high-temp').value = high;
            document.getElementById('cfg-max-temp').value = max;

            log('INFO', 'Profile', `Application immédiate: ${card.dataset.profile} (${low}/${high}/${max})`);

            try {
                await invoke('save_mbpfan_config', { low, high, max });
                await invoke('restart_mbpfan');
                log('INFO', 'Profile', `Profil '${card.dataset.profile}' appliqué et mbpfan redémarré`);
                await loadConfig();
                await refreshAll();
            } catch(e) {
                alert(`Erreur lors de l'application : ${e}`);
                log('ERROR', 'Profile', `${e}`);
            }
        });
    });

    // ---- Application courbe ----
    const btnSave = document.getElementById('btn-save-config');
    if (btnSave) {
        btnSave.addEventListener('click', async () => {
            const low = parseInt(document.getElementById('cfg-low-temp').value);
            const high = parseInt(document.getElementById('cfg-high-temp').value);
            const max = parseInt(document.getElementById('cfg-max-temp').value);

            log('INFO', 'Config', `Sauvegarde: ${low}/${high}/${max}`);

            if (!(low < high && high < max)) {
                alert('Erreur : low_temp < high_temp < max_temp requis');
                return;
            }

            try {
                await invoke('save_mbpfan_config', { low, high, max });
                await invoke('restart_mbpfan');
                isManualActive = false;
                log('INFO', 'Config', 'Appliqué avec succès');
                alert('✓ Configuration appliquée et mbpfan redémarré');
                await loadConfig();
                await refreshAll();
            } catch(e) {
                alert(`Erreur: ${e}`);
                log('ERROR', 'Config', `${e}`);
            }
        });
    }

    // ---- Rendre contrôle manuellement (bouton dans l'onglet manuel) ----
    const btnRestoreAuto = document.getElementById('btn-restore-auto');
    if (btnRestoreAuto) {
        btnRestoreAuto.addEventListener('click', async () => {
            if (!confirm('Rendre le Contrôle à FanPilot ?')) return;
            try {
                await invoke('restart_mbpfan');
                isManualActive = false;
                alert('✓ mbpfan redémarré, contrôle automatique rétabli');
                await loadConfig();
                await refreshAll();
            } catch(e) { alert(`Erreur: ${e}`); }
        });
    }

    const btnReload = document.getElementById('btn-reload-config');
    if (btnReload) btnReload.addEventListener('click', loadConfig);

    // Initialisation

    // ---- Écoute des événements venant du Tray ----
    const { listen } = window.__TAURI__.event;
    listen('profile-changed', (event) => {
        log('INFO', 'Tray', `Profil changé via barre système : ${event.payload}`);
        loadConfig();
        refreshAll();
    });

    await loadProfiles();
    await loadProfiles();
    await loadProfiles();
    await refreshAll();
    await loadConfig();
    setInterval(refreshAll, 1000);
});

async function updateFans() {
  try {
    const fans = await invoke('get_fans');
    fans.forEach((fan, i) => {
      const idx = i + 1;
      const elRpm = document.getElementById(`fan${idx}-rpm`);
      if (elRpm) elRpm.textContent = `${fan.rpm} RPM`;
      const elMin = document.getElementById(`fan${idx}-min`);
      if (elMin) elMin.textContent = `${fan.min} RPM`;
      const elMax = document.getElementById(`fan${idx}-max`);
      if (elMax) elMax.textContent = `${fan.max} RPM`;
      const pct = fan.max > fan.min ? ((fan.rpm - fan.min) / (fan.max - fan.min)) * 100 : 0;
      const elBar = document.getElementById(`fan${idx}-bar`);
      if (elBar) elBar.style.width = `${Math.max(0, Math.min(100, pct))}%`;
    });
  } catch (e) { log('ERROR', 'SMC', `Fans: ${e}`); }
}

async function updateTemps() {
  try {
    const temps = await invoke('get_temps');
    Object.entries(temps).forEach(([key, val]) => {
      const el = document.getElementById(`temp-${key.toLowerCase()}`);
      if (el) el.textContent = `${val.toFixed(1)} °C`;
    });
  } catch (e) { log('ERROR', 'SMC', `Temps: ${e}`); }
}

async function checkDaemon() {
  try {
    const running = await invoke('is_mbpfan_running');
    const dot = document.getElementById('daemon-status');
    const text = document.getElementById('daemon-text');
    if (dot && text) {
        dot.className = `dot ${running ? 'running' : 'stopped'}`;
        text.textContent = running ? 'mbpfan : actif' : 'mbpfan : arrêté';
    }
    if (running) isManualActive = false;
  } catch (e) {
    const text = document.getElementById('daemon-text');
    if (text) text.textContent = 'mbpfan : inconnu';
  }
}

async function loadConfig() {
  try {
    const cfg = await invoke('get_mbpfan_config');
    const elLow = document.getElementById('cfg-low-temp');
    if (elLow) elLow.value = cfg.low_temp;
    const elHigh = document.getElementById('cfg-high-temp');
    if (elHigh) elHigh.value = cfg.high_temp;
    const elMax = document.getElementById('cfg-max-temp');
    if (elMax) elMax.value = cfg.max_temp;
    const raw = document.getElementById('config-raw');
    if (raw) raw.textContent = cfg.raw;

    // Différencier "sélectionné" (bordure verte) de "actif" (coche ✓)
    let matchedProfile = null;
    // ============ PROFILS PERSONNALISABLES ============
    async function loadProfiles() {
        try {
            const profiles = await invoke('get_profiles');
            document.querySelectorAll('.profile-card').forEach(card => {
                const name = card.dataset.profile;
                if (profiles[name]) {
                    const low = profiles[name].low;
                    const high = profiles[name].high;
                    const max = profiles[name].max;
                    card.dataset.low = low;
                    card.dataset.high = high;
                    card.dataset.max = max;
                    const p = card.querySelector('.profile-values');
                    if (p) p.textContent = `low ${low} / high ${high} / max ${max}`;
                }
            });
            log('INFO', 'Profiles', 'Profils chargés depuis JSON');
        } catch(e) {
            log('ERROR', 'Profiles', `Chargement: ${e}`);
        }
    }

    // Écoute des modifications des champs → met à jour en temps réel le profil appliqué
    ['cfg-low-temp', 'cfg-high-temp', 'cfg-max-temp'].forEach(id => {
        const el = document.getElementById(id);
        if (!el) return;
        el.addEventListener('input', () => {
            const appliedCard = document.querySelector('.profile-card.applied');
            if (!appliedCard) return;
            const low = parseInt(document.getElementById('cfg-low-temp').value);
            const high = parseInt(document.getElementById('cfg-high-temp').value);
            const max = parseInt(document.getElementById('cfg-max-temp').value);
            if (isNaN(low) || isNaN(high) || isNaN(max)) return;
            if (!(low < high && high < max)) return;
            appliedCard.dataset.low = low;
            appliedCard.dataset.high = high;
            appliedCard.dataset.max = max;
            const p = appliedCard.querySelector('.profile-values');
            if (p) p.textContent = `low ${low} / high ${high} / max ${max}`;
            log('INFO', 'Profiles', `Édition en cours du profil '${appliedCard.dataset.profile}' : ${low}/${high}/${max}`);
        });
    });

    document.querySelectorAll('.profile-card').forEach(card => {
        const low = parseInt(card.dataset.low);
        const high = parseInt(card.dataset.high);
        const max = parseInt(card.dataset.max);
        const isActive = (low === cfg.low_temp && high === cfg.high_temp && max === cfg.max_temp);

        if (isActive) {
            card.classList.add('applied');
            card.classList.remove('selected');
            matchedProfile = card.dataset.profile;
        } else {
            card.classList.remove('applied');
            card.classList.remove('active');
        }
    });

    // Sync tray checkmarks
    if (matchedProfile) {
        invoke('update_tray_checkmarks', { profile: matchedProfile }).catch(() => {});
    } else {
        invoke('update_tray_checkmarks', { profile: 'custom' }).catch(() => {});
    }

    log('INFO', 'Config', 'Chargée');
  } catch (e) {
    const raw = document.getElementById('config-raw');
    if (raw) raw.textContent = `Erreur: ${e}`;
    log('ERROR', 'Config', `${e}`);
  }
}

async function refreshAll() { await updateFans(); await updateTemps(); await checkDaemon(); }

// ---- Contrôle manuel ----
window.setManual = async (fanId) => {
    const rpm = parseInt(document.getElementById(`manual-fan${fanId}`).value);
    log('INFO', 'Control', `Fan ${fanId} → ${rpm} RPM`);
    try {
        await invoke('set_fan_speed', { fanId, rpm });
        isManualActive = true;
        alert(`✓ Ventilateur ${fanId} réglé à ${rpm} RPM\n\n⚠️ Mode manuel actif. Quittez cet onglet pour restaurer le contrôle automatique.`);
        await refreshAll();
    } catch(e) {
        alert(`Erreur: ${e}`);
        log('ERROR', 'Control', `${e}`);
    }
};
