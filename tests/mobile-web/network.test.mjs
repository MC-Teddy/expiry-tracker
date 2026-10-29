import test from 'node:test';
import assert from 'node:assert/strict';
import {makeNativeFetch} from '../../mobile-web/network.mjs';
const origin='https://viupqrjyszvvcpnxrmsq.supabase.co';
test('local transport denies networking before invoking native host',async()=>{let calls=0;const fetch=makeNativeFetch('local',()=>{calls++;});await assert.rejects(fetch(origin+'/rest/v1/items'),/disabled/);assert.equal(calls,0);});
test('cloud transport allowlists project; round trips bytes and HTTP error status',async()=>{
 const messages=[];const fetch=makeNativeFetch('cloud',async(action,p)=>{messages.push([action,p]);return {status:403,headers:{'content-type':'application/json'},body:btoa('{"message":"forbidden"}')};});
 await assert.rejects(fetch('https://evil.test/'),/permitted/);assert.equal(messages.length,0);
 const r=await fetch(origin+'/rest/v1/items',{method:'POST',headers:{Authorization:'Bearer TEST_FIXTURE_ONLY'},body:new Uint8Array([0,128,255])});assert.equal(r.status,403);assert.equal(await r.text(),'{"message":"forbidden"}');assert.equal(messages[0][0],'request');assert.equal(messages[0][1].body,'AID/');assert.equal(messages[0][1].headers.authorization,'Bearer TEST_FIXTURE_ONLY');
});
test('cloud transport preserves empty response and rejects aborted requests',async()=>{
 let calls=0;const fetch=makeNativeFetch('cloud',async()=>{calls++;return {status:204,headers:{},body:''};});assert.equal((await fetch(origin)).status,204);const c=new AbortController();c.abort();await assert.rejects(fetch(origin,{signal:c.signal}),/abort/i);assert.equal(calls,1);
});
