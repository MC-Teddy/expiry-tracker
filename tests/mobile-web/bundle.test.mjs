import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
test('bundle contains no remote assets, browser camera, photo localStorage, cloud OCR or service worker',()=>{
 const html=readFileSync(new URL('../../mobile-web/index.html',import.meta.url),'utf8'),app=readFileSync(new URL('../../mobile-web/app.js',import.meta.url),'utf8');
 assert.doesNotMatch(html,/(?:src|href)=["']https?:/);assert.doesNotMatch(app,/getUserMedia|expiry_images|vision-ocr|Tesseract|serviceWorker|https:\/\/world.openfoodfacts/);
 assert.match(html,/connect-src 'none'/);assert.match(html,/assets\/Archivo.ttf/);
});
