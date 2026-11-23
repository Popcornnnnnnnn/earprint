/**
 * Earprint 28-Day x 24h Acoustic Chronometer + WHO / ITU H.870 Sound Budget Lab
 * - Crisp Retina canvas dial (28 daily rings x 24 hourly sectors) matching EarprintGlyph.swift
 * - Exact SplitMix64(7n) + 4 Listening Persona presets with smooth animated morphing
 * - Interactive pointer hover, touch tap, and keyboard sector inspection
 * - Live WHO / ITU H.870 sound budget readout + calculator + Share Poster sync
 */

let didInit = false;

function getLang() {
  if (window.earprintState?.getLang) return window.earprintState.getLang();
  return document.documentElement.lang === 'zh-Hans' ? 'zh-Hans' : 'en';
}

function getResolvedTheme() {
  if (window.earprintState?.getTheme) {
    const t = window.earprintState.getTheme();
    if (t === 'light' || t === 'dark') return t;
  }
  const ds = document.documentElement.dataset.resolvedTheme;
  if (ds === 'light' || ds === 'dark') return ds;
  return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
}

function prefersReducedMotion() {
  return window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
}

function createSplitMix64(seedBigInt) {
  let state = BigInt(seedBigInt);
  const MASK = 0xffffffffffffffffn;
  const next = () => {
    state = (state + 0x9e3779b97f4a7c15n) & MASK;
    let z = state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK;
    return z ^ (z >> 31n);
  };
  const unit = () => Number(next() >> 11n) / 9007199254740992;
  const range = (min, max) => min + unit() * (max - min);
  return { unit, range };
}

function makeEmptyGrid() {
  return {
    minutes: Array.from({ length: 28 }, () => new Array(24).fill(0)),
    decibels: Array.from({ length: 28 }, () => new Array(24).fill(0)),
  };
}

function cloneGrid(grid) {
  return {
    minutes: grid.minutes.map((row) => row.slice()),
    decibels: grid.decibels.map((row) => row.slice()),
  };
}

/**
 * Exact SampleData grid from ListeningSummary.swift (SplitMix64 seed 7)
 */
function buildSampleBaseGrid() {
  const rng = createSplitMix64(7n);
  const grid = makeEmptyGrid();

  const add = (day, hour, minLo, minHi, dbLo, dbHi, chance = 1) => {
    if (rng.unit() >= chance) return;
    grid.minutes[day][hour] = Math.min(60, grid.minutes[day][hour] + rng.range(minLo, minHi));
    grid.decibels[day][hour] = rng.range(dbLo, dbHi);
  };

  for (let day = 0; day < 28; day += 1) {
    const weekday = day % 7 < 5;
    if (weekday) {
      add(day, 8, 25, 50, 62, 70);
      add(day, 9, 5, 20, 60, 66, 0.6);
      add(day, 13, 10, 30, 54, 60, 0.5);
      add(day, 18, 25, 50, 63, 72);
      add(day, 19, 10, 25, 60, 66, 0.7);
    } else {
      for (let h = 14; h <= 17; h += 1) {
        add(day, h, 10, 45, 55, 64, 0.55);
      }
    }
    for (let h = 21; h <= 23; h += 1) {
      add(day, h, 15, 55, 58, 70, 0.75);
    }
    add(day, 0, 10, 45, 66, 80, 0.5);
    add(day, 1, 5, 30, 70, 82, 0.25);
  }
  return grid;
}

function scaleGrid(base, keep, seed) {
  const rng = createSplitMix64(BigInt(seed));
  const out = cloneGrid(base);
  for (let d = 0; d < 28; d += 1) {
    for (let h = 0; h < 24; h += 1) {
      if (rng.unit() > keep) {
        out.minutes[d][h] = 0;
        out.decibels[d][h] = 0;
      }
    }
  }
  return out;
}

function mergeGrids(grids) {
  const out = makeEmptyGrid();
  for (let d = 0; d < 28; d += 1) {
    for (let h = 0; h < 24; h += 1) {
      let sumMin = 0;
      let energy = 0;
      for (const g of grids) {
        const m = g.minutes[d][h];
        const db = g.decibels[d][h];
        if (m > 0 && db > 0) {
          sumMin += m;
          energy += Math.pow(10, db / 10) * m;
        }
      }
      if (sumMin > 0 && energy > 0) {
        out.minutes[d][h] = Math.min(60, sumMin);
        out.decibels[d][h] = 10 * Math.log10(energy / sumMin);
      }
    }
  }
  return out;
}

