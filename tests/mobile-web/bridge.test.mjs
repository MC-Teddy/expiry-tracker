import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
test('Native Promise bridge correlates replies and rejects failures and unavailable host',async()=>{
 const code=readFileSync(new URL('../../mobile-web/native.js',import.meta.url),'utf8');
 const messages=[];const w={webkit:{messageHandlers:{native:{postMessage:m=>messages.push(m)}}}};vm.runInNewContext(code,{window:w,setTimeout,clearTimeout,crypto});
 const p=w.Native.call('ocr',{image:'data:image/png;base64,YQ=='});assert.equal(messages[0].action,'ocr');w.nativeReply(messages[0].id,{text:'EXP 01/12/2026'},null);assert.equal((await p).text,'EXP 01/12/2026');
 const q=w.Native.call('export',{name:'x',data:'YQ=='});w.nativeReply(messages[1].id,null,'Denied');await assert.rejects(q,/Denied/);w.nativeReply('unknown',{},null);
 delete w.webkit;await assert.rejects(w.Native.call('ocr',{}),/iPhone app/);
});
