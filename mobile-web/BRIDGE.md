# Bundled iPhone integration

Entry: mobile-web/index.html. Bundle this entire directory including vendor and assets. No website/backend deployment.

Native bridge: window.webkit.messageHandlers.native.postMessage({id,action,...payload}); finish once via window.nativeReply(id,result,error), error null/string. JS Native.call returns a Promise, rejects unavailable/timeouts/native errors.

Actions:
- camera {purpose:'expiry'|'barcode'} -> {image:JPEG data URL} for expiry, {barcode:string} for barcode. AVFoundation owns preview/capture/torch; cancellation rejects with a clear cancellation message. JS never calls getUserMedia and does not auto-present camera on tab selection. Capture/Retake explicitly launch it. Barcode result is displayed/staged without any network product lookup. Returning an image for purpose barcode is NOT sufficient (JS does not pretend OCR is barcode recognition).
- ocr {image:dataURL} -> {text:string}; Apple Vision on-device only, either mode.
- export {name,data:base64} -> {completed:bool}; completed=false means user cancelled, not success. Supported exports: real UTF-8 `.csv` item rows and `.json` photo backups, never XLSX. Decoded byte ceiling is 20 MiB (20,971,520 bytes), inclusive. Web `transfer.mjs` enforces the same limit on Blob.size before base64 and on import file/serialized bytes.
- request {url,method,headers,body:base64|null} -> {status,headers,body:base64}. Only https://viupqrjyszvvcpnxrmsq.supabase.co allowed. Deny redirects, foreign callers, unsupported schemes/methods. HTTP errors return status; transport errors reject. No OpenFoodFacts or OCR endpoint required.

Persistent WKWebsiteDataStore required; stable local bundle origin and app identity required for IndexedDB across upgrades. JS blocks external browser requests using CSP; cloud HTTP goes exclusively through native request. Native must independently validate trusted bundle origin and destination.

Mode selection persists in localStorage (only tiny mode value); content/photos/settings are IndexedDB. Switching mode flushes pending writes then reloads, never mutates active scope. Local has no identity. Cloud account changes reload to immutable per-account storage scope. No automatic copying. JSON export includes photos; import replaces LOCAL dataset atomically after validation and explicit confirmation; cloud import is intentionally not offered.

BLOCKER: original index.html anon key is literal placeholder eyJhbG...G7qk. Cloud must fail with configuration error until a real public anon/publishable key is set in config.js. Never use service-role/secret keys. Native compile/install does not verify cloud login/sync.
