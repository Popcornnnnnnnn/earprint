/**
 * Earprint 3D Collectible Foil Slab Lab & Collector Binder
 * - Critically-damped rAF spring physics (hover tilt, pointer grab-drag, 180deg flip)
 * - 6 authentic metallic/iridescent tiers (Bronze Slate 0h+ -> Liquid Holo 2,000h+)
 * - Real-time 0-2,500h scrubber, device switcher, PSA rear provenance slab & 4-week glyph
 * - Collector Binder (#tier-binder-mount) & Section 04 PSA Slab (#psa-slab) flip/tilt
 */

const TIERS = [
  {
    id: 'bronze',
    minHours: 0,
    presetHours: 12,
    titleEn: 'BRONZE SLATE',
    titleZh: '青铜岩',
    shortEn: 'Bronze',
    shortZh: '青铜',
    finishEn: 'Anodized Matte',
    finishZh: '哑光阳极铜',
    taglineEn: 'Starter anodized slate cast on your first listen',
    taglineZh: '首次聆听即铸造的自然青铜岩起始卡面',
    glow: '#B58263',
    accentLight: '#8F5736',
    accentDark: '#CC9675',
    ink: '#FFFFFF',
    swatch: 'linear-gradient(135deg, #B58263, #5A3B2A)',
  },
  {
    id: 'silver',
    minHours: 25,
    presetHours: 64,
    titleEn: 'SILVER ALUMINUM',
    titleZh: '银灰铝',
    shortEn: 'Silver',
    shortZh: '银铝',
    finishEn: 'Beaded Alloy',
    finishZh: '微珠喷砂铝',
    taglineEn: 'Brushed silver aluminum unibody at 25+ hours',
    taglineZh: '累计满 25 小时解锁的微珠喷砂银灰一体成型质感',
    glow: '#B9C0CC',
    accentLight: '#596375',
    accentDark: '#DDE3ED',
    ink: '#14141A',
    swatch: 'linear-gradient(135deg, #EEF1F6, #7B8391)',
  },
  {
    id: 'sapphire',
    minHours: 120,
    presetHours: 188,
    titleEn: 'FJORD TEAL',
    titleZh: '峡湾青',
    shortEn: 'Fjord',
    shortZh: '峡湾',
    finishEn: 'Brushed Slate',
    finishZh: '拉丝石青绿',
    taglineEn: 'Coastal brushed fjord teal at 120+ hours',
    taglineZh: '累计满 120 小时解锁的海岸拉丝峡湾青卡面',
    glow: '#6D9CA8',
    accentLight: '#246E7D',
    accentDark: '#7EB0BD',
    ink: '#FFFFFF',
    swatch: 'linear-gradient(135deg, #86AEB8, #26454E)',
  },
  {
    id: 'platinum',
    minHours: 400,
    presetHours: 580,
    titleEn: 'DEEP PURPLE',
    titleZh: '深紫',
    shortEn: 'Purple',
    shortZh: '深紫',
    finishEn: 'Frosted Plum',
    finishZh: '哑光深紫釉',
    taglineEn: 'Frosted velvet deep purple at 400+ hours',
    taglineZh: '累计满 400 小时解锁的哑光丝绒深紫釉卡面',
    glow: '#8563B5',
    accentLight: '#66409E',
    accentDark: '#A382D6',
    ink: '#FFFFFF',
    swatch: 'linear-gradient(135deg, #8563B5, #24163A)',
  },
  {
    id: 'obsidian',
    minHours: 1000,
    presetHours: 1280,
    titleEn: 'MIDNIGHT CARBON',
    titleZh: '午夜碳纤',
    shortEn: 'Carbon',
    shortZh: '碳纤',
    finishEn: 'DLC Coating',
    finishZh: '类钻碳涂层',
    taglineEn: 'Forged midnight carbon at 1,000+ hours',
    taglineZh: '累计满 1,000 小时解锁的锻造碳纤维类钻黑臻享卡面',
    glow: '#4D90C4',
    accentLight: '#2E5794',
    accentDark: '#7EA6E0',
    ink: '#FFFFFF',
    swatch: 'linear-gradient(135deg, #252E42, #080B12)',
  },
  {
    id: 'holo',
    minHours: 2000,
    presetHours: 2240,
    titleEn: 'LIQUID HOLO · LEGENDARY',
    titleZh: '流光全息 · 传说',
    shortEn: 'Holo',
    shortZh: '全息',
    finishEn: 'Prism Oxide',
    finishZh: '液态全息镀膜',
    taglineEn: 'Full-spectrum liquid holographic crown at 2,000+ hours',
    taglineZh: '累计满 2,000 小时解锁的全光谱流光全息传说皇冠',
    glow: '#9A84FF',
    accentLight: '#0A8F8A',
    accentDark: '#88F5EC',
    ink: '#14141A',
    swatch: 'linear-gradient(135deg, #6CF5E8, #9A84FF, #FF84CE, #FFF08C)',
  },
];

