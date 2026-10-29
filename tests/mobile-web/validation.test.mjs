import test from 'node:test';
import assert from 'node:assert/strict';
import 'fake-indexeddb/auto';
import {Store,validateBackup} from '../../mobile-web/storage.mjs';
const b={format:'expiry-tracker',version:1,items:[{id:'sample_full',name:'Eggs',expiry:'2026-12-01',icon:'Dairy',added:'2026-10-15T00:00:00Z'}],photos:{sample_full:'data:image/png;base64,YQ=='},settings:{}};
test('validation supports photo IDs ending in _full and rejects non-object containers',()=>{
 assert.deepEqual(validateBackup(b),b);
 for(const patch of [{photos:7},{settings:7},{photos:[]},{settings:[]},{items:[{...b.items[0],id:null}]},{settings:{expiry_cats:'[]'}}])assert.throws(()=>validateBackup({...b,...patch}),/Invalid backup/);
});
test('backup limit measures serialized UTF-8 bytes, accepts 20 MiB, rejects larger without replacing data',async()=>{
 const limit=20*1024*1024;
 const exact={...b,settings:{expiry_device_id:''}};
 exact.settings.expiry_device_id='a'.repeat(limit-Buffer.byteLength(JSON.stringify(exact)));
 assert.equal(Buffer.byteLength(JSON.stringify(exact)),limit);assert.deepEqual(validateBackup(exact),exact);
 const oversized={...exact,settings:{expiry_device_id:exact.settings.expiry_device_id+'a'}};
 assert.throws(()=>validateBackup(oversized),/20 MiB/);
 const unicode={...b,settings:{expiry_device_id:'冷'.repeat(Math.ceil(limit/3))}};
 assert.ok(JSON.stringify(unicode).length<limit);assert.throws(()=>validateBackup(unicode),/20 MiB/);
 const s=await Store.open('local');await s.put('items','retained',{id:'retained'});const before=await s.backup();
 await assert.rejects(s.importBackup(oversized),/20 MiB/);assert.deepEqual(await s.backup(),before);
});
test('aborted import transaction rolls back all three local stores',async()=>{
 const s=await Store.open('local');await s.put('items','old',{id:'old'});await s.put('photos','old','photo');await s.put('settings','expiry_theme','light');const before=await s.backup();
 const transaction=s.transaction.bind(s);s.transaction=(names,work)=>transaction(names,tx=>{work(tx);tx.abort();});
 await assert.rejects(s.importBackup({...b,photos:{}}),/Storage/i);assert.deepEqual(await s.backup(),before);
});