function buildPersonaGrid(personaKey) {
  const seeds = {
    nightOwl: 101n,
    commuter: 202n,
    earlyBird: 303n,
    allDay: 404n,
  };
  const rng = createSplitMix64(seeds[personaKey] || 404n);
  const grid = makeEmptyGrid();
  const add = (day, hour, minLo, minHi, dbLo, dbHi, chance = 1) => {
    if (rng.unit() >= chance) return;
    grid.minutes[day][hour] = Math.min(60, grid.minutes[day][hour] + rng.range(minLo, minHi));
    grid.decibels[day][hour] = rng.range(dbLo, dbHi);
  };

  for (let d = 0; d < 28; d += 1) {
    const weekday = d % 7 < 5;
    if (personaKey === 'nightOwl') {
      add(d, 13, 8, 22, 56, 63, 0.35);
      add(d, 21, 20, 46, 62, 71, 0.72);
      add(d, 22, 28, 56, 68, 78, 0.92);
      add(d, 23, 30, 58, 70, 81, 0.9);
      add(d, 0, 24, 54, 72, 83, 0.82);
      add(d, 1, 14, 42, 71, 82, 0.58);
      add(d, 2, 10, 28, 66, 76, 0.28);
    } else if (personaKey === 'commuter') {
      if (weekday) {
        add(d, 7, 25, 48, 72, 79, 0.88);
        add(d, 8, 30, 56, 74, 82, 0.95);
        add(d, 12, 10, 24, 58, 64, 0.4);
        add(d, 17, 28, 52, 73, 81, 0.9);
        add(d, 18, 30, 54, 74, 82, 0.94);
        add(d, 21, 12, 28, 58, 65, 0.45);
      } else {
        add(d, 11, 18, 36, 62, 70, 0.55);
        add(d, 16, 20, 42, 64, 72, 0.6);
      }
    } else if (personaKey === 'earlyBird') {
      add(d, 5, 18, 42, 55, 62, 0.85);
      add(d, 6, 32, 55, 57, 65, 0.95);
      add(d, 7, 22, 46, 56, 64, 0.86);
      add(d, 12, 14, 30, 54, 61, 0.6);
      add(d, 16, 12, 26, 56, 62, 0.45);
      add(d, 20, 10, 24, 54, 60, 0.4);
    } else {
      for (let h = 9; h <= 21; h += 1) {
        const isBreak = h === 12 || h === 19;
        add(d, h, isBreak ? 10 : 18, isBreak ? 26 : 42, 58, 69, isBreak ? 0.4 : 0.68);
      }
      add(d, 22, 10, 24, 57, 64, 0.35);
    }
  }
  return grid;
}

function normalizePersonaKey(raw) {
  if (!raw) return 'nightOwl';
  const map = {
    nightOwl: 'nightOwl',
    'night-owl': 'nightOwl',
    commuter: 'commuter',
    commute: 'commuter',
    earlyBird: 'earlyBird',
    'early-bird': 'earlyBird',
    allDay: 'allDay',
    'all-day': 'allDay',
  };
  return map[raw] || 'allDay';
}

function analyzeGrid(grid) {
  let total28 = 0;
  let night = 0;
  let commute = 0;
  let morning = 0;
  let weekMin = 0;
  let weekEnergy = 0;
  let weekDose = 0;
  let maxMinutes = 1;

  for (let d = 0; d < 28; d += 1) {
    const isLast7 = d >= 21;
    for (let h = 0; h < 24; h += 1) {
      const m = grid.minutes[d][h];
      const db = grid.decibels[d][h];
      if (m <= 0) continue;
      if (m > maxMinutes) maxMinutes = m;
      total28 += m;
      if (h >= 22 || h <= 3) night += m;
      if (h === 7 || h === 8 || h === 17 || h === 18) commute += m;
      if (h >= 5 && h <= 7) morning += m;

      if (isLast7 && db > 0) {
        weekMin += m;
        const e = Math.pow(10, db / 10) * m;
        weekEnergy += e;
        weekDose += (Math.pow(10, (db - 80) / 10) * m) / 2400;
      }
    }
  }

  const weekDb = weekMin > 0 && weekEnergy > 0 ? 10 * Math.log10(weekEnergy / weekMin) : 0;
  let personaKey = 'allDay';
  let personaShare = 1;

  if (total28 > 0) {
    const nightShare = night / total28;
    const commuteShare = commute / total28;
    const morningShare = morning / total28;
    if (nightShare >= 0.3) {
      personaKey = 'nightOwl';
      personaShare = nightShare;
    } else if (commuteShare >= 0.3) {
      personaKey = 'commuter';
      personaShare = commuteShare;
    } else if (morningShare >= 0.2) {
      personaKey = 'earlyBird';
      personaShare = morningShare;
    }
  }

  return {
    total28,
    weekMin,
    weekDb,
    weekDose,
    maxMinutes,
    personaKey,
    personaShare,
  };
}

const PERSONA_META = {
  nightOwl: {
    emoji: '🦉',
    en: 'Night Owl',
    zh: '夜猫子',
    descEn: 'listening after 10 pm',
    descZh: '聆听发生在晚 10 点后',
  },
  commuter: {
    emoji: '🚇',
    en: 'Commute Soundtracker',
    zh: '通勤听众',
    descEn: 'listening on the commute',
    descZh: '聆听发生在早晚通勤时段',
  },
  earlyBird: {
    emoji: '🐦',
    en: 'Early Bird',
    zh: '早起听众',
    descEn: 'listening before 8 am',
    descZh: '聆听发生在早 8 点前',
  },
  allDay: {
    emoji: '🎧',
    en: 'All-Day Listener',
    zh: '全天听众',
    descEn: 'steady full-day rhythm',
    descZh: '全天均匀陪伴聆听',
  },
};

function mixRgb(a, b, t) {
  const clamped = Math.max(0, Math.min(1, t));
  const r = Math.round(a[0] + (b[0] - a[0]) * clamped);
  const g = Math.round(a[1] + (b[1] - a[1]) * clamped);
  const bl = Math.round(a[2] + (b[2] - a[2]) * clamped);
  return [r, g, bl];
}