const DEVICES = {
  pro2: {
    id: 'pro2',
    model: 'AirPods Pro 2 · USB-C',
    pid: '0x2024',
    serial: 1,
    defaultHours: 188 + 22 / 60,
    sessions: 269,
    longestMin: 220,
    avgDb: 58,
    weeklyDose: 0.042,
    loudShare: 0.01,
    nightShare: 0.18,
    activeMonths: 14,
    since: '2026.10.30',
    cutout: './assets/cutouts/airpods-pro-case.webp',
    altEn: 'AirPods Pro 2 with MagSafe charging case',
    altZh: 'AirPods Pro 2 无线充电盒立体模型',
    density: 1.0,
    seed: 7n,
  },
  max: {
    id: 'max',
    model: 'AirPods Max',
    pid: '0x200A',
    serial: 2,
    defaultHours: 64 + 10 / 60,
    sessions: 88,
    longestMin: 185,
    avgDb: 63,
    weeklyDose: 0.064,
    loudShare: 0.03,
    nightShare: 0.11,
    activeMonths: 23,
    since: '2024.12.25',
    cutout: './assets/cutouts/airpods-max.webp',
    altEn: 'AirPods Max over-ear headphones',
    altZh: 'AirPods Max 头戴式耳机立体模型',
    density: 0.65,
    seed: 450n,
  },
  airpods4: {
    id: 'airpods4',
    model: 'AirPods 4 (ANC)',
    pid: '0x201B',
    serial: 3,
    defaultHours: 9 + 40 / 60,
    sessions: 21,
    longestMin: 64,
    avgDb: 71,
    weeklyDose: 0.11,
    loudShare: 0.09,
    nightShare: 0.08,
    activeMonths: 20,
    since: '2025.03.08',
    cutout: './assets/cutouts/airpods-4.webp',
    altEn: 'AirPods 4 Active Noise Cancellation',
    altZh: 'AirPods 4 主动降噪版立体模型',
    density: 0.35,
    seed: 150n,
  },
  beats: {
    id: 'beats',
    model: 'Beats Fit Pro',
    pid: '0x2012',
    serial: 4,
    defaultHours: 35,
    sessions: 52,
    longestMin: 98,
    avgDb: 67,
    weeklyDose: 0.082,
    loudShare: 0.06,
    nightShare: 0.09,
    activeMonths: 17,
    since: '2025.06.14',
    cutout: './assets/cutouts/beats-fit-black.webp',
    altEn: 'Beats Fit Pro wireless earbuds',
    altZh: 'Beats Fit Pro 真无线耳机立体模型',
    density: 0.5,
    seed: 912n,
  },
};

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

function tierForHours(hours) {
  for (let i = TIERS.length - 1; i >= 0; i -= 1) {
    if (hours >= TIERS[i].minHours) return TIERS[i];
  }
  return TIERS[0];
}

function nextTierOf(tier) {
  const idx = TIERS.findIndex((t) => t.id === tier.id);
  return idx >= 0 && idx < TIERS.length - 1 ? TIERS[idx + 1] : null;
}

function computeEarGrade(dev) {
  const vol = Math.max(0, dev.avgDb - 55) * 0.12;
  const dose = Math.min(3, dev.weeklyDose * 2.5);
  const loud = Math.min(2, dev.loudShare * 8);
  const night = Math.min(0.6, dev.nightShare * 0.8);
  const score = Math.max(1, Math.min(10, Math.round((10 - vol - dose - loud - night) * 10) / 10));
  let label = 'WELL WORN';
  if (score >= 9.95) label = 'PRISTINE';
  else if (score >= 9.0) label = 'GEM MINT';
  else if (score >= 8.0) label = 'MINT';
  else if (score >= 7.0) label = 'NEAR MINT';
  else if (score >= 6.0) label = 'EXCELLENT';
  else if (score >= 5.0) label = 'VERY GOOD';
  return { score: score.toFixed(1), label };
}

