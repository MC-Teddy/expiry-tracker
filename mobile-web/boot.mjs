import {assertTransferSize} from './transfer.mjs';
import {Store} from './storage.mjs';
import {makeNativeFetch} from './network.mjs';
import {watchAccount} from './session.mjs';
const modeKey='expiry_mobile_mode_v1';
const M=window.Mobile={mode:localStorage.getItem(modeKey),photos:{},pending:new Set(),failed:null,client:null,session:null};
const error=e=>{const text=e?.message||String(e);const el=document.getElementById('mode-error');if(el)el.textContent=text;const n=document.getElementById('notify-bar');if(n){n.textContent=text;n.classList.add('show');}};
window.addEventListener('unhandledrejection',e=>{error(e.reason);e.preventDefault();});
M.write=fn=>{const p=Promise.resolve().then(fn);M.pending.add(p);p.catch(e=>{M.failed=e;error(Error('Storage write failed: '+e.message));}).finally(()=>M.pending.delete(p));return p;};
M.track=fn=>{let p;try{p=Promise.resolve(fn());}catch(e){p=Promise.reject(e);}M.pending.add(p);p.then(()=>M.pending.delete(p),()=>M.pending.delete(p));return p;};
M.flush=async()=>{while(M.pending.size)await Promise.all([...M.pending]);if(M.failed)throw Error('A storage write failed. Switching or export is blocked to avoid an incomplete dataset. Close and reopen the app; unsaved changes may be lost.');};
M.pickMode=()=>{document.getElementById('mode-picker').style.display='flex';};
M.selectMode=async mode=>{try{if(!['local','cloud'].includes(mode))throw Error('Invalid storage mode');await M.flush();localStorage.setItem(modeKey,mode);location.reload();}catch(e){error(e);}};
M.base64=blob=>{assertTransferSize(blob.size);return new Promise((resolve,reject)=>{const r=new FileReader();r.onload=()=>resolve(r.result.split(',')[1]);r.onerror=()=>reject(Error('Unable to encode export'));r.readAsDataURL(blob);});};
M.exportBackup=async()=>{const st=document.getElementById('backup-status');try{st.textContent='Preparing complete backup…';await M.flush();let b=await M.store.backup();if(M.mode==='cloud'){b.items=await window.dbGetAll();b.photos={};for(const i of b.items)for(const full of [false,true]){const p=await window.fetchImage(i.id,full);if(p)b.photos[String(i.id)+(full?'_full':'')]=p;}}const data=await M.base64(new Blob([JSON.stringify(b)],{type:'application/json'}));const r=await Native.call('export',{name:'expiry-tracker-backup-v1.json',data});st.textContent=r?.completed?'Backup exported with photos.':'Export cancelled — no file was saved.';}catch(e){st.textContent='Backup failed: '+e.message;}};
M.importBackup=async input=>{const st=document.getElementById('backup-status');try{if(M.mode!=='local')throw Error('Switch to local mode before importing. Cloud imports are not supported.');const f=input.files?.[0];if(!f)return;assertTransferSize(f.size);const b=JSON.parse(await f.text());const {validateBackup}=await import('./storage.mjs');validateBackup(b);if(!confirm('Replace ALL local items, photos and settings with this backup? Export a backup first. Cloud data is not changed.'))return;await M.flush();await M.store.importBackup(b);location.reload();}catch(e){st.textContent='Import rejected; existing data retained: '+e.message;}finally{input.value='';}};
async function loadScript(src){await new Promise((resolve,reject)=>{const s=document.createElement('script');s.src=src;s.onload=resolve;s.onerror=()=>reject(Error('Bundled resource missing: '+src));document.head.appendChild(s);});}
const nativeFetch=makeNativeFetch(M.mode,(action,payload)=>Native.call(action,payload));
M.start=async()=>{for(const name of ['dbAdd','dbUpdate','dbDelete','uploadImage','removeImage','saveManualItem','saveScannedItem','saveEdit','commitDelete']){const fn=window[name];window[name]=(...args)=>M.track(()=>fn(...args));}window.renderVersion();document.getElementById('storage-mode').textContent=M.mode==='local'?'On this iPhone — no account, no network':'Online — separate account storage';document.getElementById('backup-import').hidden=M.mode!=='local';if(M.mode==='local'){document.getElementById('account-email').textContent='No account needed';document.getElementById('account-role').textContent='Local';for(const id of ['new-password'])document.getElementById(id).closest('.bao-card').hidden=true;}await window.initAuth();};
try{
 if(!['local','cloud'].includes(M.mode)){M.pickMode();}else{
 if(M.mode==='cloud'){
  const cfg=window.EXPIRY_CONFIG;if(!cfg?.publicKey||cfg.publicKey.includes('...'))throw Error('Cloud is not configured: the existing Supabase public anon/publishable key is missing (the website has a placeholder). Choose On this iPhone, or supply the real public key in config.js.');
  if(!cfg.publicKey.startsWith('sb_publishable_')){let claims;try{claims=JSON.parse(atob(cfg.publicKey.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));}catch{throw Error('Cloud configuration: invalid public key');}if(claims.role!=='anon')throw Error('Cloud configuration requires a public anon key; privileged keys are forbidden.');}
  await loadScript('vendor/supabase.js');
  const authStore=await Store.open('cloud:auth'),authCache=Object.fromEntries(await authStore.entries('settings'));
  const authStorage={getItem:k=>authCache[k]??null,setItem:async(k,v)=>{authCache[k]=v;await authStore.put('settings',k,v);},removeItem:async k=>{delete authCache[k];await authStore.remove('settings',k);}};
  M.client=supabase.createClient(cfg.url,cfg.publicKey,{global:{fetch:nativeFetch},auth:{storage:authStorage,storageKey:'expiry-native-auth',detectSessionInUrl:false}});
  const {data,error:authError}=await M.client.auth.getSession();if(authError)throw authError;M.session=data.session;
  watchAccount(M.client,M.session?.user?.id,()=>{document.getElementById('app').style.display='none';location.reload();});
 }
 const scope=M.mode==='local'?'local':'cloud:'+(M.session?.user.id||'signedout');M.store=await Store.open(scope);
 const cache=Object.fromEntries(await M.store.entries('settings'));M.photos=Object.fromEntries(await M.store.entries('photos'));
 M.settings={getItem:k=>cache[k]??null,setItem:(k,v)=>{cache[k]=String(v);M.write(()=>M.store.put('settings',k,String(v)));},removeItem:k=>{delete cache[k];M.write(()=>M.store.remove('settings',k));}};
 document.getElementById('mode-picker').style.display='none';await loadScript('app.js');
 }
}catch(e){M.pickMode();error(e);}
