/* Earprint Site Core Controller
 * Theme toggling (dark-mode-toggle compliant), bilingual i18n wiring, accessible tabs,
 * WCAG video pause/play + lazy-video IO fallback, PSA Ear Grade calculator, 41-Icon Studio,
 * scroll-reveal fallback, and dynamic interactive lab initialization.
 */

import { getLang, initI18n, t } from './i18n.js';

const THEME_STORAGE_KEY = 'earprint.theme';
const DARK_MQ = window.matchMedia('(prefers-color-scheme: dark)');
const REDUCED_MOTION_MQ = window.matchMedia('(prefers-reduced-motion: reduce)');

function getSystemTheme() {
  return DARK_MQ.matches ? 'dark' : 'light';
}

function getStoredPreference() {
  try {
    const val = localStorage.getItem(THEME_STORAGE_KEY);
    if (val === 'light' || val === 'dark') return val;
  } catch {
    // Ignore storage access errors
  }
  return null;
}

function getThemeState() {
  const stored = getStoredPreference();
  const preference = stored ?? 'system';
  const resolved = stored ?? getSystemTheme();
  return { preference, resolved, theme: resolved };
}

function syncThemeToDom({ emit = true } = {}) {
  const state = getThemeState();
  const meta = document.querySelector('meta[name="color-scheme"]');
  if (meta) {
    meta.content = state.preference === 'system' ? 'light dark' : state.preference;
  }
  document.documentElement.dataset.resolvedTheme = state.resolved;
  document.documentElement.dataset.themePreference = state.preference;

  const toggleBtn = document.querySelector('[data-theme-toggle]');
  if (toggleBtn) {
    toggleBtn.setAttribute('aria-pressed', String(state.resolved === 'dark'));
  }

  if (emit) {
    document.dispatchEvent(
      new CustomEvent('earprint:themechange', {
        bubbles: true,
        detail: {
          theme: state.resolved,
          preference: state.preference,
          resolved: state.resolved
        }
      })
    );
  }
  return state;
}

function initThemeController() {
  syncThemeToDom({ emit: false });

  document.addEventListener('click', (event) => {
    const btn = event.target.closest('[data-theme-toggle]');
    if (!btn) return;
    const { resolved } = getThemeState();
    const target = resolved === 'dark' ? 'light' : 'dark';
    try {
      if (target === getSystemTheme()) {
        localStorage.removeItem(THEME_STORAGE_KEY);
      } else {
        localStorage.setItem(THEME_STORAGE_KEY, target);
      }
    } catch {
      // Fall back to transient meta update when storage is disabled
      const meta = document.querySelector('meta[name="color-scheme"]');
      if (meta) meta.content = target;
    }
    syncThemeToDom({ emit: true });
  });

  // Never erase a stored preference when system matches it; only re-resolve system state
  DARK_MQ.addEventListener('change', () => {
    syncThemeToDom({ emit: true });
  });

  window.addEventListener('storage', (event) => {
    if (event.key === THEME_STORAGE_KEY) {
      syncThemeToDom({ emit: true });
    }
  });
}