function formatHoursMinutes(totalHours, lang) {
  const totalMinutes = Math.max(0, Math.round(totalHours * 60));
  const h = Math.floor(totalMinutes / 60);
  const m = totalMinutes % 60;
  if (h === 0) return lang === 'zh-Hans' ? `${m} 分钟` : `${m}m`;
  return `${h.toLocaleString('en-US')}h ${String(m).padStart(2, '0')}m`;
}

function formatMinutesCompact(minutes, lang) {
  const m = Math.round(minutes);
  const h = Math.floor(m / 60);
  const rem = m % 60;
  if (h === 0) return lang === 'zh-Hans' ? `${rem} 分钟` : `${rem}m`;
  return `${h}h ${rem}m`;
}

function ensureFoilLayers(target, withBevel = true) {
  if (!target) return;
  if (!target.querySelector(':scope > .foil-layers')) {
    const wrap = document.createElement('div');
    wrap.className = 'foil-layers';
    wrap.setAttribute('aria-hidden', 'true');
    wrap.innerHTML =
      '<div class="foil-base"></div>' +
      '<div class="foil-texture"></div>' +
      '<div class="foil-light"></div>' +
      '<div class="foil-sheen"></div>';
    target.prepend(wrap);
  }
  if (withBevel && !target.querySelector(':scope > .foil-bevel')) {
    const bevel = document.createElement('div');
    bevel.className = 'foil-bevel';
    bevel.setAttribute('aria-hidden', 'true');
    target.append(bevel);
  }
}

function drawMiniGlyph(container, dev, isLight) {
  if (!container) return;
  let canvas = container.tagName === 'CANVAS' ? container : container.querySelector('canvas');
  if (!canvas) {
    canvas = document.createElement('canvas');
    canvas.className = 'slab-mini-glyph-canvas';
    canvas.setAttribute('aria-hidden', 'true');
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    container.replaceChildren(canvas);
  }

  const size = 124;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = size * dpr;
  canvas.height = size * dpr;

  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, size, size);

  const cx = size / 2;
  const cy = size / 2;
  const outer = size * 0.44;
  const inner = outer * 0.45;
  const days = 28;
  const step = (outer - inner) / days;

  // Deterministic pseudo-random mini pattern matching device density
  let state = BigInt(dev.seed || 7n);
  const nextRand = () => {
    state = (state + 0x9e3779b97f4a7c15n) & 0xffffffffffffffffn;
    let z = state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & 0xffffffffffffffffn;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & 0xffffffffffffffffn;
    z ^= z >> 31n;
    return Number(z >> 11n) / 9007199254740992;
  };

  ctx.strokeStyle = isLight ? 'rgba(19, 20, 28, 0.08)' : 'rgba(255, 255, 255, 0.06)';
  ctx.lineWidth = Math.max(0.9, step * 0.52);
  ctx.lineCap = 'round';
  ctx.beginPath();
  for (let d = 0; d < days; d += 1) {
    const r = inner + step * (d + 0.5);
    ctx.moveTo(cx + r, cy);
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
  }
  ctx.stroke();

  const quiet = isLight ? '#0D998C' : '#52E6DB';
  const moderate = isLight ? '#CC800A' : '#FAC75C';
  const loud = isLight ? '#DB2947' : '#FC5775';

  for (let d = 0; d < days; d += 1) {
    const r = inner + step * (d + 0.5);
    for (let h = 0; h < 24; h += 1) {
      const activeHour = (h >= 8 && h <= 10) || (h >= 18 && h <= 23) || h === 0;
      const prob = activeHour ? 0.68 * dev.density : 0.16 * dev.density;
      if (nextRand() > prob) continue;

      const dbRoll = nextRand();
      const color = dbRoll > 0.84 ? loud : dbRoll > 0.45 ? moderate : quiet;
      const a0 = ((h * 15 - 90 + 1.5) * Math.PI) / 180;
      const a1 = (((h + 1) * 15 - 90 - 1.5) * Math.PI) / 180;

      ctx.strokeStyle = color;
      ctx.globalAlpha = 0.5 + nextRand() * 0.48;
      ctx.lineWidth = step * (0.42 + nextRand() * 0.46);
      ctx.beginPath();
      ctx.arc(cx, cy, r, a0, a1);
      ctx.stroke();
    }
  }
  ctx.globalAlpha = 1;
}