function levelRgb(db, isLight) {
  const q = isLight ? [13, 153, 140] : [82, 230, 219];
  const m = isLight ? [204, 128, 10] : [250, 199, 92];
  const l = isLight ? [219, 41, 71] : [252, 87, 117];
  if (db < 60) return q;
  if (db < 72) return mixRgb(q, m, (db - 60) / 12);
  if (db < 82) return mixRgb(m, l, (db - 72) / 10);
  return l;
}

function formatHourRange(hour) {
  const h0 = String(hour).padStart(2, '0');
  const h1 = String((hour + 1) % 24).padStart(2, '0');
  return `${h0}:00–${h1}:00`;
}

function formatHoursMinutes(minutes, lang) {
  const m = Math.max(0, Math.round(minutes));
  const h = Math.floor(m / 60);
  const rem = m % 60;
  if (h === 0) return lang === 'zh-Hans' ? `${rem} 分钟` : `${rem}m`;
  return `${h}h ${String(rem).padStart(2, '0')}m`;
}

function formatAllowedDuration(hours, lang) {
  if (!Number.isFinite(hours) || hours >= 999) {
    return lang === 'zh-Hans' ? '999+ 小时' : '999+ h';
  }
  if (hours >= 10) return lang === 'zh-Hans' ? `${Math.round(hours)} 小时/周` : `${Math.round(hours)}h / wk`;
  if (hours >= 1) return lang === 'zh-Hans' ? `${hours.toFixed(1)} 小时/周` : `${hours.toFixed(1)}h / wk`;
  const mins = Math.max(1, Math.round(hours * 60));
  return lang === 'zh-Hans' ? `${mins} 分钟/周` : `${mins}m / wk`;
}