/* Accessible Single-Row Tabs (roving tabindex + beforematch + hidden="until-found") */
function initAccessibleTabs() {
  for (const tablist of document.querySelectorAll('[data-tabs-root] [role="tablist"]')) {
    const root = tablist.closest('[data-tabs-root]');
    const tabs = Array.from(tablist.querySelectorAll('[role="tab"]'));
    const panels = tabs.map((tab) => root?.querySelector(`[role="tabpanel"][aria-labelledby="${CSS.escape(tab.id)}"]`));

    const activateTab = (nextTab, { focus = false, scroll = true } = {}) => {
      const idx = tabs.indexOf(nextTab);
      if (idx === -1) return;

      tabs.forEach((tab, i) => {
        const selected = i === idx;
        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
      });

      panels.forEach((panel, i) => {
        if (!panel) return;
        const selected = i === idx;
        if (selected) {
          panel.removeAttribute('hidden');
          if (!panel.querySelector('a, button, input, summary, [tabindex]')) {
            panel.tabIndex = 0;
          }
        } else {
          panel.setAttribute('hidden', 'until-found');
          panel.removeAttribute('tabindex');
        }
      });

      if (scroll) {
        nextTab.scrollIntoView({ block: 'nearest', inline: 'nearest' });
      }
      if (focus) nextTab.focus();
    };

    // Initialize roving tabindex from HTML aria-selected state without scrolling page on load
    const initial = tabs.find((tab) => tab.getAttribute('aria-selected') === 'true') ?? tabs[0];
    if (initial) activateTab(initial, { focus: false, scroll: false });

    tablist.addEventListener('click', (event) => {
      const tab = event.target.closest('[role="tab"]');
      if (tab && tabs.includes(tab)) {
        activateTab(tab, { focus: false });
      }
    });

    tablist.addEventListener('keydown', (event) => {
      const current = document.activeElement;
      const idx = tabs.indexOf(current);
      if (idx === -1) return;

      let nextIdx = -1;
      if (event.key === 'ArrowRight') nextIdx = (idx + 1) % tabs.length;
      else if (event.key === 'ArrowLeft') nextIdx = (idx - 1 + tabs.length) % tabs.length;
      else if (event.key === 'Home') nextIdx = 0;
      else if (event.key === 'End') nextIdx = tabs.length - 1;

      if (nextIdx !== -1) {
        event.preventDefault();
        activateTab(tabs[nextIdx], { focus: true });
      }
    });

    panels.forEach((panel, idx) => {
      if (!panel) return;
      panel.addEventListener('beforematch', () => {
        activateTab(tabs[idx], { focus: false });
      });
    });
  }

  // Also enable roving tabindex + arrow keys on standalone tablists (hero device & rings device)
  for (const tablist of document.querySelectorAll('[role="tablist"]')) {
    if (tablist.closest('[data-tabs-root]')) continue;
    const tabs = Array.from(tablist.querySelectorAll('[role="tab"]'));
    if (!tabs.length) continue;

    const syncRoving = () => {
      const selected = tabs.find((t) => t.getAttribute('aria-selected') === 'true') ?? tabs[0];
      tabs.forEach((t) => {
        t.tabIndex = t === selected ? 0 : -1;
      });
    };

    syncRoving();
    tablist.addEventListener('click', (event) => {
      if (event.target.closest('[role="tab"]')) {
        queueMicrotask(syncRoving);
      }
    });

    tablist.addEventListener('keydown', (event) => {
      const idx = tabs.indexOf(document.activeElement);
      if (idx === -1) return;

      let nextIdx = -1;
      if (event.key === 'ArrowRight') nextIdx = (idx + 1) % tabs.length;
      else if (event.key === 'ArrowLeft') nextIdx = (idx - 1 + tabs.length) % tabs.length;
      else if (event.key === 'Home') nextIdx = 0;
      else if (event.key === 'End') nextIdx = tabs.length - 1;

      if (nextIdx !== -1) {
        event.preventDefault();
        const nextTab = tabs[nextIdx];
        tabs.forEach((t) => {
          t.tabIndex = t === nextTab ? 0 : -1;
        });
        nextTab.focus();
        nextTab.click();
      }
    });
  }
}