/**
 * Critically-damped 3D spring driver (zeta = 1 -> zero oscillation overshoot, 60fps smooth)
 */
function attachSpring3D(stageEl, options = {}) {
  if (!stageEl) return null;

  const maxHoverX = options.maxHoverX ?? 10;
  const maxHoverY = options.maxHoverY ?? 13;
  const maxDragX = options.maxDragX ?? 24;
  const maxDragY = options.maxDragY ?? 30;
  const stiffness = options.stiffness ?? 155;
  const damping = 2 * Math.sqrt(stiffness);

  const state = {
    rx: 0,
    ry: 0,
    flip: 0,
    lift: 0,
    vrx: 0,
    vry: 0,
    vflip: 0,
    vlift: 0,
    targetRx: 0,
    targetRy: 0,
    targetFlip: 0,
    targetLift: 0,
    isHovering: false,
    isDragging: false,
    isVisible: true,
    dragStartX: 0,
    dragStartY: 0,
    dragMoved: false,
    rafId: 0,
    lastTime: 0,
    idlePhase: 0,
  };

  function writeCssVars() {
    const tx = Math.max(-1.2, Math.min(1.2, state.ry / maxHoverY));
    const ty = Math.max(-1.2, Math.min(1.2, -state.rx / maxHoverX));
    const px = 50 + tx * 34;
    const py = 36 + ty * 30;
    const sheenAngle = 118 + tx * 28 - ty * 14;
    const bevelAngle = 135 + Math.atan2(ty, tx) * (180 / Math.PI) * 0.35;

    stageEl.style.setProperty('--rx', `${state.rx.toFixed(3)}deg`);
    stageEl.style.setProperty('--ry', `${state.ry.toFixed(3)}deg`);
    stageEl.style.setProperty('--flip', `${state.flip.toFixed(3)}deg`);
    stageEl.style.setProperty('--z-lift', `${state.lift.toFixed(2)}px`);
    stageEl.style.setProperty('--tx', tx.toFixed(4));
    stageEl.style.setProperty('--ty', ty.toFixed(4));
    stageEl.style.setProperty('--px', `${px.toFixed(2)}%`);
    stageEl.style.setProperty('--py', `${py.toFixed(2)}%`);
    stageEl.style.setProperty('--sheen-angle', `${sheenAngle.toFixed(2)}deg`);
    stageEl.style.setProperty('--bevel-angle', `${bevelAngle.toFixed(2)}deg`);

    const totalAngle = state.ry + state.flip;
    const showsFront = Math.cos((totalAngle * Math.PI) / 180) > 0;
    const desiredFace = showsFront ? 'front' : 'back';
    if (stageEl.dataset.face !== desiredFace) {
      stageEl.dataset.face = desiredFace;
    }
    if (options.frontFaceEl) {
      options.frontFaceEl.style.opacity = showsFront ? '1' : '0';
      options.frontFaceEl.setAttribute('aria-hidden', String(!showsFront));
    }
    if (options.backFaceEl) {
      options.backFaceEl.style.opacity = showsFront ? '0' : '1';
      options.backFaceEl.setAttribute('aria-hidden', String(showsFront));
    }
  }

  function step(now) {
    state.rafId = 0;
    if (!state.lastTime) state.lastTime = now;
    const dt = Math.min(0.032, Math.max(0.001, (now - state.lastTime) / 1000));
    state.lastTime = now;

    const reduced = prefersReducedMotion();
    if (!state.isHovering && !state.isDragging && !reduced && state.isVisible && !document.hidden) {
      state.idlePhase += dt * 1.15;
      state.targetRy = Math.sin(state.idlePhase) * 2.4;
      state.targetRx = Math.cos(state.idlePhase * 0.8) * 1.6;
    }

    if (reduced) {
      state.rx = state.targetRx;
      state.ry = state.targetRy;
      state.flip = state.targetFlip;
      state.lift = state.targetLift;
      state.vrx = 0;
      state.vry = 0;
      state.vflip = 0;
      state.vlift = 0;
      writeCssVars();
      return;
    }

    const integrate = (val, vel, target) => {
      const acc = stiffness * (target - val) - damping * vel;
      const nextVel = vel + acc * dt;
      const nextVal = val + nextVel * dt;
      return [nextVal, nextVel];
    };

    [state.rx, state.vrx] = integrate(state.rx, state.vrx, state.targetRx);
    [state.ry, state.vry] = integrate(state.ry, state.vry, state.targetRy);
    [state.flip, state.vflip] = integrate(state.flip, state.vflip, state.targetFlip);
    [state.lift, state.vlift] = integrate(state.lift, state.vlift, state.targetLift);

    writeCssVars();

    const settled =
      Math.abs(state.targetRx - state.rx) < 0.02 &&
      Math.abs(state.vrx) < 0.05 &&
      Math.abs(state.targetRy - state.ry) < 0.02 &&
      Math.abs(state.vry) < 0.05 &&
      Math.abs(state.targetFlip - state.flip) < 0.05 &&
      Math.abs(state.vflip) < 0.05 &&
      Math.abs(state.targetLift - state.lift) < 0.05;

    const keepIdleAlive = !reduced && state.isVisible && !document.hidden;
    if (!settled || state.isHovering || state.isDragging || keepIdleAlive) {
      state.rafId = requestAnimationFrame(step);
    } else {
      state.lastTime = 0;
    }
  }

  function wake() {
    if (!state.rafId) {
      state.lastTime = 0;
      state.rafId = requestAnimationFrame(step);
    }
  }

  function setFlipped(flipped) {
    state.targetFlip = flipped ? 180 : 0;
    wake();
  }

  function updateHoverFromPointer(e) {
    const rect = stageEl.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const nx = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    const ny = ((e.clientY - rect.top) / rect.height) * 2 - 1;
    const clampedX = Math.max(-1, Math.min(1, nx));
    const clampedY = Math.max(-1, Math.min(1, ny));
    state.targetRy = clampedX * maxHoverY;
    state.targetRx = -clampedY * maxHoverX;
    state.targetLift = 10;
    wake();
  }

  stageEl.addEventListener('pointerenter', (e) => {
    if (e.pointerType === 'touch') return;
    state.isHovering = true;
    updateHoverFromPointer(e);
  });

  stageEl.addEventListener('pointermove', (e) => {
    if (state.isDragging) {
      const dx = e.clientX - state.dragStartX;
      const dy = e.clientY - state.dragStartY;
      if (Math.hypot(dx, dy) > 6) state.dragMoved = true;
      const rect = stageEl.getBoundingClientRect();
      const normX = Math.max(-1.2, Math.min(1.2, dx / (rect.width * 0.45)));
      const normY = Math.max(-1.2, Math.min(1.2, dy / (rect.height * 0.45)));
      state.targetRy = normX * maxDragY;
      state.targetRx = -normY * maxDragX;
      state.targetLift = 16;
      wake();
    } else if (e.pointerType !== 'touch' && state.isHovering) {
      updateHoverFromPointer(e);
    }
  });

  stageEl.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 || e.target.closest('button, a, input')) return;
    state.isDragging = true;
    state.dragMoved = false;
    state.dragStartX = e.clientX;
    state.dragStartY = e.clientY;
    stageEl.classList.add('is-dragging');
    try {
      stageEl.setPointerCapture(e.pointerId);
    } catch {
      // Ignore synthetic events without active pointerId
    }
    state.targetLift = 14;
    wake();
  });

  const endDrag = (e) => {
    if (!state.isDragging) return;
    const wasMoved = state.dragMoved;
    state.isDragging = false;
    stageEl.classList.remove('is-dragging');
    try {
      if (stageEl.hasPointerCapture?.(e.pointerId)) {
        stageEl.releasePointerCapture(e.pointerId);
      }
    } catch {
      // Ignore
    }
    state.targetRx = 0;
    state.targetRy = 0;
    state.targetLift = state.isHovering ? 10 : 0;
    wake();
    if (!wasMoved && typeof options.onTap === 'function') {
      options.onTap();
    }
  };

  stageEl.addEventListener('pointerup', endDrag);
  stageEl.addEventListener('pointercancel', endDrag);

  stageEl.addEventListener('pointerleave', () => {
    state.isHovering = false;
    if (!state.isDragging) {
      state.targetRx = 0;
      state.targetRy = 0;
      state.targetLift = 0;
      wake();
    }
  });

  stageEl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      if (typeof options.onTap === 'function') options.onTap();
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault();
      state.targetRy = -maxHoverY;
      wake();
    } else if (e.key === 'ArrowRight') {
      e.preventDefault();
      state.targetRy = maxHoverY;
      wake();
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      state.targetRx = maxHoverX;
      wake();
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      state.targetRx = -maxHoverX;
      wake();
    }
  });

  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver(
      (entries) => {
        state.isVisible = entries[0]?.isIntersecting ?? true;
        if (state.isVisible) wake();
      },
      { threshold: 0.05 }
    );
    io.observe(stageEl);
  }

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && state.isVisible) wake();
  });

  writeCssVars();
  wake();

  return { setFlipped, wake };
}

