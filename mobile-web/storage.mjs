import {assertTransferSize} from './transfer.mjs';
export class Store {
 static async open(scope){
  if(!/^(local|cloud:[\w-]+)$/.test(scope)) throw Error('Invalid storage scope');
  const db=await new Promise((resolve,reject)=>{ const r=indexedDB.open('expiry-mobile-v1',1); r.onupgradeneeded=()=>{for(const s of ['items','photos','settings'])r.result.createObjectStore(s);};r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error); });
  return new Store(db,scope);
 }
 async backup(){return new Promise((resolve,reject)=>{const b={format:'expiry-tracker',version:1,items:[],photos:{},settings:{}};const tx=this.db.transaction(['items','photos','settings'],'readonly');for(const name of ['items','photos','settings']){const r=tx.objectStore(name).openCursor();r.onsuccess=()=>{const c=r.result;if(!c)return;if(String(c.key).startsWith(this.scope+'|')){const k=String(c.key).slice(this.scope.length+1);if(name==='items')b.items.push(c.value);else Object.defineProperty(b[name],k,{value:c.value,enumerable:true,writable:true,configurable:true});}c.continue();};}tx.oncomplete=()=>resolve(b);tx.onerror=()=>reject(tx.error||Error('Backup read failed'));tx.onabort=()=>reject(tx.error||Error('Backup read aborted'));});}
 async importBackup(input){
  if(this.scope!=='local')throw Error('Import is available only in local mode');
  const b=validateBackup(input);
  await this.transaction(['items','photos','settings'],tx=>{
   for(const name of ['items','photos','settings']){const os=tx.objectStore(name),r=os.openCursor();r.onsuccess=()=>{const c=r.result;if(c){if(String(c.key).startsWith(this.scope+'|'))c.delete();c.continue();}else{const entries=name==='items'?b.items.map(v=>[v.id,v]):Object.entries(b[name]);for(const [k,v] of entries)os.put(v,this.key(k));}};}
  });
 }
 constructor(db,scope){this.db=db;this.scope=scope;}
 key(id){return this.scope+'|'+id;}
 async transaction(names,work){return new Promise((resolve,reject)=>{const tx=this.db.transaction(names,'readwrite');tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error||Error('Storage write failed'));tx.onabort=()=>reject(tx.error||Error('Storage transaction aborted'));try{work(tx);}catch(e){tx.abort();reject(e);}});}
 async put(name,id,value){await this.transaction([name],tx=>tx.objectStore(name).put(value,this.key(id)));}
 async remove(name,id){await this.transaction([name],tx=>tx.objectStore(name).delete(this.key(id)));}
 async entries(name){return new Promise((resolve,reject)=>{const out=[],tx=this.db.transaction(name),r=tx.objectStore(name).openCursor();r.onsuccess=()=>{const c=r.result;if(c){if(String(c.key).startsWith(this.scope+'|'))out.push([String(c.key).slice(this.scope.length+1),c.value]);c.continue();}};tx.oncomplete=()=>resolve(out);tx.onerror=()=>reject(tx.error);});}
 async all(name){return (await this.entries(name)).map(e=>e[1]);}
 async get(name,id){return new Promise((resolve,reject)=>{const r=this.db.transaction(name).objectStore(name).get(this.key(id));r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});}
}

export function validateBackup(b){
 const fail=m=>{throw Error('Invalid backup: '+m);};
 if(!b||b.format!=='expiry-tracker'||b.version!==1||!Array.isArray(b.items)||!b.photos||typeof b.photos!=='object'||Array.isArray(b.photos)||!b.settings||typeof b.settings!=='object'||Array.isArray(b.settings))fail('format/version');
 assertTransferSize(new Blob([JSON.stringify(b)]).size);
 if(b.items.length>50000)fail('size limit (50000 items)');
 const ids=new Set();
 for(const i of b.items){if(!i||!['string','number'].includes(typeof i.id)||!(/^[a-zA-Z0-9_-]{1,100}$/).test(String(i.id))||ids.has(String(i.id)))fail('item id');ids.add(String(i.id));if(typeof i.name!=='string'||!i.name.trim()||i.name.length>1000||typeof i.expiry!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(i.expiry)||Number.isNaN(Date.parse(i.expiry))||new Date(i.expiry).toISOString().slice(0,10)!==i.expiry)fail('item name/date');if(typeof i.icon!=='string'||i.icon.length>200||typeof i.added!=='string'||!Number.isFinite(Date.parse(i.added)))fail('category/added date');}
 for(const [id,p] of Object.entries(b.photos)){if(!(ids.has(id)||(id.endsWith('_full')&&ids.has(id.slice(0,-5))))||typeof p!=='string'||!/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/]+={0,2}$/.test(p)||p.split(',')[1].length%4)fail('photo');}
 for(const [k,v] of Object.entries(b.settings)){if(!['expiry_theme','expiry_cards','expiry_soon_days','expiry_critical_days','expiry_products','expiry_cats','expiry_device_id'].includes(k)||typeof v!=='string')fail('settings');if(['expiry_products','expiry_cats'].includes(k)){let a;try{a=JSON.parse(v);}catch{fail('settings JSON');}if(!Array.isArray(a)||(k==='expiry_cats'&&!a.length)||a.length>10000||a.some(x=>k==='expiry_products'?typeof x!=='string':!(typeof x==='string'||x&&typeof x.name==='string')))fail('settings list');}if(k.endsWith('_days')&&(!/^\d+$/.test(v)||+v<1||+v>60))fail('threshold');}
 return structuredClone(b);
}
