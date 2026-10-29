import test from 'node:test';
import assert from 'node:assert/strict';
import 'fake-indexeddb/auto';
import {Store} from '../../mobile-web/storage.mjs';
test('backup reads items, photos and settings in one consistent snapshot during writes',async()=>{
 const s=await Store.open('local');await s.put('items','snapshot',{id:'snapshot',generation:1});await s.put('photos','snapshot','generation-1');await s.put('settings','generation','1');
 const reading=s.backup();const writing=s.transaction(['items','photos','settings'],tx=>{tx.objectStore('items').put({id:'snapshot',generation:2},s.key('snapshot'));tx.objectStore('photos').put('generation-2',s.key('snapshot'));tx.objectStore('settings').put('2',s.key('generation'));});
 const b=await reading;await writing;assert.equal(b.photos.snapshot,'generation-'+b.items[0].generation);assert.equal(b.settings.generation,String(b.items[0].generation));
});