export function initFoilCard() {
  if (didInit) return;
  didInit = true;

  const heroStage = document.getElementById('hero-card-stage');
  const heroFront = document.getElementById('hero-card-front');
  const heroBack = document.getElementById('hero-card-back');
  const flipBtn = document.getElementById('hero-flip-btn');
  const hoursRange = document.getElementById('hero-hours-range');
  const deviceBtns = Array.from(document.querySelectorAll('[data-hero-device]'));
  const tierBtns = Array.from(document.querySelectorAll('[data-hero-tier]'));

  const binderCards = Array.from(document.querySelectorAll('[data-tier-card]'));
  const spotlightEl = document.getElementById('tier-spotlight');
  const psaSlab = document.getElementById('psa-slab');
  const slabFlipBtn = document.getElementById('slab-flip-btn');

  let activeDeviceKey = heroStage?.dataset.device && DEVICES[heroStage.dataset.device] ? heroStage.dataset.device : 'pro2';
  let activeHours = Number(hoursRange?.value ?? heroStage?.dataset.hours ?? DEVICES[activeDeviceKey].defaultHours);
  if (Number.isNaN(activeHours)) activeHours = DEVICES[activeDeviceKey].defaultHours;
  let isHeroFlipped = heroStage?.dataset.face === 'back';
  let activeBinderTierId = TIERS[2].id;
  let isPsaFlipped = psaSlab?.dataset.face === 'back';

  ensureFoilLayers(heroFront, true);
  if (heroBack && !heroBack.querySelector(':scope > .slab-guilloche')) {
    const guilloche = document.createElement('div');
    guilloche.className = 'slab-guilloche';
    guilloche.setAttribute('aria-hidden', 'true');
    heroBack.prepend(guilloche);
    heroBack.classList.add('slab-back-shell');
  }
  binderCards.forEach((btn) => ensureFoilLayers(btn, false));
  if (spotlightEl) ensureFoilLayers(spotlightEl, true);

  let heroSpring = null;
  const toggleHeroFlip = () => {
    isHeroFlipped = !isHeroFlipped;
    heroSpring?.setFlipped(isHeroFlipped);
    syncHeroUI();
  };

  if (heroStage) {
    if (!heroStage.hasAttribute('tabindex')) heroStage.setAttribute('tabindex', '0');
    heroSpring = attachSpring3D(heroStage, {
      frontFaceEl: heroFront,
      backFaceEl: heroBack,
      onTap: toggleHeroFlip,
    });
  }

  let psaSpring = null;
  const psaFront = psaSlab?.querySelector('.psa-slab-front, [data-slab-face="front"]');
  const psaBack = psaSlab?.querySelector('.psa-slab-back, [data-slab-face="back"]');
  const togglePsaFlip = () => {
    isPsaFlipped = !isPsaFlipped;
    psaSpring?.setFlipped(isPsaFlipped);
    if (slabFlipBtn) {
      slabFlipBtn.setAttribute('aria-pressed', String(isPsaFlipped));
    }
    if (psaSlab) {
      psaSlab.dataset.face = isPsaFlipped ? 'back' : 'front';
    }
  };

  if (psaSlab) {
    if (!psaSlab.hasAttribute('tabindex')) psaSlab.setAttribute('tabindex', '0');
    psaSpring = attachSpring3D(psaSlab, {
      maxHoverX: 7,
      maxHoverY: 10,
      frontFaceEl: psaFront,
      backFaceEl: psaBack,
      onTap: togglePsaFlip,
    });
  }

  if (spotlightEl) {
    attachSpring3D(spotlightEl, { maxHoverX: 4, maxHoverY: 6 });
  }

  function syncHeroUI() {
    const lang = getLang();
    const isLight = getResolvedTheme() === 'light';
    const tier = tierForHours(activeHours);
    const nextTier = nextTierOf(tier);
    const dev = DEVICES[activeDeviceKey] || DEVICES.pro2;
    const accent = isLight ? tier.accentLight : tier.accentDark;

    // Broadcast tier tokens to :root & ambient-canvas
    const rootStyle = document.documentElement.style;
    rootStyle.setProperty('--tier-accent', accent);
    rootStyle.setProperty('--tier-glow', tier.glow);
    rootStyle.setProperty('--tier-ink', tier.ink);

    if (heroStage) {
      heroStage.dataset.tier = tier.id;
      heroStage.dataset.device = dev.id;
      heroStage.dataset.hours = String(Math.round(activeHours));
      heroStage.style.setProperty('--tier-accent-local', accent);
      heroStage.style.setProperty('--tier-glow-local', tier.glow);
      heroStage.style.setProperty('--tier-ink-local', tier.ink);
    }

    const tierBadgeEl = document.getElementById('hero-card-tier-badge');
    const artworkEl = document.getElementById('hero-card-artwork');
    const modelEl = document.getElementById('hero-card-model');
    const hoursEl = document.getElementById('hero-card-hours');
    const metaEl = document.getElementById('hero-card-meta');

    if (tierBadgeEl) {
      tierBadgeEl.textContent = lang === 'zh-Hans' ? tier.titleZh : tier.titleEn;
    }
    if (artworkEl && artworkEl.getAttribute('src') !== dev.cutout) {
      artworkEl.setAttribute('src', dev.cutout);
      artworkEl.setAttribute('alt', lang === 'zh-Hans' ? dev.altZh : dev.altEn);
    }
    if (modelEl) modelEl.textContent = dev.model;
    if (hoursEl) hoursEl.textContent = formatHoursMinutes(activeHours, lang);

    const scale = dev.defaultHours > 0 ? Math.max(0.2, activeHours / dev.defaultHours) : 1;
    const scaledSessions = Math.max(1, Math.round(dev.sessions * scale));
    if (metaEl) {
      const leftText = lang === 'zh-Hans' ? `${scaledSessions} 次聆听` : `${scaledSessions} sessions`;
      const rightText = lang === 'zh-Hans' ? `始于 ${dev.since}` : `since ${dev.since}`;
      metaEl.innerHTML = `<span>${leftText}</span><span>${rightText}</span>`;
    }

    // PSA Rear Provenance Slab placeholders
    const grade = computeEarGrade(dev);
    const serialEl = document.getElementById('hero-back-serial');
    const gradeEl = document.getElementById('hero-back-grade');
    const avgDbEl = document.getElementById('hero-back-avg-db') || document.getElementById('hero-back-db');
    const longestEl = document.getElementById('hero-back-longest');
    const monthsEl = document.getElementById('hero-back-months');
    const sessionsEl = document.getElementById('hero-back-sessions');
    const progressEl = document.getElementById('hero-back-progress');
    const glyphEl = document.getElementById('hero-back-glyph');

    if (serialEl) serialEl.textContent = `#${String(dev.serial).padStart(4, '0')} · ${dev.pid}`;
    if (gradeEl) gradeEl.textContent = `${grade.score} ${grade.label}`;
    if (avgDbEl) avgDbEl.textContent = `${dev.avgDb} dB(A)`;
    if (longestEl) longestEl.textContent = formatMinutesCompact(dev.longestMin, lang);
    if (monthsEl) {
      monthsEl.textContent = lang === 'zh-Hans' ? `${dev.activeMonths} 个月` : `${dev.activeMonths} mo`;
    }
    if (sessionsEl) sessionsEl.textContent = String(scaledSessions);

    let progressRatio = 1;
    if (nextTier) {
      const span = Math.max(1, nextTier.minHours - tier.minHours);
      progressRatio = Math.min(1, Math.max(0, (activeHours - tier.minHours) / span));
      const rem = Math.max(1, Math.ceil(nextTier.minHours - activeHours));
      if (progressEl) {
        progressEl.textContent =
          lang === 'zh-Hans'
            ? `距「${nextTier.titleZh}」还差 ${rem.toLocaleString('en-US')}h`
            : `${rem.toLocaleString('en-US')}h to ${nextTier.titleEn}`;
      }
    } else if (progressEl) {
      progressEl.textContent = lang === 'zh-Hans' ? '已达到最高等级 ✦' : 'Max tier reached ✦';
    }
    if (heroStage) {
      heroStage.style.setProperty('--tier-progress', `${Math.round(progressRatio * 100)}%`);
    }

    drawMiniGlyph(glyphEl, dev, isLight);

    // Sync controls
    if (hoursRange && Number(hoursRange.value) !== Math.round(activeHours)) {
      hoursRange.value = String(Math.round(activeHours));
    }
    const hoursValueLabel = document.getElementById('hero-hours-value');
    if (hoursValueLabel) {
      hoursValueLabel.textContent = `${Math.round(activeHours).toLocaleString('en-US')}h`;
    }

    deviceBtns.forEach((btn) => {
      const selected = btn.dataset.heroDevice === activeDeviceKey;
      btn.setAttribute('aria-selected', String(selected));
    });

    tierBtns.forEach((btn) => {
      const pressed = btn.dataset.heroTier === tier.id;
      btn.setAttribute('aria-pressed', String(pressed));
    });

    if (flipBtn) {
      flipBtn.setAttribute('aria-pressed', String(isHeroFlipped));
      flipBtn.setAttribute(
        'aria-label',
        isHeroFlipped
          ? lang === 'zh-Hans'
            ? '翻转回正面卡面'
            : 'Flip to front card face'
          : lang === 'zh-Hans'
            ? '翻转查看背面档案卡'
            : 'Flip to provenance back'
      );
    }

    document.dispatchEvent(
      new CustomEvent('earprint:tierchange', {
        bubbles: true,
        detail: {
          tier: tier.id,
          accent,
          glow: tier.glow,
          ink: tier.ink,
          hours: activeHours,
        },
      })
    );
  }

  function syncBinderSpotlight() {
    const lang = getLang();
    const isLight = getResolvedTheme() === 'light';
    const tier = TIERS.find((t) => t.id === activeBinderTierId) || TIERS[2];
    const accent = isLight ? tier.accentLight : tier.accentDark;

    if (spotlightEl) {
      spotlightEl.dataset.tier = tier.id;
      spotlightEl.style.color = tier.ink;
      spotlightEl.style.setProperty('--tier-glow-local', tier.glow);
      spotlightEl.style.setProperty('--tier-accent-local', accent);
    }

    const titleEl = document.getElementById('tier-spotlight-title');
    const hoursEl = document.getElementById('tier-spotlight-hours');
    const finishEl = document.getElementById('tier-spotlight-finish');
    const taglineEl = document.getElementById('tier-spotlight-tagline');

    if (titleEl) titleEl.textContent = lang === 'zh-Hans' ? tier.titleZh : tier.titleEn;
    if (hoursEl) hoursEl.textContent = `${tier.minHours.toLocaleString('en-US')}h+`;
    if (finishEl) finishEl.textContent = lang === 'zh-Hans' ? tier.finishZh : tier.finishEn;
    if (taglineEl) taglineEl.textContent = lang === 'zh-Hans' ? tier.taglineZh : tier.taglineEn;

    binderCards.forEach((btn) => {
      const id = btn.dataset.tierCard;
      const t = TIERS.find((item) => item.id === id);
      if (t) {
        btn.dataset.tier = t.id;
        btn.style.color = t.ink;
      }
      btn.setAttribute('aria-pressed', String(id === tier.id));
    });
  }

  // Event bindings
  flipBtn?.addEventListener('click', toggleHeroFlip);
  slabFlipBtn?.addEventListener('click', togglePsaFlip);

  hoursRange?.addEventListener('input', () => {
    const maxVal = Number(hoursRange.max) || 2500;
    activeHours = Math.max(0, Math.min(maxVal, Number(hoursRange.value) || 0));
    syncHeroUI();
  });

  deviceBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const key = btn.dataset.heroDevice;
      if (!key || !DEVICES[key]) return;
      activeDeviceKey = key;
      activeHours = DEVICES[key].defaultHours;
      syncHeroUI();
    });
  });

  tierBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const tier = TIERS.find((t) => t.id === btn.dataset.heroTier);
      if (!tier) return;
      activeHours = tier.presetHours;
      activeBinderTierId = tier.id;
      syncHeroUI();
      syncBinderSpotlight();
    });
  });

  binderCards.forEach((btn) => {
    btn.addEventListener('click', () => {
      const tier = TIERS.find((t) => t.id === btn.dataset.tierCard);
      if (!tier) return;
      activeBinderTierId = tier.id;
      syncBinderSpotlight();
    });
  });

  document.addEventListener('earprint:themechange', () => {
    syncHeroUI();
    syncBinderSpotlight();
  });

  document.addEventListener('earprint:langchange', () => {
    syncHeroUI();
    syncBinderSpotlight();
  });

  syncHeroUI();
  syncBinderSpotlight();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => initFoilCard(), { once: true });
} else {
  queueMicrotask(() => initFoilCard());
}
