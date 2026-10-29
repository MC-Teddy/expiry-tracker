import test from 'node:test';
import assert from 'node:assert/strict';
import {watchAccount} from '../../mobile-web/session.mjs';
test('account identity changes reload instead of reusing photos/settings; token refresh does not',()=>{
 let listener,reloads=0;const client={auth:{onAuthStateChange:fn=>{listener=fn;return {data:{subscription:{unsubscribe(){}}}};}}};watchAccount(client,'user-a',()=>reloads++);
 listener('INITIAL_SESSION',{user:{id:'user-a'}});listener('TOKEN_REFRESHED',{user:{id:'user-a'}});assert.equal(reloads,0);listener('SIGNED_IN',{user:{id:'user-b'}});assert.equal(reloads,1);
});
