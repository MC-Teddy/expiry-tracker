# MicroCR — a from-scratch, dependency-free OCR engine

MicroCR is a tiny (~15 KB), zero-dependency OCR engine written from scratch in
plain JavaScript + Canvas. **No imported OCR or ML libraries.** It is designed
for *constrained-charset* recognition (expiry dates, serial numbers, license
plates, meter readings, price tags) where it can be **faster, smaller, and
instant-to-start** compared with general engines like Tesseract (~10 MB model,
slow cold start).

It reads many fonts without shipping a trained neural network by using a trick:
**it renders the target charset in fonts you name, at runtime, and matches
captured glyphs against those self-generated templates.** You teach it a font
just by passing the font name.

> Honest scope: MicroCR will *not* beat a trained deep model (Tesseract LSTM,
> PaddleOCR, TrOCR) on arbitrary/unknown/handwritten fonts — that capability
> comes from training on millions of samples. MicroCR wins on **small charsets,
> known fonts, zero footprint, and startup speed.** See "Roadmap" for how to
> push it toward the hard cases.

---

## Quick start

```html
<script src="microcr.js"></script>
<script>
  const ocr = new MicroCR({
    charset: '0123456789/-.: ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    fonts:   ['Arial', 'Verdana', 'Courier New', 'Georgia'],
  });
  await ocr.train();                        // one-time, ~50ms

  const { text, chars } = ocr.recognize(canvasEl, {
    roi: { x: 0.1, y: 0.4, w: 0.8, h: 0.2 } // optional fractional crop
  });
  // text  -> "EXP 31 DEC 2027"
  // chars -> [{ char:'E', conf:0.94, margin:0.11, box:{x,y,w,h} }, ...]
</script>
```

Open **`microcr-demo.html`** to see it read text rendered in fonts it was never
trained on, with live per-character confidence and timing.

---

## API

### `new MicroCR(options)`

| option          | default                              | meaning |
|-----------------|--------------------------------------|---------|
| `charset`       | `'0123456789/-.: '`                  | characters it can output |
| `fonts`         | 6 common system fonts                | fonts to render templates from |
| `weights`       | `['normal','bold']`                  | font weights per template |
| `gridSize`      | `24`                                 | glyph normalization grid (N×N) |
| `renderPx`      | `96`                                 | template render size |
| `minConfidence` | `0.72`                               | below this a glyph becomes `'?'` |

### `await ocr.train()`
Renders every char × font × weight and stores a feature vector per template.
Call once (idempotent). Needs a Canvas (browser / OffscreenCanvas).

### `ocr.recognize(source, { roi, window, k })`
`source` = `HTMLCanvasElement | ImageData | HTMLImageElement | OffscreenCanvas`.
Returns `{ text, chars }`. `window`/`k` tune the Sauvola binarizer.

### Exposed primitives (also usable standalone / in Node)
`toGray, sauvolaBinarize, otsuBinarize, connectedComponents, filterComponents,
orderIntoLines, cropGlyph, normalizeGlyph, featureVector, cosine`.

---

## How it works (the pipeline)

```
RGBA image
  │  toGray               Rec.601 luminance
  ▼
grayscale
  │  sauvolaBinarize      adaptive local threshold (integral images, O(1)/px)
  ▼                       → robust to shadows / uneven lighting / gradients
binary (ink=1)
  │  connectedComponents  two-pass union-find, 8-connectivity
  ▼
components (bounding boxes)
  │  filterComponents     drop specks & page-spanning blobs by median height
  │  orderIntoLines       group by vertical overlap, sort L→R then T→B
  ▼
ordered glyphs
  │  cropGlyph            isolate each component's own pixels
  │  normalizeGlyph       aspect-preserving area-resample to 24×24, centered,
  │                       anti-aliased (grayscale coverage, not hard binary)
  │  featureVector        grid + row/col projection profiles, L2-normalized
  ▼
feature vectors
  │  cosine vs templates  nearest-template match; confidence = best score,
  ▼                       margin = best − 2nd-best
text + per-char confidence
```

Why these choices:
- **Sauvola over global threshold** — the single biggest accuracy lever on real
  photos; a global threshold dies on shadows and glare.
- **Integral images** — window mean/variance in O(1) per pixel, so adaptive
  binarization is fast even on full-frame photos.
- **Anti-aliased normalization + cosine** — grayscale coverage keeps sub-pixel
  stroke shape; L2-normalization makes matching invariant to stroke weight, so
  bold vs regular of the same font still matches.
- **Self-rendered multi-font templates** — generalization to unseen fonts comes
  from covering the *style space*, not from a trained net.

---

## Roadmap — how to make it read genuinely difficult fonts

Ordered by payoff. This is the honest path from "good on constrained charsets"
toward "reads hard fonts," staying as close to from-scratch as you want.

1. **More & better templates (cheap, big win).** Add fonts, weights, italics,
   and light augmentation per template: ±3° rotation, slight shear, dilation/
   erosion (stroke-weight jitter), and Gaussian blur. This widens the style
   space each glyph is matched against. Pure Canvas, no new deps.

2. **Better features than raw pixels.** Add Histogram-of-Oriented-Gradients
   (HOG) or a Zernike/central-moment descriptor. HOG captures stroke direction
   and is markedly more font-robust than pixel grids. Still hand-writable.

3. **k-NN → learned prototype / linear classifier.** Replace nearest-template
   with a small learned model: average templates into class prototypes, or train
   a one-layer softmax (logistic regression) on the feature vectors. You can
   train it in-browser with plain gradient descent — no library.

4. **Segmentation-free line recognition.** Connected-components fails on touching
   or broken glyphs (dot-matrix, cursive). The real fix is a sliding-window +
   sequence model (CTC) over the whole line. That is the step where a small
   **trained CNN/RNN with exported weights** becomes worth it — you'd still ship
   pure-JS *inference* (a few matmuls), just with offline-trained weights.

5. **Contrast/geometry pre-correction.** Deskew via projection-profile variance,
   perspective-correct via the largest quadrilateral, and CLAHE-style local
   contrast before binarizing. Big gains on curved packaging and angled shots.

6. **Domain post-processing (do this now, always).** For dates, a format grammar
   that reconciles `O↔0`, `I/l↔1`, `S↔5`, `B↔8` inside numeric runs recovers
   many near-misses for free. Constrained output is your biggest accuracy
   multiplier and costs almost nothing.

The realistic ceiling: steps 1–3 + 5–6 make a *superb constrained-domain* engine
that stays tiny and offline. Step 4 is where "any difficult font" actually lives,
and it fundamentally requires trained weights — at that point the honest move is
pure-JS inference over an offline-trained model, not a hand-tuned algorithm.

---

## Files
- `microcr.js` — the engine (browser global `MicroCR`; Node `require` for primitives)
- `microcr-demo.html` — interactive demo / accuracy benchmark
- `microcr-README.md` — this file
