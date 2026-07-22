/* ============================================================================
 * MicroCR — a tiny, dependency-free, offline OCR engine (from scratch).
 * ----------------------------------------------------------------------------
 * No imported OCR/ML libraries. Pure JS + Canvas. ~15KB, instant startup.
 *
 * It is a *constrained-charset* engine: you tell it which characters and fonts
 * to expect, it renders those glyphs itself (using the browser's font engine)
 * to build a template model, then recognizes unseen images by matching glyphs
 * against those templates. This is what lets it read many fonts without a giant
 * trained network — it "learns" a font simply by being told its name.
 *
 * Pipeline:  grayscale -> adaptive binarize (Sauvola) -> connected-components
 *            -> line grouping -> per-glyph normalize -> nearest-template match.
 *
 * Browser:   window.MicroCR
 * Node:      const {MicroCR, ...primitives} = require('./microcr.js')  (CV
 *            primitives run headless; train()/recognize(canvas) need Canvas)
 *
 * Usage:
 *   const ocr = new MicroCR({
 *     charset: '0123456789/-. JANFEBMARPYULGSOCTNVD',
 *     fonts:   ['Arial','Helvetica','Courier New','Verdana','Georgia'],
 *   });
 *   await ocr.train();                       // one-time, ~50ms
 *   const { text, chars } = ocr.recognize(canvasEl, { roi:{x:.1,y:.4,w:.8,h:.2} });
 * ========================================================================== */