/* Video Reduced-Motion, WCAG 2.2.2 Pause/Play Toggle, and Lazy Media IO Fallback */
function initVideoControls() {
  const videos = Array.from(document.querySelectorAll('video'));
  if (!videos.length) return;

  let userPaused = REDUCED_MOTION_MQ.matches;

  const updateToggleButtons = () => {
    for (const btn of document.querySelectorAll('[data-video-toggle]')) {
      const key = userPaused ? 'showcase.playVideos' : 'showcase.pauseVideos';
      btn.setAttribute('data-i18n', key);
      btn.textContent = t(key);
    }
  };

  const applyMotionState = (paused) => {
    userPaused = paused;
    for (const video of videos) {
      if (paused) video.pause();
      else if (!video.querySelector('source[data-src]')) video.play().catch(() => {});
    }
    updateToggleButtons();
  };

  REDUCED_MOTION_MQ.addEventListener('change', (event) => {
    applyMotionState(event.matches);
  });

  document.addEventListener('click', (event) => {
    const btn = event.target.closest('[data-video-toggle]');
    if (!btn) return;
    applyMotionState(!userPaused);
  });

  document.addEventListener('earprint:langchange', updateToggleButtons);

  // Lazy media fallback when HTMLMediaElement.prototype.loading is unsupported
  if (!Object.hasOwn(HTMLMediaElement.prototype, 'loading')) {
    const lazyVideos = videos.filter((v) => v.getAttribute('loading') === 'lazy');
    if (lazyVideos.length) {
      const mediaObserver = new IntersectionObserver(
        (entries, observer) => {
          for (const entry of entries) {
            if (!entry.isIntersecting) continue;
            const video = entry.target;
            if (video.dataset.poster) {
              video.poster = video.dataset.poster;
              delete video.dataset.poster;
            }
            if (video.dataset.preload) {
              video.preload = video.dataset.preload;
              delete video.dataset.preload;
            }
            for (const source of video.querySelectorAll('source[data-src]')) {
              source.src = source.dataset.src;
              delete source.dataset.src;
            }
            video.load();
            if (!userPaused) {
              video.play().catch(() => {});
            }
            observer.unobserve(video);
          }
        },
        { rootMargin: '220px 0px' }
      );

      for (const video of lazyVideos) {
        if (video.hasAttribute('poster')) {
          video.dataset.poster = video.getAttribute('poster');
          video.removeAttribute('poster');
        }
        if (video.hasAttribute('preload') && video.getAttribute('preload') !== 'none') {
          video.dataset.preload = video.getAttribute('preload');
        }
        video.preload = 'none';
        for (const source of video.querySelectorAll('source[src]')) {
          source.dataset.src = source.getAttribute('src');
          source.removeAttribute('src');
        }
        mediaObserver.observe(video);
      }
    }
  }
  applyMotionState(userPaused);
}

/* Section 04 PSA Ear Grade 4-Factor Simulator (matches DeviceDossier.swift) */
function initEarGradeSimulator() {
  const dbInput = document.getElementById('grade-db-input');
  const doseInput = document.getElementById('grade-dose-input');
  const loudInput = document.getElementById('grade-loud-input');
  const nightInput = document.getElementById('grade-night-input');
  if (!dbInput || !doseInput || !loudInput || !nightInput) return;

  const scoreEl = document.getElementById('grade-score');
  const labelEl = document.getElementById('grade-label');
  const listEl = document.getElementById('grade-factors-list');
  const dbVal = document.getElementById('grade-db-val');
  const doseVal = document.getElementById('grade-dose-val');
  const loudVal = document.getElementById('grade-loud-val');
  const nightVal = document.getElementById('grade-night-val');

  const gradeBadge = (score, isZh) => {
    if (score >= 9.95) return isZh ? 'PRISTINE · 臻品' : 'PRISTINE';
    if (score >= 9.0) return isZh ? 'GEM MINT · 极品' : 'GEM MINT';
    if (score >= 8.0) return isZh ? 'MINT · 品相极佳' : 'MINT';
    if (score >= 7.0) return isZh ? 'NEAR MINT · 近全新' : 'NEAR MINT';
    if (score >= 6.0) return isZh ? 'EXCELLENT · 优良' : 'EXCELLENT';
    if (score >= 5.0) return isZh ? 'VERY GOOD · 良好' : 'VERY GOOD';
    return isZh ? 'WELL WORN · 重度使用' : 'WELL WORN';
  };

  const render = () => {
    const db = Number(dbInput.value);
    const dosePct = Number(doseInput.value);
    const loudPct = Number(loudInput.value);
    const nightPct = Number(nightInput.value);
    const isZh = getLang() === 'zh-Hans';

    if (dbVal) dbVal.textContent = `${db} dB(A)`;
    if (doseVal) doseVal.textContent = `${dosePct}%`;
    if (loudVal) loudVal.textContent = `${loudPct}%`;
    if (nightVal) nightVal.textContent = `${nightPct}%`;

    const volPen = Math.max(0, db - 55) * 0.12;
    const dosePen = Math.min(3.0, (dosePct / 100) * 2.5);
    const loudPen = Math.min(2.0, (loudPct / 100) * 8.0);
    const nightPen = Math.min(0.6, (nightPct / 100) * 0.8);

    const raw = 10 - volPen - dosePen - loudPen - nightPen;
    const clamped = Math.min(10.0, Math.max(1.0, Math.round(raw * 10) / 10));

    if (scoreEl) scoreEl.textContent = clamped.toFixed(1);
    if (labelEl) labelEl.textContent = gradeBadge(clamped, isZh);

    if (listEl) {
      const rows = [
        [isZh ? '平均音量扣分' : 'Average volume', `-${volPen.toFixed(2)}`],
        [isZh ? 'WHO 周剂量扣分' : 'Weekly WHO dose', `-${dosePen.toFixed(2)}`],
        [isZh ? '≥80 dB 高音量占比' : 'Loud sessions ≥ 80 dB', `-${loudPen.toFixed(2)}`],
        [isZh ? '深夜聆听占比' : 'Late-night share', `-${nightPen.toFixed(2)}`]
      ];
      listEl.innerHTML = '';
      for (const [name, pen] of rows) {
        const row = document.createElement('div');
        row.className = 'grade-factor-row';
        const left = document.createElement('span');
        left.textContent = name;
        const right = document.createElement('span');
        right.className = 'grade-factor-val';
        right.textContent = pen;
        row.append(left, right);
        listEl.append(row);
      }
    }
  };

  for (const input of [dbInput, doseInput, loudInput, nightInput]) {
    input.addEventListener('input', render);
  }
  document.addEventListener('earprint:langchange', render);
  render();
}

