import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import 'fake-indexeddb/auto';
import {pathToFileURL} from 'node:url';
const url=pathToFileURL(new URL('../../mobile-web/storage.mjs',import.meta.url).pathname.replace(/^\/(\w:)/,'$1'));
test('IndexedDB persists photos and separates local/account scopes',async()=>{
 const {Store}=await import(url); const a=await Store.open('local'), b=await Store.open('cloud:user-a');
 await a.put('items','a',{id:'a',name:'Milk'}); await a.put('photos','a','data:image/png;base64,YQ==');
 assert.equal((await (await Store.open('local')).all('items'))[0].name,'Milk');
 assert.equal(await a.get('photos','a'),'data:image/png;base64,YQ=='); assert.deepEqual(await b.all('items'),[]);
});
test('versioned backups include photos; invalid import leaves data intact; valid import replaces only local atomically',async()=>{
 const {Store,validateBackup}=await import(url); const s=await Store.open('local');
 const backup={format:'expiry-tracker',version:1,items:[{id:'safe',name:'Eggs',expiry:'2026-12-01',icon:'Dairy',added:'2026-10-15T00:00:00.000Z'}],photos:{safe:'data:image/png;base64,YQ=='},settings:{expiry_theme:'dark'}};
 assert.deepEqual(validateBackup(backup),backup);
 await assert.rejects(s.importBackup({...backup,photos:{orphan:'https://evil.test/a'}}),/photo/i);
 assert.equal((await s.all('items'))[0].id,'a');
 await s.importBackup(backup); assert.deepEqual(await s.backup(),backup);
 const b=await Store.open('cloud:user-a'); await assert.rejects(b.importBackup(backup),/local/i);
 for(const bad of [{...backup,version:2},{...backup,items:[{...backup.items[0],id:"x');evil()"}]},{...backup,items:[{...backup.items[0],expiry:'2026-02-30'}]},{...backup,settings:{expiry_products:'not-json'}}]) assert.throws(()=>validateBackup(bad));
});