(function (global) {
  'use strict';

  /* ------------------------------------------------------------------ *
   * 1. IMAGE PRIMITIVES                                                 *
   * ------------------------------------------------------------------ */

  // RGBA ImageData -> luminance Float32Array (0..255), Rec.601 weights.
  function toGray(imgData) {
    const { data, width: w, height: h } = imgData;
    const g = new Float32Array(w * h);
    for (let i = 0, p = 0; i < data.length; i += 4, p++) {
      g[p] = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
    }
    return { data: g, w, h };
  }

  // Integral (summed-area) images of value and value^2 — O(1) window stats.
  function integralImages(g, w, h) {
    const W = w + 1;
    const sum = new Float64Array(W * (h + 1));
    const sq = new Float64Array(W * (h + 1));
    for (let y = 0; y < h; y++) {
      let rs = 0, rsq = 0;
      for (let x = 0; x < w; x++) {
        const v = g[y * w + x];
        rs += v; rsq += v * v;
        const i = (y + 1) * W + (x + 1);
        sum[i] = sum[i - W] + rs;
        sq[i] = sq[i - W] + rsq;
      }
    }
    return { sum, sq, W };
  }

  // Sauvola adaptive threshold — robust to uneven lighting / shadows / gradients.
  // Returns Uint8Array where 1 = ink (dark), 0 = background.
  function sauvolaBinarize(g, w, h, opt) {
    opt = opt || {};
    const win = opt.window || Math.max(15, Math.round(Math.min(w, h) * 0.06) | 1);
    const k = opt.k != null ? opt.k : 0.2;
    const R = opt.R || 128;
    const r = win >> 1;
    const { sum, sq, W } = integralImages(g, w, h);
    const bin = new Uint8Array(w * h);
    for (let y = 0; y < h; y++) {
      const y0 = Math.max(0, y - r), y1 = Math.min(h - 1, y + r);
      for (let x = 0; x < w; x++) {
        const x0 = Math.max(0, x - r), x1 = Math.min(w - 1, x + r);
        const area = (x1 - x0 + 1) * (y1 - y0 + 1);
        const A = (y1 + 1) * W + (x1 + 1), B = (y1 + 1) * W + x0;
        const C = y0 * W + (x1 + 1), D = y0 * W + x0;
        const s = sum[A] - sum[B] - sum[C] + sum[D];
        const s2 = sq[A] - sq[B] - sq[C] + sq[D];
        const mean = s / area;
        const std = Math.sqrt(Math.max(0, s2 / area - mean * mean));
        const thr = mean * (1 + k * (std / R - 1));
        bin[y * w + x] = g[y * w + x] < thr ? 1 : 0;
      }
    }
    return bin;
  }

  // Otsu global threshold — best on clean, evenly-lit renders (used in training).
  function otsuBinarize(g, w, h) {
    const hist = new Float64Array(256);
    for (let i = 0; i < g.length; i++) hist[g[i] | 0]++;
    const total = g.length;
    let sumAll = 0; for (let t = 0; t < 256; t++) sumAll += t * hist[t];
    let sumB = 0, wB = 0, max = -1, thr = 127;
    for (let t = 0; t < 256; t++) {
      wB += hist[t]; if (!wB) continue;
      const wF = total - wB; if (!wF) break;
      sumB += t * hist[t];
      const mB = sumB / wB, mF = (sumAll - sumB) / wF;
      const between = wB * wF * (mB - mF) * (mB - mF);
      if (between > max) { max = between; thr = t; }
    }
    // Foreground (ink) = intensity ≤ threshold: pixels exactly at the dark
    // cluster's value belong to it (Otsu partitions as [0..t] and [t+1..255]).
    const bin = new Uint8Array(g.length);
    for (let i = 0; i < g.length; i++) bin[i] = g[i] <= thr ? 1 : 0;
    return bin;
  }

  /* ------------------------------------------------------------------ *
   * 2. CONNECTED COMPONENTS (two-pass union-find, 8-connectivity)       *
   * ------------------------------------------------------------------ */

  function connectedComponents(bin, w, h) {
    const labels = new Int32Array(w * h).fill(0);
    const parent = [0];
    const find = (x) => { while (parent[x] !== x) { parent[x] = parent[parent[x]]; x = parent[x]; } return x; };
    const union = (a, b) => { a = find(a); b = find(b); if (a !== b) parent[Math.max(a, b)] = Math.min(a, b); };
    let next = 1;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (!bin[y * w + x]) continue;
        // neighbours already visited: W, NW, N, NE
        const nb = [];
        if (x > 0 && labels[y * w + x - 1]) nb.push(labels[y * w + x - 1]);
        if (y > 0) {
          if (labels[(y - 1) * w + x]) nb.push(labels[(y - 1) * w + x]);
          if (x > 0 && labels[(y - 1) * w + x - 1]) nb.push(labels[(y - 1) * w + x - 1]);
          if (x < w - 1 && labels[(y - 1) * w + x + 1]) nb.push(labels[(y - 1) * w + x + 1]);
        }
        if (!nb.length) { parent[next] = next; labels[y * w + x] = next++; }
        else {
          const m = Math.min.apply(null, nb);
          labels[y * w + x] = m;
          for (const n of nb) union(m, n);
        }
      }
    }
    // second pass: flatten labels + collect component bounds
    const remap = new Map();
    const comps = [];
    for (let i = 0; i < labels.length; i++) {
      if (!labels[i]) continue;
      const root = find(labels[i]);
      let idx = remap.get(root);
      if (idx === undefined) {
        idx = comps.length;
        remap.set(root, idx);
        comps.push({ label: idx + 1, x0: w, y0: h, x1: -1, y1: -1, area: 0 });
      }
      labels[i] = idx + 1;
      const c = comps[idx], x = i % w, y = (i / w) | 0;
      if (x < c.x0) c.x0 = x; if (x > c.x1) c.x1 = x;
      if (y < c.y0) c.y0 = y; if (y > c.y1) c.y1 = y;
      c.area++;
    }
    for (const c of comps) { c.w = c.x1 - c.x0 + 1; c.h = c.y1 - c.y0 + 1; }
    return { labels, comps };
  }

  // Drop specks and oversized blobs; keep components near the median glyph height.
  function filterComponents(comps, imgH) {
    if (!comps.length) return comps;
    const heights = comps.map(c => c.h).sort((a, b) => a - b);
    const med = heights[heights.length >> 1];
    return comps.filter(c =>
      c.area >= 6 &&
      c.h >= Math.max(6, med * 0.35) && c.h <= med * 2.6 &&
      c.h <= imgH * 0.95 && c.w <= imgH * 3 &&        // reject page-spanning blobs
      c.w >= 2
    );
  }

  // Group components into text lines (by vertical overlap), order L→R, then lines T→B.
  function orderIntoLines(comps) {
    const sorted = comps.slice().sort((a, b) => a.y0 - b.y0);
    const lines = [];
    for (const c of sorted) {
      const cy = (c.y0 + c.y1) / 2;
      let line = lines.find(L => cy >= L.top && cy <= L.bot);
      if (!line) { line = { top: c.y0, bot: c.y1, items: [] }; lines.push(line); }
      line.items.push(c);
      line.top = Math.min(line.top, c.y0);
      line.bot = Math.max(line.bot, c.y1);
    }
    lines.sort((a, b) => a.top - b.top);
    for (const L of lines) L.items.sort((a, b) => a.x0 - b.x0);
    return lines;
  }

  /* ------------------------------------------------------------------ *
   * 3. GLYPH NORMALIZATION + FEATURES                                  *
   * ------------------------------------------------------------------ */

  // Extract a single component's pixels into a tight 0/255 bitmap.
  function cropGlyph(labels, w, comp) {
    const cw = comp.w, ch = comp.h, out = new Uint8Array(cw * ch);
    for (let y = 0; y < ch; y++)
      for (let x = 0; x < cw; x++)
        if (labels[(comp.y0 + y) * w + (comp.x0 + x)] === comp.label)
          out[y * cw + x] = 255;
    return { data: out, w: cw, h: ch };
  }

  // Aspect-preserving area-resample into a size×size grayscale grid, centered.
  // Anti-aliased coverage (not hard binary) → far more discriminative for matching.
  function normalizeGlyph(bmp, size) {
    const { data, w, h } = bmp;
    const grid = new Float32Array(size * size);
    const margin = 0.10;                       // keep a small border
    const target = size * (1 - 2 * margin);
    const scale = target / Math.max(w, h);
    const dw = w * scale, dh = h * scale;
    const ox = (size - dw) / 2, oy = (size - dh) / 2;
    // For each destination cell, average the source region mapping to it.
    for (let gy = 0; gy < size; gy++) {
      for (let gx = 0; gx < size; gx++) {
        const sx0 = (gx - ox) / scale, sy0 = (gy - oy) / scale;
        const sx1 = (gx + 1 - ox) / scale, sy1 = (gy + 1 - oy) / scale;
        const ix0 = Math.max(0, Math.floor(sx0)), iy0 = Math.max(0, Math.floor(sy0));
        const ix1 = Math.min(w, Math.ceil(sx1)), iy1 = Math.min(h, Math.ceil(sy1));
        let acc = 0, n = 0;
        for (let sy = iy0; sy < iy1; sy++)
          for (let sx = ix0; sx < ix1; sx++) { acc += data[sy * w + sx]; n++; }
        grid[gy * size + gx] = n ? acc / (255 * n) : 0;
      }
    }
    return grid;
  }

  // Feature vector = normalized grid + row/col projection profiles, L2-normalized
  // so matching uses cosine similarity (scale-invariant to stroke weight).
  function featureVector(grid, size) {
    const rows = new Float32Array(size), cols = new Float32Array(size);
    for (let y = 0; y < size; y++)
      for (let x = 0; x < size; x++) {
        const v = grid[y * size + x]; rows[y] += v; cols[x] += v;
      }
    const feat = new Float32Array(grid.length + 2 * size);
    feat.set(grid, 0);
    feat.set(rows, grid.length);
    feat.set(cols, grid.length + size);
    let norm = 0; for (let i = 0; i < feat.length; i++) norm += feat[i] * feat[i];
    norm = Math.sqrt(norm) || 1;
    for (let i = 0; i < feat.length; i++) feat[i] /= norm;
    return feat;
  }

  function cosine(a, b) { let s = 0; for (let i = 0; i < a.length; i++) s += a[i] * b[i]; return s; }

  /* ------------------------------------------------------------------ *
   * 4. THE ENGINE                                                      *
   * ------------------------------------------------------------------ */

  class MicroCR {
    constructor(opt) {
      opt = opt || {};
      this.charset = (opt.charset || '0123456789/-.: ').replace(/\s+/g, ' ');
      this.fonts = opt.fonts || ['Arial', 'Helvetica', 'Verdana', 'Courier New', 'Georgia', 'Times New Roman'];
      this.weights = opt.weights || ['normal', 'bold'];
      this.gridSize = opt.gridSize || 24;
      this.renderPx = opt.renderPx || 96;
      this.minConfidence = opt.minConfidence != null ? opt.minConfidence : 0.72;
      this.templates = [];          // {char, vec}
      this.trained = false;
    }

    _canvas(w, h) {
      const c = (typeof OffscreenCanvas !== 'undefined')
        ? new OffscreenCanvas(w, h)
        : (typeof document !== 'undefined' ? document.createElement('canvas') : null);
      if (!c) throw new Error('MicroCR: no Canvas available in this environment');
      c.width = w; c.height = h;
      return c;
    }

    // Render every char in every font/weight, extract a template feature vector.
    async train() {
      if (typeof document !== 'undefined' && document.fonts && document.fonts.ready) {
        try { await document.fonts.ready; } catch (e) {}
      }
      const px = this.renderPx, pad = px, dim = px + 2 * pad;
      const cv = this._canvas(dim, dim), ctx = cv.getContext('2d');
      this.templates = [];
      for (const ch of this.charset) {
        if (ch === ' ') continue;
        for (const font of this.fonts) {
          for (const weight of this.weights) {
            ctx.clearRect(0, 0, dim, dim);
            ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, dim, dim);
            ctx.fillStyle = '#000';
            ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
            ctx.font = `${weight} ${px}px ${font}`;
            ctx.fillText(ch, dim / 2, dim / 2);
            const vec = this._glyphFeatureFromCanvas(ctx, dim, dim, true);
            if (vec) this.templates.push({ char: ch, vec });
          }
        }
      }
      this.trained = true;
      return this;
    }

    // Isolate the largest component in a canvas region and vectorize it.
    _glyphFeatureFromCanvas(ctx, w, h, clean) {
      const img = ctx.getImageData(0, 0, w, h);
      const gray = toGray(img);
      const bin = clean ? otsuBinarize(gray.data, w, h)
        : sauvolaBinarize(gray.data, w, h);
      const { labels, comps } = connectedComponents(bin, w, h);
      if (!comps.length) return null;
      comps.sort((a, b) => b.area - a.area);
      const g = normalizeGlyph(cropGlyph(labels, w, comps[0]), this.gridSize);
      return featureVector(g, this.gridSize);
    }

    _classify(vec) {
      let best = -2, second = -2, bestChar = '?';
      for (const t of this.templates) {
        const s = cosine(vec, t.vec);
        if (s > best) { second = best; best = s; bestChar = t.char; }
        else if (s > second) second = s;
      }
      return { char: bestChar, score: best, margin: best - second };
    }

    // source: HTMLCanvasElement | ImageData | HTMLImageElement | OffscreenCanvas
    // roi: optional fractional crop {x,y,w,h} in 0..1
    recognize(source, opt) {
      if (!this.trained) throw new Error('MicroCR: call train() before recognize()');
      opt = opt || {};
      const img = this._toImageData(source, opt.roi);
      const gray = toGray(img);
      const bin = sauvolaBinarize(gray.data, img.width, img.height, opt);
      const cc = connectedComponents(bin, img.width, img.height);
      const kept = filterComponents(cc.comps, img.height);
      const lines = orderIntoLines(kept);

      const chars = [], out = [];
      for (const line of lines) {
        let prevX1 = null, medW = median(line.items.map(c => c.w)) || 1;
        for (const c of line.items) {
          // insert a space on a wide gap between glyphs
          if (prevX1 != null && c.x0 - prevX1 > medW * 0.9) out.push(' ');
          prevX1 = c.x1;
          const vec = featureVector(normalizeGlyph(cropGlyph(cc.labels, img.width, c), this.gridSize), this.gridSize);
          const r = this._classify(vec);
          const ch = r.score >= this.minConfidence ? r.char : '?';
          out.push(ch);
          chars.push({ char: ch, conf: +r.score.toFixed(3), margin: +r.margin.toFixed(3),
            box: { x: c.x0, y: c.y0, w: c.w, h: c.h } });
        }
        out.push('\n');
      }
      return { text: out.join('').replace(/[ \t]+\n/g, '\n').trim(), chars };
    }

    _toImageData(source, roi) {
      let w, h, draw;
      if (typeof ImageData !== 'undefined' && source instanceof ImageData) {
        if (!roi) return source;
        w = source.width; h = source.height;
        const tmp = this._canvas(w, h); tmp.getContext('2d').putImageData(source, 0, 0);
        source = tmp; draw = true;
      }
      w = source.width; h = source.height;
      const rx = roi ? Math.round(roi.x * w) : 0, ry = roi ? Math.round(roi.y * h) : 0;
      const rw = roi ? Math.round(roi.w * w) : w, rh = roi ? Math.round(roi.h * h) : h;
      const cv = this._canvas(rw, rh), ctx = cv.getContext('2d');
      ctx.drawImage(source, rx, ry, rw, rh, 0, 0, rw, rh);
      return ctx.getImageData(0, 0, rw, rh);
    }
  }

  function median(arr) {
    if (!arr.length) return 0;
    const s = arr.slice().sort((a, b) => a - b);
    return s[s.length >> 1];
  }

  /* ------------------------------------------------------------------ */
  const api = {
    MicroCR, toGray, integralImages, sauvolaBinarize, otsuBinarize,
    connectedComponents, filterComponents, orderIntoLines,
    cropGlyph, normalizeGlyph, featureVector, cosine, median,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  global.MicroCR = MicroCR;
  global.MicroCRlib = api;
})(typeof self !== 'undefined' ? self : this);