/* Section 05 41-Icon Studio */
function initIconStudio() {
  const mount = document.getElementById('icon-studio-mount');
  if (!mount) return;

  const squircle = document.getElementById('icon-preview-squircle');
  const cutoutImg = document.getElementById('icon-preview-cutout');
  const labelEl = document.getElementById('icon-preview-label');

  const FINISH_INFO = {
    midnight: { file: 'cutout-midnight.webp', en: 'Midnight (USB-C)', zh: '午夜色 (USB-C)' },
    starlight: { file: 'cutout-starlight.webp', en: 'Starlight (USB-C)', zh: '星光色 (USB-C)' },
    blue: { file: 'cutout-blue.webp', en: 'Blue (USB-C)', zh: '蓝色 (USB-C)' },
    purple: { file: 'cutout-purple.webp', en: 'Purple (USB-C)', zh: '紫色 (USB-C)' },
    orange: { file: 'cutout-orange.webp', en: 'Orange (USB-C)', zh: '橙色 (USB-C)' },
    spaceGray: { file: 'cutout-space-gray.webp', en: 'Space Gray (Lightning)', zh: '深空灰 (Lightning)' },
    silver: { file: 'cutout-silver.webp', en: 'Silver (Lightning)', zh: '银色 (Lightning)' },
    skyBlue: { file: 'cutout-sky-blue.webp', en: 'Sky Blue (Lightning)', zh: '天蓝色 (Lightning)' },
    green: { file: 'cutout-green.webp', en: 'Green (Lightning)', zh: '绿色 (Lightning)' },
    pink: { file: 'cutout-pink.webp', en: 'Pink (Lightning)', zh: '粉色 (Lightning)' }
  };

  const BG_LABELS = {
    auto: { en: 'Auto Split', zh: '自动双拼' },
    light: { en: 'Light', zh: '浅色' },
    dark: { en: 'Dark', zh: '深色' },
    holo: { en: 'Holo', zh: '全息' }
  };

  let state = { mode: 'custom', bg: 'dark', finish: 'midnight' };

  const render = () => {
    const isZh = getLang() === 'zh-Hans';
    const bgButtons = mount.querySelectorAll('[data-icon-bg]');
    const finishButtons = mount.querySelectorAll('[data-icon-finish]');
    const defaultBtn = mount.querySelector('[data-icon-default]');

    if (squircle) {
      squircle.dataset.bg = state.mode === 'default' ? 'dark' : state.bg;
      squircle.dataset.finish = state.mode === 'default' ? 'emblem' : state.finish;
    }

    if (cutoutImg) {
      if (state.mode === 'default') {
        cutoutImg.src = './assets/app-icon-default.webp';
        cutoutImg.alt = isZh ? 'Earprint 默认声纹徽标图标' : 'Earprint Studio default emblem app icon';
      } else {
        const info = FINISH_INFO[state.finish] ?? FINISH_INFO.midnight;
        cutoutImg.src = `./assets/icons/${info.file}`;
        cutoutImg.alt = `${isZh ? info.zh : info.en} AirPods Max icon cutout`;
      }
    }

    if (labelEl) {
      if (state.mode === 'default') {
        labelEl.textContent = isZh ? 'Earprint 默认声纹徽标 · #01/41' : 'Earprint Studio Emblem · #01/41';
      } else {
        const info = FINISH_INFO[state.finish] ?? FINISH_INFO.midnight;
        const bgLbl = BG_LABELS[state.bg] ?? BG_LABELS.dark;
        labelEl.textContent = `${isZh ? info.zh : info.en} · ${isZh ? bgLbl.zh : bgLbl.en}`;
      }
    }

    bgButtons.forEach((btn) => {
      btn.setAttribute('aria-pressed', String(state.mode === 'custom' && btn.dataset.iconBg === state.bg));
    });
    finishButtons.forEach((btn) => {
      btn.setAttribute('aria-pressed', String(state.mode === 'custom' && btn.dataset.iconFinish === state.finish));
    });
    if (defaultBtn) {
      defaultBtn.setAttribute('aria-pressed', String(state.mode === 'default'));
    }
  };

  mount.addEventListener('click', (event) => {
    const bgBtn = event.target.closest('[data-icon-bg]');
    if (bgBtn) {
      state = { ...state, mode: 'custom', bg: bgBtn.dataset.iconBg };
      render();
      return;
    }
    const finishBtn = event.target.closest('[data-icon-finish]');
    if (finishBtn) {
      state = { ...state, mode: 'custom', finish: finishBtn.dataset.iconFinish };
      render();
      return;
    }
    if (event.target.closest('[data-icon-default]')) {
      state = { ...state, mode: 'default' };
      render();
    }
  });

  document.addEventListener('earprint:langchange', render);
  render();
}

