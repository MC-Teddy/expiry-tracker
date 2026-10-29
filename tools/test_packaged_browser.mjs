// Smoke-test GENERATED Web resources, never the canonical mobile-web tree.
// Usage: node tools/test_packaged_browser.mjs <generated-or-bundled-Web>
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createServer} from 'node:http';
import {readFile, realpath} from 'node:fs/promises';
import {resolve, relative, extname, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
const require = createRequire(new URL('../tests/mobile-web/package.json', import.meta.url));
const {chromium} = require('playwright');
assert.ok(process.argv[2], 'Pass a generated or bundled Web directory');
const root = await realpath(resolve(process.argv[2]));
const canonical = await realpath(fileURLToPath(new URL('../mobile-web/', import.meta.url)));
assert.notEqual(root, canonical, 'Refusing canonical mobile-web: generate resources first');
await readFile(resolve(root, 'index.html'));
const mime = {'.html':'text/html', '.mjs':'text/javascript', '.js':'text/javascript', '.css':'text/css', '.ttf':'font/ttf', '.woff2':'font/woff2', '.svg':'image/svg+xml', '.png':'image/png'};
const server = createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const target = await realpath(resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname)));
    const rel = relative(root, target);
    if (rel === '..' || rel.startsWith('..' + sep)) throw Error('outside root');
    res.setHeader('Content-Type', mime[extname(target)] || 'application/octet-stream');
    res.end(await readFile(target));
  } catch { res.writeHead(404); res.end('not found'); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({channel:'msedge', headless:true});
  const context = await browser.newContext({viewport:{width:390, height:844}});
  const page = await context.newPage();
  const errors = [], failed = [], external = [], loaded = new Set();
  const origin = 'http://127.0.0.1:' + server.address().port;
  page.on('pageerror', e => errors.push(e.message));
  page.on('requestfailed', r => failed.push(r.url() + ': ' + r.failure()?.errorText));
  page.on('response', r => {
    if (r.status() >= 400) failed.push(r.status() + ': ' + r.url());
    if (r.ok()) loaded.add(new URL(r.url()).pathname);
  });
  page.on('request', r => { if (!r.url().startsWith(origin + '/')) external.push(r.url()); });
  await page.goto(origin + '/');
  await page.locator('#choose-local').waitFor({state:'visible', timeout:10000});
  assert.equal(await page.evaluate(() => Mobile.mode), null, 'Fresh context must show first launch');
  await page.locator('#choose-local').click();
  await page.locator('#app').waitFor({state:'visible', timeout:15000});
  await page.waitForFunction(() => Mobile.mode === 'local' && !!Mobile.store && !!Mobile.settings);
  const state = await page.evaluate(() => ({mode:Mobile.mode, store:!!Mobile.store,
    persisted:localStorage.getItem('expiry_mobile_mode_v1'), status:document.getElementById('storage-mode').textContent,
    error:document.getElementById('mode-error').textContent}));
  assert.equal(state.persisted, 'local');
  assert.equal(state.error, '');
  for (const name of ['boot.mjs', 'network.mjs', 'session.mjs', 'storage.mjs', 'app.js'])
    assert.ok(loaded.has('/' + name), 'Startup must load generated ' + name);
  await page.reload();
  await page.locator('#app').waitFor({state:'visible'});
  assert.equal(await page.evaluate(() => Mobile.mode), 'local');
  assert.deepEqual(errors, []);
  assert.deepEqual(failed, []);
  assert.deepEqual(external, []);
  console.log(JSON.stringify({result:'PASS', browser:'Edge', webRoot:root,
    firstLaunch:true, chooseLocal:true, initialized:state, reload:true,
    loaded:[...loaded].sort(), pageErrors:errors, failedRequests:failed, externalRequests:external}, null, 2));
  await context.close();
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
