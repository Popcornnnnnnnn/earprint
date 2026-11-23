/**
 * Earprint Ambient Acoustic Field Canvas
 * - Whisper-quiet architectural concentric acoustic contours + depth field
 * - Harmonizes smoothly with Dark/Light theme and active foil tier accent
 * - Auto-pauses via IntersectionObserver & document.hidden; static under prefers-reduced-motion
 */

let didInit = false;

function getResolvedTheme() {
  if (window.earprintState?.getTheme) {
    const t = window.earprintState.getTheme();
    const resolved = typeof t === 'string' ? t : t?.resolved || t?.theme;
    if (resolved === 'light' || resolved === 'dark') return resolved;
  }
  const ds = document.documentElement.dataset.resolvedTheme;
  if (ds === 'light' || ds === 'dark') return ds;
  return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
}

function parseHexToRgb(hex) {
  if (!hex || typeof hex !== 'string') return null;
  const clean = hex.trim().replace('#', '');
  if (clean.length === 3) {
    const r = parseInt(clean[0] + clean[0], 16);
    const g = parseInt(clean[1] + clean[1], 16);
    const b = parseInt(clean[2] + clean[2], 16);
    return Number.isNaN(r) ? null : [r, g, b];
  }
  if (clean.length === 6) {
    const r = parseInt(clean.slice(0, 2), 16);
    const g = parseInt(clean.slice(2, 4), 16);
    const b = parseInt(clean.slice(4, 6), 16);
    return Number.isNaN(r) ? null : [r, g, b];
  }
  return null;
}