/* IntersectionObserver Fallback for Scroll Reveals */
function initScrollRevealFallback() {
  const nativeSupported = CSS.supports('(animation-timeline: view()) and (animation-range: 0% 100%)');
  if (nativeSupported || REDUCED_MOTION_MQ.matches) return;

  const targets = document.querySelectorAll('.reveal');
  if (!targets.length) return;

  document.documentElement.classList.add('has-scroll-fallback');

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      }
    },
    { threshold: 0 }
  );

  for (const target of targets) {
    observer.observe(target);
  }
}

/* Flip Button Bilingual Label Sync (keeps visible label in sync with aria-pressed & lang) */
function initFlipButtonLabels() {
  const pairs = [
    { id: 'hero-flip-btn', frontKey: 'hero.flipFront', backKey: 'hero.flipBack' },
    { id: 'slab-flip-btn', frontKey: 'dossier.slabFlipFront', backKey: 'dossier.slabFlipBack' }
  ];

  const syncLabels = () => {
    for (const { id, frontKey, backKey } of pairs) {
      const btn = document.getElementById(id);
      if (!btn) continue;
      const isFlipped = btn.getAttribute('aria-pressed') === 'true';
      const key = isFlipped ? backKey : frontKey;
      btn.setAttribute('data-i18n', key);
      btn.textContent = t(key);
    }
  };

  for (const { id } of pairs) {
    const btn = document.getElementById(id);
    if (!btn) continue;
    new MutationObserver(syncLabels).observe(btn, { attributes: true, attributeFilter: ['aria-pressed'] });
  }
  document.addEventListener('earprint:langchange', syncLabels);
  syncLabels();
}

/* Bootstrap */
window.earprintState = {
  getTheme: () => getThemeState(),
  getLang: () => getLang()
};

initI18n();
initThemeController();
initAccessibleTabs();
initVideoControls();
initEarGradeSimulator();
initIconStudio();
initScrollRevealFallback();
initFlipButtonLabels();

// Load interactive modules only on pages containing the showcase mounts
if (document.getElementById('hero-slab-mount')) {
  Promise.all([
    import('./ambient-canvas.js'),
    import('./foil-card.js'),
    import('./earprint-rings.js')
  ])
    .then(([ambient, foil, rings]) => {
      ambient?.initAmbientCanvas?.();
      foil?.initFoilCard?.();
      rings?.initEarprintRings?.();
    })
    .catch((err) => {
      console.error('Failed to initialize Earprint interactive labs:', err);
    });
}