export function initEarprintRings() {
  if (didInit) return;
  didInit = true;

  const canvas = document.getElementById('earprint-rings-canvas');
  if (!canvas) return;

  const baseGrid = buildSampleBaseGrid();
  const pro2Grid = baseGrid;
  const maxGrid = scaleGrid(baseGrid, 0.45, 450);
  const airpods4Grid = scaleGrid(baseGrid, 0.15, 150);
  const allGrid = mergeGrids([pro2Grid, maxGrid, airpods4Grid]);

  const datasets = {
    all: allGrid,
    pro2: pro2Grid,
    max: maxGrid,
    airpods4: airpods4Grid,
    nightOwl: buildPersonaGrid('nightOwl'),
    commuter: buildPersonaGrid('commuter'),
    earlyBird: buildPersonaGrid('earlyBird'),
    allDay: buildPersonaGrid('allDay'),
  };

  const deviceBtns = Array.from(document.querySelectorAll('[data-rings-device]'));
  const personaBtns = Array.from(document.querySelectorAll('[data-rings-persona]'));
  const posterAspectBtns = Array.from(document.querySelectorAll('[data-poster-aspect]'));
  const posterThemeBtns = Array.from(document.querySelectorAll('[data-poster-theme]'));

  const readoutEl = document.getElementById('rings-readout');
  const centerHoursEl = document.getElementById('rings-center-hours');
  const centerDbEl = document.getElementById('rings-center-db');
  const personaBadgeEl = document.getElementById('rings-persona-badge');
  const a11ySummaryEl = document.getElementById('rings-a11y-summary');

  const whoDbRange = document.getElementById('who-db-range');
  const whoHoursRange = document.getElementById('who-hours-range');
  const whoBudgetPctEl = document.getElementById('who-budget-pct');
  const whoAllowedHoursEl = document.getElementById('who-allowed-hours');
  const whoExposedMinEl = document.getElementById('who-exposed-min');
  const whoRemainingPctEl = document.getElementById('who-remaining-pct');
  const whoBarFillEl = document.getElementById('who-bar-fill');
  const whoVerdictEl = document.getElementById('who-verdict');

  const posterEl = document.getElementById('share-poster-preview');
  const posterCanvas = document.getElementById('share-poster-canvas');

  let activeModeKey = 'all';
  let activeDeviceKey = 'all';
  let activePersonaPreset = null;
  let fromGrid = cloneGrid(datasets.all);
  let targetGrid = cloneGrid(datasets.all);
  let displayGrid = cloneGrid(datasets.all);
  let morphStart = 0;
  const MORPH_MS = 440;

  let hoveredCell = null; // { day, hour }
  let pinnedCell = null;
  let reticleAngle = -Math.PI / 2;
  let lastFrameTime = 0;
  let rafId = 0;
  let isVisible = true;
  let canvasSize = 640;

  if (!canvas.hasAttribute('tabindex')) canvas.setAttribute('tabindex', '0');

  function setDataset(key, options = {}) {
    const next = datasets[key];
    if (!next) return;
    activeModeKey = key;
    if (options.isDevice) {
      activeDeviceKey = key;
      activePersonaPreset = null;
    } else if (options.isPersona) {
      activePersonaPreset = key;
      activeDeviceKey = null;
    }

    if (prefersReducedMotion()) {
      fromGrid = cloneGrid(next);
      targetGrid = cloneGrid(next);
      displayGrid = cloneGrid(next);
      morphStart = 0;
    } else {
      fromGrid = cloneGrid(displayGrid);
      targetGrid = cloneGrid(next);
      morphStart = performance.now();
    }

    whoCustomMode = false;
    syncMetricsAndWHO({ syncSliders: true, useExactGrid: true });
    updateSelectionUI();
    drawFrame(performance.now());
    wake();
  }

  function updateSelectionUI() {
    deviceBtns.forEach((btn) => {
      btn.setAttribute('aria-selected', String(btn.dataset.ringsDevice === activeDeviceKey));
    });
    personaBtns.forEach((btn) => {
      const normalized = normalizePersonaKey(btn.dataset.ringsPersona);
      btn.setAttribute('aria-pressed', String(normalized === activePersonaPreset));
    });
  }

  function syncWhoFromInputs(overrideMetrics = null) {
    const lang = getLang();
    const isLight = getResolvedTheme() === 'light';
    const db = overrideMetrics ? overrideMetrics.weekDb : Number(whoDbRange?.value ?? 70);
    const exposedMinutes = overrideMetrics
      ? Math.round(overrideMetrics.weekMin)
      : Math.round(Number(whoHoursRange?.value ?? 35) * 60);
    const weeklyHours = exposedMinutes / 60;

    // Exact WHO ITU H.870 equal-energy formula: 40h/week at 80 dB(A), halving every +3.01 dB
    const allowedHours = 40 * Math.pow(10, (80 - db) / 10);
    const doseRatio = overrideMetrics
      ? overrideMetrics.weekDose
      : (weeklyHours / 40) * Math.pow(10, (db - 80) / 10);
    const dosePct = doseRatio * 100;
    const remainingPct = Math.max(0, 100 - dosePct);

    const [r, g, b] = levelRgb(db || 62, isLight);
    const levelColor = `rgb(${r}, ${g}, ${b})`;

    const dbReadout = document.getElementById('who-db-value');
    const hrsReadout = document.getElementById('who-hours-value');
    if (dbReadout) dbReadout.textContent = `${Math.round(db)} dB(A)`;
    if (hrsReadout) hrsReadout.textContent = `${weeklyHours.toFixed(1)}h`;

    if (whoBudgetPctEl) {
      whoBudgetPctEl.textContent = dosePct < 10 ? `${dosePct.toFixed(1)}%` : `${Math.round(dosePct)}%`;
      whoBudgetPctEl.style.color = levelColor;
    }
    if (whoAllowedHoursEl) {
      whoAllowedHoursEl.textContent = formatAllowedDuration(allowedHours, lang);
    }
    if (whoExposedMinEl) {
      whoExposedMinEl.textContent =
        lang === 'zh-Hans' ? `${exposedMinutes.toLocaleString('en-US')} 分钟` : `${exposedMinutes.toLocaleString('en-US')} min`;
    }
    if (whoRemainingPctEl) {
      whoRemainingPctEl.textContent = `${Math.max(0, Math.round(remainingPct))}%`;
    }
    if (whoBarFillEl) {
      whoBarFillEl.style.inlineSize = `${Math.min(100, Math.max(2, dosePct))}%`;
      whoBarFillEl.style.backgroundColor = levelColor;
    }
    if (whoVerdictEl) {
      let msg;
      if (dosePct <= 40) {
        msg = lang === 'zh-Hans' ? '安全充裕 · 低听觉疲劳风险' : 'Well within WHO weekly margin';
      } else if (dosePct <= 85) {
        msg = lang === 'zh-Hans' ? '适中负荷 · 保持音量均衡' : 'Moderate load · comfortable margin';
      } else if (dosePct <= 100) {
        msg = lang === 'zh-Hans' ? '接近每周上限 · 建议调低 3 dB' : 'Approaching weekly ceiling · ease volume by 3 dB';
      } else {
        msg = lang === 'zh-Hans' ? '超出 WHO 每周参考限额 · 建议休息或降噪' : 'Over WHO weekly allowance · rest ears or lower level';
      }
      whoVerdictEl.textContent = msg;
      whoVerdictEl.style.color = levelColor;
    }
  }

  function syncMetricsAndWHO(opts = {}) {
    const lang = getLang();
    const isLight = getResolvedTheme() === 'light';
    const metrics = analyzeGrid(targetGrid);
    const pMeta = PERSONA_META[metrics.personaKey] || PERSONA_META.allDay;
    const sharePct = Math.round(metrics.personaShare * 100);

    if (centerHoursEl) {
      centerHoursEl.textContent = formatHoursMinutes(metrics.weekMin, lang);
    }
    if (centerDbEl) {
      const [r, g, b] = levelRgb(metrics.weekDb || 62, isLight);
      centerDbEl.textContent = metrics.weekMin > 0 ? `${metrics.weekDb.toFixed(1)} dB(A)` : '— dB(A)';
      centerDbEl.style.color = `rgb(${r}, ${g}, ${b})`;
    }
    if (personaBadgeEl) {
      const label = lang === 'zh-Hans' ? pMeta.zh : pMeta.en;
      const shareSuffix = metrics.personaKey === 'allDay' ? '' : ` · ${sharePct}%`;
      personaBadgeEl.textContent = `${pMeta.emoji} ${label}${shareSuffix}`;
    }

    if (opts.syncSliders) {
      if (whoDbRange && metrics.weekDb > 0) {
        const clampedDb = Math.max(Number(whoDbRange.min) || 55, Math.min(Number(whoDbRange.max) || 95, Math.round(metrics.weekDb)));
        whoDbRange.value = String(clampedDb);
      }
      if (whoHoursRange) {
        const hrs = Math.max(Number(whoHoursRange.min) || 1, Math.min(Number(whoHoursRange.max) || 50, Number((metrics.weekMin / 60).toFixed(1))));
        whoHoursRange.value = String(hrs);
      }
    }

    syncWhoFromInputs(opts.useExactGrid !== false ? metrics : null);
    updateSectorReadout();

    if (a11ySummaryEl) {
      const pTitle = lang === 'zh-Hans' ? pMeta.zh : pMeta.en;
      const dt1 = lang === 'zh-Hans' ? '近 7 天聆听' : '7-day listening';
      const dt2 = lang === 'zh-Hans' ? '能量均响度' : 'Energy Leq';
      const dt3 = lang === 'zh-Hans' ? '聆听画像' : 'Listening persona';
      const dt4 = lang === 'zh-Hans' ? 'WHO 周限额占比' : 'WHO weekly budget';
      a11ySummaryEl.innerHTML =
        `<dt>${dt1}</dt><dd>${formatHoursMinutes(metrics.weekMin, lang)}</dd>` +
        `<dt>${dt2}</dt><dd>${metrics.weekDb.toFixed(1)} dB(A)</dd>` +
        `<dt>${dt3}</dt><dd>${pMeta.emoji} ${pTitle}</dd>` +
        `<dt>${dt4}</dt><dd>${Math.round(metrics.weekDose * 100)}%</dd>`;
    }

    drawPosterPreview(metrics);
  }

  function updateSectorReadout() {
    if (!readoutEl) return;
    const lang = getLang();
    const isLight = getResolvedTheme() === 'light';
    const active = hoveredCell || pinnedCell;

    if (!active) {
      readoutEl.innerHTML =
        lang === 'zh-Hans'
          ? '<span>悬停、点击或使用方向键探查任意日期与时段</span><span>28 天 × 24 小时</span>'
          : '<span>Hover, tap, or arrow-key any ring sector to inspect</span><span>28 days × 24h</span>';
      return;
    }

    const { day, hour } = active;
    const daysAgo = 27 - day;
    let dayLabel;
    if (daysAgo === 0) dayLabel = lang === 'zh-Hans' ? '今天' : 'Today';
    else if (daysAgo === 1) dayLabel = lang === 'zh-Hans' ? '昨天' : 'Yesterday';
    else dayLabel = lang === 'zh-Hans' ? `${daysAgo} 天前` : `${daysAgo}d ago`;

    const mins = Math.round(displayGrid.minutes[day]?.[hour] ?? 0);
    const db = displayGrid.decibels[day]?.[hour] ?? 0;
    const windowStr = formatHourRange(hour);

    if (mins <= 0) {
      const quietText = lang === 'zh-Hans' ? '无播放记录' : 'Quiet · No playback';
      readoutEl.innerHTML =
        `<strong>${dayLabel} · ${windowStr}</strong>` +
        `<span style="opacity:0.72">${quietText}</span>`;
      return;
    }

    const [r, g, b] = levelRgb(db, isLight);
    const minStr = lang === 'zh-Hans' ? `${mins} 分钟` : `${mins} min`;
    readoutEl.innerHTML =
      `<strong>${dayLabel} · ${windowStr}</strong>` +
      `<span>${minStr} · <strong style="color:rgb(${r},${g},${b})">${db.toFixed(1)} dB(A) Leq</strong></span>`;
  }

  function drawPosterPreview(metrics) {
    const posterHoursEl = document.getElementById('poster-week-hours');
    const posterPersonaEl = document.getElementById('poster-persona');
    const posterDbEl = document.getElementById('poster-avg-db');
    const lang = getLang();
    const pMeta = PERSONA_META[metrics.personaKey] || PERSONA_META.allDay;

    if (posterHoursEl) posterHoursEl.textContent = formatHoursMinutes(metrics.weekMin, lang);
    if (posterPersonaEl) posterPersonaEl.textContent = `${pMeta.emoji} ${lang === 'zh-Hans' ? pMeta.zh : pMeta.en}`;
    if (posterDbEl) posterDbEl.textContent = `${Math.round(metrics.weekDb)} dB`;

    if (!posterCanvas) return;
    const isLight = posterEl?.dataset.scheme === 'light';
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const side = 220;
    posterCanvas.width = side * dpr;
    posterCanvas.height = side * dpr;
    const ctx = posterCanvas.getContext('2d');
    if (!ctx) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, side, side);
    drawDialOnContext(ctx, side, targetGrid, metrics, isLight, null, null);
  }

  function drawDialOnContext(ctx, side, grid, metrics, isLight, activeCell, sweepAngle) {
    const cx = side / 2;
    const cy = side / 2;
    const outer = (side / 2) * 0.8;
    const inner = outer * 0.46;
    const step = (outer - inner) / 28;
    const bezelGap = Math.max(1.6, step * 0.55);
    const innerRingR = Math.max(2, inner - bezelGap * 0.55);
    const outerRingR = outer + bezelGap * 0.65;
    const maxMinutes = Math.max(metrics.maxMinutes, 1);
    const arcGapDeg = 1.2;

    // 1. Empty tracks
    ctx.strokeStyle = isLight ? 'rgba(19, 20, 28, 0.075)' : 'rgba(255, 255, 255, 0.055)';
    ctx.lineWidth = step * 0.54;
    ctx.lineCap = 'round';
    ctx.beginPath();
    for (let d = 0; d < 28; d += 1) {
      const r = inner + step * (d + 0.5);
      for (let h = 0; h < 24; h += 1) {
        const a0 = ((h * 15 - 90 + arcGapDeg) * Math.PI) / 180;
        const a1 = (((h + 1) * 15 - 90 - arcGapDeg) * Math.PI) / 180;
        ctx.moveTo(cx + r * Math.cos(a0), cy + r * Math.sin(a0));
        ctx.arc(cx, cy, r, a0, a1);
      }
    }
    ctx.stroke();

    // 2. Concentric precision bezel hairlines
    ctx.lineWidth = Math.max(0.75, Math.min(1.1, side * 0.004));
    ctx.strokeStyle = isLight ? 'rgba(19, 20, 28, 0.13)' : 'rgba(255, 255, 255, 0.12)';
    ctx.beginPath();
    ctx.arc(cx, cy, innerRingR, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(cx, cy, outerRingR, 0, Math.PI * 2);
    ctx.stroke();

    // Inner persona progress ring (between center readout & day 0)
    const personaRingR = Math.max(4, innerRingR - Math.max(4, step * 1.15));
    if (personaRingR > outer * 0.25) {
      ctx.strokeStyle = isLight ? 'rgba(19, 20, 28, 0.08)' : 'rgba(255, 255, 255, 0.08)';
      ctx.lineWidth = Math.max(1.5, step * 0.35);
      ctx.beginPath();
      ctx.arc(cx, cy, personaRingR, 0, Math.PI * 2);
      ctx.stroke();

      const shareSweep = Math.max(0.18, Math.min(1, metrics.personaShare)) * Math.PI * 2;
      const [pr, pg, pb] = levelRgb(metrics.weekDb || 62, isLight);
      ctx.strokeStyle = `rgba(${pr}, ${pg}, ${pb}, 0.72)`;
      ctx.beginPath();
      ctx.arc(cx, cy, personaRingR, -Math.PI / 2, -Math.PI / 2 + shareSweep);
      ctx.stroke();
    }

    // 3. Minor 24-hour bezel ticks
    ctx.strokeStyle = isLight ? 'rgba(19, 20, 28, 0.22)' : 'rgba(255, 255, 255, 0.18)';
    ctx.lineWidth = Math.max(0.7, side * 0.003);
    const tickLen = Math.max(2.2, side * 0.014);
    ctx.beginPath();
    for (let h = 0; h < 24; h += 1) {
      if (h % 6 === 0) continue;
      const ang = ((h * 15 - 90) * Math.PI) / 180;
      const c = Math.cos(ang);
      const s = Math.sin(ang);
      ctx.moveTo(cx + (outerRingR - tickLen * 0.35) * c, cy + (outerRingR - tickLen * 0.35) * s);
      ctx.lineTo(cx + (outerRingR + tickLen * 0.65) * c, cy + (outerRingR + tickLen * 0.65) * s);
    }
    ctx.stroke();

    // 4. Sweeping acoustic reticle beam (if animated)
    if (sweepAngle !== null) {
      ctx.save();
      const grad = ctx.createRadialGradient(cx, cy, innerRingR, cx, cy, outerRingR);
      const sweepColor = isLight ? 'rgba(13, 153, 140, 0.14)' : 'rgba(82, 230, 219, 0.16)';
      grad.addColorStop(0, 'transparent');
      grad.addColorStop(0.5, sweepColor);
      grad.addColorStop(1, 'transparent');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.moveTo(cx + innerRingR * Math.cos(sweepAngle - 0.18), cy + innerRingR * Math.sin(sweepAngle - 0.18));
      ctx.arc(cx, cy, outerRingR, sweepAngle - 0.18, sweepAngle + 0.02);
      ctx.arc(cx, cy, innerRingR, sweepAngle + 0.02, sweepAngle - 0.18, true);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }

    // 5. Active listening sectors (subtle glow + crisp strokes)
    const minAlpha = isLight ? 0.48 : 0.35;
    ctx.lineCap = 'round';
    for (let d = 0; d < 28; d += 1) {
      const r = inner + step * (d + 0.5);
      for (let h = 0; h < 24; h += 1) {
        const mins = grid.minutes[d][h];
        if (mins <= 0.15) continue;
        const db = grid.decibels[d][h] || 60;
        const [cr, cg, cb] = levelRgb(db, isLight);
        const t = Math.min(1, mins / maxMinutes);
        const alpha = minAlpha + (1 - minAlpha) * (0.2 + 0.8 * t);
        const a0 = ((h * 15 - 90 + arcGapDeg) * Math.PI) / 180;
        const a1 = (((h + 1) * 15 - 90 - arcGapDeg) * Math.PI) / 180;

        // Soft acoustic aura
        ctx.strokeStyle = `rgba(${cr}, ${cg}, ${cb}, ${(isLight ? 0.16 : 0.24) * t})`;
        ctx.lineWidth = step * 1.15;
        ctx.beginPath();
        ctx.arc(cx, cy, r, a0, a1);
        ctx.stroke();

        // Crisp core segment
        ctx.strokeStyle = `rgba(${cr}, ${cg}, ${cb}, ${alpha})`;
        ctx.lineWidth = step * (0.34 + 0.54 * t);
        ctx.beginPath();
        ctx.arc(cx, cy, r, a0, a1);
        ctx.stroke();
      }
    }

    // 6. Hovered / Pinned Sector Bracket
    if (activeCell) {
      const r = inner + step * (activeCell.day + 0.5);
      const a0 = ((activeCell.hour * 15 - 90 + 0.6) * Math.PI) / 180;
      const a1 = (((activeCell.hour + 1) * 15 - 90 - 0.6) * Math.PI) / 180;
      const aMid = (a0 + a1) / 2;

      ctx.save();
      ctx.strokeStyle = isLight ? 'rgba(19, 20, 28, 0.28)' : 'rgba(255, 255, 255, 0.24)';
      ctx.lineWidth = 1;
      ctx.setLineDash([2, 3]);
      ctx.beginPath();
      ctx.moveTo(cx + innerRingR * Math.cos(aMid), cy + innerRingR * Math.sin(aMid));
      ctx.lineTo(cx + outerRingR * Math.cos(aMid), cy + outerRingR * Math.sin(aMid));
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.strokeStyle = isLight ? '#13141C' : '#FFFFFF';
      ctx.lineWidth = Math.max(2, step * 0.92);
      ctx.beginPath();
      ctx.arc(cx, cy, r, a0, a1);
      ctx.stroke();
      ctx.restore();
    }

    // 7. Cardinal dots & mono numerals (0, 6, 12, 18)
    const dotR = Math.max(1.3, Math.min(2.1, side * 0.008));
    const fontSize = Math.max(10, Math.round(side * 0.032));
    ctx.font = `700 ${fontSize}px ui-monospace, "SF Mono", Menlo, monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    const cardinals = [
      [0, '0'],
      [6, '6'],
      [12, '12'],
      [18, '18'],
    ];
    for (const [hour, label] of cardinals) {
      const ang = ((hour * 15 - 90) * Math.PI) / 180;
      const c = Math.cos(ang);
      const s = Math.sin(ang);

      ctx.fillStyle =
        hour === 0
          ? isLight
            ? 'rgba(19, 20, 28, 0.8)'
            : 'rgba(255, 255, 255, 0.92)'
          : isLight
            ? 'rgba(19, 20, 28, 0.42)'
            : 'rgba(255, 255, 255, 0.56)';
      ctx.beginPath();
      ctx.arc(cx + outerRingR * c, cy + outerRingR * s, dotR, 0, Math.PI * 2);
      ctx.fill();

      const labelR = outerRingR + Math.max(13, side * 0.056);
      ctx.fillStyle =
        hour === 0
          ? isLight
            ? 'rgba(19, 20, 28, 0.88)'
            : 'rgba(255, 255, 255, 0.9)'
          : isLight
            ? 'rgba(19, 20, 28, 0.56)'
            : 'rgba(255, 255, 255, 0.58)';
      ctx.fillText(label, cx + labelR * c, cy + labelR * s);
    }
  }

  function interpolateGrid(t) {
    const ease = 1 - Math.pow(1 - t, 3);
    for (let d = 0; d < 28; d += 1) {
      for (let h = 0; h < 24; h += 1) {
        const m0 = fromGrid.minutes[d][h];
        const m1 = targetGrid.minutes[d][h];
        const db0 = fromGrid.decibels[d][h];
        const db1 = targetGrid.decibels[d][h];

        displayGrid.minutes[d][h] = m0 + (m1 - m0) * ease;
        if (m0 <= 0.1 && m1 > 0.1) displayGrid.decibels[d][h] = db1;
        else if (m1 <= 0.1 && m0 > 0.1) displayGrid.decibels[d][h] = db0;
        else displayGrid.decibels[d][h] = db0 + (db1 - db0) * ease;
      }
    }
  }

  function drawFrame(now) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const px = Math.round(canvasSize * dpr);
    if (canvas.width !== px || canvas.height !== px) {
      canvas.width = px;
      canvas.height = px;
    }

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    if (morphStart > 0) {
      const elapsed = now - morphStart;
      const t = Math.min(1, elapsed / MORPH_MS);
      interpolateGrid(t);
      if (t >= 1) {
        displayGrid = cloneGrid(targetGrid);
        morphStart = 0;
      }
    }

    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, canvasSize, canvasSize);

    const isLight = getResolvedTheme() === 'light';
    const metrics = analyzeGrid(displayGrid);
    const activeCell = hoveredCell || pinnedCell;
    const sweep = prefersReducedMotion() ? null : reticleAngle;
    drawDialOnContext(ctx, canvasSize, displayGrid, metrics, isLight, activeCell, sweep);
  }

  function tick(now) {
    rafId = 0;
    if (!isVisible || document.hidden) return;
    if (!lastFrameTime) lastFrameTime = now;
    const dt = Math.min(0.05, Math.max(0.001, (now - lastFrameTime) / 1000));
    lastFrameTime = now;

    const reduced = prefersReducedMotion();
    if (!reduced) {
      reticleAngle = (reticleAngle + dt * 0.34) % (Math.PI * 2);
    }

    drawFrame(now);

    if (!reduced || morphStart > 0) {
      rafId = requestAnimationFrame(tick);
    } else {
      lastFrameTime = 0;
    }
  }

  function wake() {
    if (!rafId && isVisible && !document.hidden) {
      lastFrameTime = 0;
      rafId = requestAnimationFrame(tick);
    }
  }

  function pickCellFromPointer(clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return null;
    const side = Math.min(rect.width, rect.height);
    const x = clientX - (rect.left + rect.width / 2);
    const y = clientY - (rect.top + rect.height / 2);
    const r = Math.hypot(x, y);
    const outer = (side / 2) * 0.8;
    const inner = outer * 0.46;
    if (r < inner * 0.82 || r > outer * 1.12) return null;

    const step = (outer - inner) / 28;
    const day = Math.max(0, Math.min(27, Math.floor((r - inner) / step)));
    let deg = (Math.atan2(y, x) * 180) / Math.PI + 90;
    if (deg < 0) deg += 360;
    const hour = Math.max(0, Math.min(23, Math.floor(deg / 15)));
    return { day, hour };
  }

  canvas.addEventListener('pointermove', (e) => {
    const cell = pickCellFromPointer(e.clientX, e.clientY);
    if (
      (cell?.day ?? -1) !== (hoveredCell?.day ?? -1) ||
      (cell?.hour ?? -1) !== (hoveredCell?.hour ?? -1)
    ) {
      hoveredCell = cell;
      updateSectorReadout();
      drawFrame(performance.now());
    }
  });

  canvas.addEventListener('pointerleave', () => {
    if (hoveredCell) {
      hoveredCell = null;
      updateSectorReadout();
      drawFrame(performance.now());
    }
  });

  canvas.addEventListener('click', (e) => {
    const cell = pickCellFromPointer(e.clientX, e.clientY);
    if (!cell) {
      pinnedCell = null;
    } else if (pinnedCell && pinnedCell.day === cell.day && pinnedCell.hour === cell.hour) {
      pinnedCell = null;
    } else {
      pinnedCell = cell;
    }
    updateSectorReadout();
    drawFrame(performance.now());
  });

  canvas.addEventListener('keydown', (e) => {
    const base = pinnedCell || hoveredCell || { day: 27, hour: 21 };
    if (e.key === 'ArrowRight') {
      e.preventDefault();
      pinnedCell = { day: base.day, hour: (base.hour + 1) % 24 };
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault();
      pinnedCell = { day: base.day, hour: (base.hour + 23) % 24 };
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      pinnedCell = { day: Math.min(27, base.day + 1), hour: base.hour };
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      pinnedCell = { day: Math.max(0, base.day - 1), hour: base.hour };
    } else if (e.key === 'Escape') {
      pinnedCell = null;
    } else {
      return;
    }
    updateSectorReadout();
    drawFrame(performance.now());
  });

  deviceBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const key = btn.dataset.ringsDevice;
      if (key) setDataset(key, { isDevice: true });
    });
  });

  personaBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const key = normalizePersonaKey(btn.dataset.ringsPersona);
      setDataset(key, { isPersona: true });
    });
  });

  let whoCustomMode = false;

  whoDbRange?.addEventListener('input', () => {
    whoCustomMode = true;
    syncWhoFromInputs();
  });
  whoHoursRange?.addEventListener('input', () => {
    whoCustomMode = true;
    syncWhoFromInputs();
  });

  posterAspectBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const aspect = btn.dataset.posterAspect;
      if (!aspect || !posterEl) return;
      posterEl.dataset.aspect = aspect;
      posterAspectBtns.forEach((b) => b.setAttribute('aria-pressed', String(b === btn)));
    });
  });

  posterThemeBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const scheme = btn.dataset.posterTheme;
      if (!scheme || !posterEl) return;
      posterEl.dataset.scheme = scheme;
      posterThemeBtns.forEach((b) => b.setAttribute('aria-pressed', String(b === btn)));
      drawPosterPreview(analyzeGrid(targetGrid));
    });
  });

  if ('ResizeObserver' in window) {
    const ro = new ResizeObserver((entries) => {
      const w = entries[0]?.contentRect?.width;
      if (w && w > 80) {
        canvasSize = Math.round(w);
        drawFrame(performance.now());
      }
    });
    ro.observe(canvas);
  }

  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver(
      (entries) => {
        isVisible = entries[0]?.isIntersecting ?? true;
        if (isVisible) wake();
      },
      { threshold: 0.05 }
    );
    io.observe(canvas);
  }

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && isVisible) wake();
  });

  document.addEventListener('earprint:themechange', () => {
    syncMetricsAndWHO({ syncSliders: false, useExactGrid: !whoCustomMode });
    drawFrame(performance.now());
  });

  document.addEventListener('earprint:langchange', () => {
    syncMetricsAndWHO({ syncSliders: false, useExactGrid: !whoCustomMode });
  });

  syncMetricsAndWHO({ syncSliders: true });
  updateSelectionUI();
  drawFrame(performance.now());
  wake();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => initEarprintRings(), { once: true });
} else {
  queueMicrotask(() => initEarprintRings());
}
