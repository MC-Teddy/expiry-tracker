// Actual generated/packaged assets at file://; no server or security overrides.
import assert from 'node:assert/strict';
import {chromium, webkit} from 'playwright';
import {realpath} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
const root = await realpath(process.argv[2] || fileURLToPath(new URL('../../ios/Sources/ExpiryTracker/Resources/Web/', import.meta.url)));
assert.notEqual(root, await realpath(fileURLToPath(new URL('../../mobile-web/', import.meta.url))), 'Test generated resources, not canonical sources');
let failures = 0;
for (const [name, engine, options] of [['WebKit', webkit, {}], ['Edge', chromium, {channel:'msedge'}]]) {
  let browser;
  const errors = [], consoleErrors = [], failed = [], external = [], loaded = new Set();
  try {
    browser = await engine.launch({headless:true, ...options});
    const context = await browser.newContext({viewport:{width:390, height:844}});
    const page = await context.newPage();
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
    page.on('requestfailed', r => failed.push(r.url() + ': ' + r.failure()?.errorText));
    page.on('request', r => { if (!r.url().startsWith('file:')) external.push(r.url()); });
    page.on('response', r => { if (r.status() >= 400) failed.push(r.status() + ': ' + r.url()); else loaded.add(new URL(r.url()).pathname.split('/').at(-1)); });
    await page.goto(pathToFileURL(resolve(root, 'index.html')).href);
    await page.locator('#choose-local').waitFor({state:'visible', timeout:10000});
    await page.waitForFunction(() => typeof window.Mobile?.selectMode === 'function', {}, {timeout:5000});
    assert.equal(await page.evaluate(() => Mobile.mode), null, 'Fresh context must show first launch');
    await page.locator('#choose-local').click();
    const initialized = async () => {
      await page.locator('#app').waitFor({state:'visible', timeout:10000});
      await page.waitForFunction(() => Mobile.mode === 'local' && !!Mobile.store && !!Mobile.settings);
      assert.equal(await page.locator('#mode-error').textContent(), '');
      assert.equal(await page.evaluate(() => localStorage.getItem('expiry_mobile_mode_v1')), 'local');
    };
    await initialized();
    await page.evaluate(async () => { await Mobile.store.put('settings', 'file_startup_regression', 'persisted'); await Mobile.flush(); });
    await page.reload();
    await initialized();
    assert.equal(await page.evaluate(() => Mobile.settings.getItem('file_startup_regression')), 'persisted');
    await page.evaluate(async () => { await Mobile.store.remove('settings', 'file_startup_regression'); });
    for (const asset of ['native.js', 'config.js', 'boot.js', 'app.js']) assert.ok(loaded.has(asset), 'Startup must load ' + asset);
    assert.ok(![...loaded].some(n => n.endsWith('.mjs')), 'Startup must not request ES modules at file origin');
    assert.deepEqual(errors, []);
    assert.deepEqual(consoleErrors, []);
    assert.deepEqual(failed, []);
    assert.deepEqual(external, []);
    console.log(JSON.stringify({result:'PASS', browser:name, origin:'file://', webRoot:root, firstLaunch:true, chooseLocal:true, initialized:true, reload:true, indexedDBPersistence:true, loaded:[...loaded].sort(), pageErrors:errors, consoleErrors, failedRequests:failed, externalRequests:external}, null, 2));
  } catch (e) {
    failures++;
    console.error(JSON.stringify({result:'FAIL', browser:name, origin:'file://', webRoot:root, error:e.message, pageErrors:errors, consoleErrors, failedRequests:failed, externalRequests:external}, null, 2));
  } finally { await browser?.close(); }
}
if (failures) process.exitCode = 1;