function parseCssColorToRgb(value) {
  if (!value) return null;
  const hex = parseHexToRgb(value);
  if (hex) return hex;
  const m = value.match(/rgba?\(\s*([\d.]+)\s*[,\s]\s*([\d.]+)\s*[,\s]\s*([\d.]+)/i);
  if (m) return [Number(m[1]), Number(m[2]), Number(m[3])];
  return null;
}

function prefersReducedMotion() {
  return window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
}

export function initAmbientCanvas() {
  if (didInit) return;
  didInit = true;

  const canvas =
    document.getElementById('ambient-canvas') ||
    document.getElementById('ambient-field-canvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  let width = window.innerWidth;
  let height = window.innerHeight;
  let dpr = Math.min(window.devicePixelRatio || 1, 1.5);
  let rafId = 0;
  let lastTime = 0;
  let phase = 0;
  let isVisible = true;
  let smoothScroll = window.scrollY || 0;
  let targetScroll = smoothScroll;
  let pointerX = 0.5;
  let pointerY = 0.35;

  let currentAccent = [126, 176, 189];
  let targetAccent = [126, 176, 189];

  // Deterministic subtle acoustic field micro-nodes (32 lightweight points)
  const nodes = Array.from({ length: 32 }, (_, i) => {
    const angle = (i / 32) * Math.PI * 2 + (i % 3) * 0.41;
    const radius = 0.24 + ((i * 19) % 37) / 48;
    const speed = 0.08 + ((i * 7) % 13) * 0.012;
    return { angle, radius, speed, size: 1 + (i % 3) * 0.45 };
  });

  function readAccentFromDom(detailAccent) {
    const raw =
      detailAccent ||
      window.getComputedStyle?.(document.documentElement)?.getPropertyValue('--tier-accent')?.trim();
    const parsed = parseCssColorToRgb(raw);
    if (parsed) {
      targetAccent = parsed;
    } else {
      targetAccent = getResolvedTheme() === 'light' ? [36, 110, 125] : [126, 176, 189];
    }
  }

  function resize() {
    width = Math.max(320, window.innerWidth);
    height = Math.max(320, window.innerHeight);
    dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
  }

  function drawStaticOrAnimatedFrame() {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, width, height);

    const isLight = getResolvedTheme() === 'light';
    const [r, g, b] = currentAccent.map((c) => Math.round(c));
    const quietRgb = isLight ? [13, 153, 140] : [82, 230, 219];

    const maxScroll = Math.max(1, document.documentElement.scrollHeight - height);
    const scrollRatio = Math.min(1, Math.max(0, smoothScroll / maxScroll));

    // Anchor acoustic chronometer center near upper-right behind hero, drifting subtly on scroll
    const cx = width * (0.72 - scrollRatio * 0.22 + (pointerX - 0.5) * 0.03);
    const cy = height * (0.38 - scrollRatio * 0.12 + (pointerY - 0.35) * 0.03);
    const baseRadius = Math.min(width, height) * 0.22;

    // 1. Subtle architectural radial illumination (very low alpha, zero SaaS glow blob)
    const radial = ctx.createRadialGradient(cx, cy, baseRadius * 0.1, cx, cy, baseRadius * 3.1);
    radial.addColorStop(0, `rgba(${r}, ${g}, ${b}, ${isLight ? 0.055 : 0.075})`);
    radial.addColorStop(0.55, `rgba(${quietRgb[0]}, ${quietRgb[1]}, ${quietRgb[2]}, ${isLight ? 0.02 : 0.03})`);
    radial.addColorStop(1, 'transparent');
    ctx.fillStyle = radial;
    ctx.fillRect(0, 0, width, height);

    // 2. Whisper-quiet concentric acoustic wave contours (broken horological arcs)
    const ringCount = 6;
    ctx.lineCap = 'round';
    for (let i = 0; i < ringCount; i += 1) {
      const radius = baseRadius * (0.65 + i * 0.42);
      const wobble = Math.sin(phase * 0.45 + i * 0.9) * 0.06;
      const startAngle = phase * (i % 2 === 0 ? 0.055 : -0.042) + i * 0.85 + scrollRatio * 1.4;
      const span = Math.PI * (1.25 - i * 0.08 + wobble);
      const alpha = (isLight ? 0.065 : 0.085) * (1 - i / (ringCount + 1.5));

      ctx.strokeStyle =
        i % 2 === 0
          ? `rgba(${r}, ${g}, ${b}, ${alpha})`
          : isLight
            ? `rgba(19, 20, 28, ${alpha * 0.65})`
            : `rgba(255, 255, 255, ${alpha * 0.55})`;
      ctx.lineWidth = i === 0 ? 1.15 : 0.85;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, startAngle, startAngle + span);
      ctx.stroke();

      // Counter-arc micro segment
      ctx.strokeStyle = `rgba(${quietRgb[0]}, ${quietRgb[1]}, ${quietRgb[2]}, ${alpha * 0.55})`;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, startAngle + span + 0.35, startAngle + span + 0.72);
      ctx.stroke();
    }

    // 3. Delicate floating harmonic micro-particles along outer acoustic field
    const fieldRadius = Math.max(width, height) * 0.68;
    for (let i = 0; i < nodes.length; i += 1) {
      const n = nodes[i];
      const ang = n.angle + phase * n.speed * 0.16 + scrollRatio * 0.45;
      const px = cx + Math.cos(ang) * fieldRadius * n.radius;
      const py = cy + Math.sin(ang) * fieldRadius * n.radius * 0.86;
      if (px < -10 || px > width + 10 || py < -10 || py > height + 10) continue;

      const pulse = 0.45 + 0.55 * Math.sin(phase * 0.9 + i);
      const nodeAlpha = (isLight ? 0.09 : 0.14) * pulse;
      ctx.fillStyle =
        i % 3 === 0
          ? `rgba(${r}, ${g}, ${b}, ${nodeAlpha})`
          : isLight
            ? `rgba(19, 20, 28, ${nodeAlpha * 0.6})`
            : `rgba(255, 255, 255, ${nodeAlpha * 0.7})`;
      ctx.beginPath();
      ctx.arc(px, py, n.size, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function step(now) {
    rafId = 0;
    if (!isVisible || document.hidden) return;
    if (!lastTime) lastTime = now;
    const dt = Math.min(0.05, Math.max(0.001, (now - lastTime) / 1000));
    lastTime = now;

    // Smoothly interpolate accent RGB & scroll position
    const blend = Math.min(1, dt * 4.5);
    currentAccent = [
      currentAccent[0] + (targetAccent[0] - currentAccent[0]) * blend,
      currentAccent[1] + (targetAccent[1] - currentAccent[1]) * blend,
      currentAccent[2] + (targetAccent[2] - currentAccent[2]) * blend,
    ];
    smoothScroll += (targetScroll - smoothScroll) * Math.min(1, dt * 6);

    const reduced = prefersReducedMotion();
    if (!reduced) {
      phase += dt;
    }

    drawStaticOrAnimatedFrame();

    if (!reduced) {
      rafId = requestAnimationFrame(step);
    } else {
      lastTime = 0;
    }
  }

  function wake() {
    if (prefersReducedMotion()) {
      currentAccent = targetAccent.slice();
      smoothScroll = targetScroll;
      drawStaticOrAnimatedFrame();
      return;
    }
    if (!rafId && isVisible && !document.hidden) {
      lastTime = 0;
      rafId = requestAnimationFrame(step);
    }
  }

  window.addEventListener(
    'scroll',
    () => {
      targetScroll = window.scrollY || 0;
      if (prefersReducedMotion()) {
        smoothScroll = targetScroll;
        drawStaticOrAnimatedFrame();
      }
    },
    { passive: true }
  );

  window.addEventListener(
    'pointermove',
    (e) => {
      if (e.pointerType === 'touch') return;
      pointerX = e.clientX / Math.max(1, width);
      pointerY = e.clientY / Math.max(1, height);
    },
    { passive: true }
  );

  window.addEventListener(
    'resize',
    () => {
      resize();
      drawStaticOrAnimatedFrame();
    },
    { passive: true }
  );

  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver(
      (entries) => {
        isVisible = entries[0]?.isIntersecting ?? true;
        if (isVisible) wake();
      },
      { threshold: 0.01 }
    );
    io.observe(canvas);
  }

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && isVisible) wake();
  });

  document.addEventListener('earprint:themechange', () => {
    readAccentFromDom();
    if (prefersReducedMotion()) currentAccent = targetAccent.slice();
    drawStaticOrAnimatedFrame();
  });

  document.addEventListener('earprint:tierchange', (e) => {
    readAccentFromDom(e.detail?.accent);
    if (prefersReducedMotion()) {
      currentAccent = targetAccent.slice();
      drawStaticOrAnimatedFrame();
    }
  });

  const motionQuery = window.matchMedia?.('(prefers-reduced-motion: reduce)');
  motionQuery?.addEventListener?.('change', () => {
    if (motionQuery.matches && rafId) {
      cancelAnimationFrame(rafId);
      rafId = 0;
    }
    wake();
  });

  resize();
  readAccentFromDom();
  currentAccent = targetAccent.slice();
  drawStaticOrAnimatedFrame();
  wake();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => initAmbientCanvas(), { once: true });
} else {
  queueMicrotask(() => initAmbientCanvas());
}
