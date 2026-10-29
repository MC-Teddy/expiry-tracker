function startCamera(){
 document.getElementById('video').style.display='none';document.getElementById('scan-overlay').style.display='none';document.getElementById('scan-hint').textContent='Tap Capture to open the iPhone camera. Enter dates manually if needed.';document.getElementById('capture-btn').style.display='flex';document.getElementById('retake-btn').style.display='none';
}
function stopCamera(){}
let nativeCameraBusy=false;
async function capturePhoto(){
 if(nativeCameraBusy)return;nativeCameraBusy=true;capturedThumb=null;resetFullPhoto();document.getElementById('scan-name').value='';document.getElementById('scan-date').value='';dateCands=[];renderDateChoices('');document.getElementById('preview-img').style.display='none';const btn=document.getElementById('capture-btn');btn.disabled=true;
 try{const result=await Native.call('camera',{purpose:'expiry'});if(!/^data:image\/jpeg;base64,/.test(result?.image||''))throw Error('Native camera returned no JPEG image.');
 const img=new Image();await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=()=>reject(Error('Unable to read camera photo'));img.src=result.image;});
 const c=document.getElementById('canvas');c.width=img.width;c.height=img.height;c.getContext('2d').drawImage(img,0,0);capturedThumb=getThumbnail(c);const preview=document.getElementById('preview-img');preview.src=result.image;preview.style.display='block';btn.style.display='none';document.getElementById('retake-btn').style.display='flex';await runOCR(c);
 }catch(e){notify(e.message);document.getElementById('add-form').classList.add('show');document.getElementById('ocr-text').textContent=e.message+' — enter details manually.';}finally{nativeCameraBusy=false;btn.disabled=false;}
}
function retakePhoto(){capturedThumb=null;document.getElementById('add-form').classList.remove('show');document.getElementById('ocr-status').classList.remove('show');capturePhoto();}
async function openBarcodeScanner(targetInputId){
 try{const result=await Native.call('camera',{purpose:'barcode'});if(typeof result?.barcode!=='string'||!result.barcode)throw Error('No barcode returned. Enter the product name manually.');const input=document.getElementById(targetInputId||'manual-name');if(input&&!input.value)input.value=result.barcode;notify('Barcode '+result.barcode+' — enter the product name (online lookup is disabled).');}catch(e){notify(e.message);}
}
/* Mobile adapters: original screen/render logic above stays intact. */
function saveImageLocally(id,data){Mobile.photos[id]=data;return Mobile.write(()=>Mobile.store.put('photos',id,data));}
function getImageLocally(id){return Mobile.photos[id]||null;}
function deleteImageLocally(id){delete Mobile.photos[id];return Mobile.write(()=>Mobile.store.remove('photos',id));}
async function uploadImage(id,data,full){
 await saveImageLocally(imgKey(id,full),data);
 if(Mobile.mode==='local')return;
 const {error}=await sb.storage.from(IMG_BUCKET).upload(imagePath(id,full),dataURLtoBlob(data),{upsert:true,contentType:'image/jpeg'});
 if(error)throw Error('Photo kept on this device; cloud upload failed: '+error.message);
}
async function fetchImage(id,full){
 const key=imgKey(id,full);if(Mobile.photos[key])return Mobile.photos[key];if(Mobile.mode==='local')return null;
 const {data,error}=await sb.storage.from(IMG_BUCKET).download(imagePath(id,full));
 if(error){if(String(error.statusCode)==='404')return null;throw Error('Cloud photo download failed: '+error.message);}
 if(!data)return null;const url=await blobToDataURL(data);await saveImageLocally(key,url);return url;
}
async function removeImage(id){
 if(Mobile.mode==='cloud'){const {error}=await sb.storage.from(IMG_BUCKET).remove([imagePath(id,false),imagePath(id,true)]);if(error)throw error;}
 await deleteImageLocally(String(id));await deleteImageLocally(id+'_full');
}
async function clearLocalImages(){
 if(Mobile.mode==='local'){notify('Local photos are originals, not a cache. Delete an item to remove its photos.');return;}
 for(const id of Object.keys(Mobile.photos))await deleteImageLocally(id);notify('Cloud photo cache cleared for this account');
}
async function dbGetAll(){
 if(Mobile.mode==='local')return (await Mobile.store.all('items')).sort((a,b)=>a.expiry.localeCompare(b.expiry));
 if(!CURRENT_USER)throw Error('Sign in to your cloud account first.');
 const {data,error}=await sb.from('items').select('*').eq('user_id',CURRENT_USER.id).order('expiry',{ascending:true});if(error)throw Error('Cloud read failed: '+error.message);setSyncing(false);return data||[];
}
async function dbAdd(item){
 try{if(Mobile.mode==='local'){const data={...item,id:crypto.randomUUID()};await Mobile.store.put('items',data.id,data);return data;}
 const {data,error}=await sb.from('items').insert([{...item,user_id:CURRENT_USER.id,device_id:DEVICE_ID}]).select().single();if(error)throw error;return data;
 }catch(e){notify('Item was not saved: '+e.message);return null;}
}
async function dbUpdate(id,fields){
 try{if(Mobile.mode==='local'){const old=await Mobile.store.get('items',id);if(!old)throw Error('Item not found');const data={...old,...fields};await Mobile.store.put('items',id,data);return data;}
 const {data,error}=await sb.from('items').update(fields).eq('id',id).eq('user_id',CURRENT_USER.id).select().single();if(error)throw error;return data;
 }catch(e){notify('Changes were not saved: '+e.message);return null;}
}
async function dbDelete(id){
 if(Mobile.mode==='local'){await Mobile.store.remove('items',id);return;}
 const {error}=await sb.from('items').delete().eq('id',id).eq('user_id',CURRENT_USER.id);if(error)throw Error('Delete failed: '+error.message);
}
function setSyncing(on){const el=document.getElementById('sync-label');el.textContent=Mobile.mode==='local'?'On this iPhone · offline storage':on?'Syncing…':'Cloud account · refreshed';}
async function clearAllItems(){
 const items=await dbGetAll();confirmDialog('Permanently delete all items and photos in this storage mode?',async()=>{for(const i of items){await removeImage(i.id);await dbDelete(i.id);}await refresh();notify('Items deleted');},{title:'Clear products',confirmText:'Delete all'});
}
async function initAuth(){if(Mobile.mode==='local'){document.getElementById('app').style.display='flex';setSyncing(false);await refresh();return;}applySession(Mobile.session);}
function applySession(session){
 const user=session?.user;if((user?.id||null)!==(Mobile.session?.user?.id||null)){location.reload();return;}
 CURRENT_USER=user||null;document.getElementById('login-page').style.display=user?'none':'flex';document.getElementById('app').style.display=user?'flex':'none';if(user)refresh();
}
async function doLogin(){
 const el=document.getElementById('login-error'),btn=document.getElementById('login-btn');btn.disabled=true;el.textContent='';
 try{const {error}=await sb.auth.signInWithPassword({email:document.getElementById('login-email').value.trim(),password:document.getElementById('login-pass').value});if(error)throw error;location.reload();}catch(e){el.textContent='Sign-in failed: '+e.message;}finally{btn.disabled=false;}
}
async function doLogout(){const {error}=await sb.auth.signOut();if(error)throw error;location.reload();}
function buildCsv(rows){
 // Quote every cell (commas, quotes and embedded newlines); neutralize spreadsheet formulas.
 const cell=value=>{let text=String(value??'');if(typeof value==='string'&&/^[\s\u0000-\u001f]*[=+@-]|^[\t\r\n]/.test(text))text="'"+text;return '"'+text.replaceAll('"','""')+'"';};
 return new Blob(['\ufeff'+rows.map(row=>row.map(cell).join(',')).join('\r\n')+'\r\n'],{type:'text/csv;charset=utf-8'});
}
async function downloadBlob(blob,name){const data=await Mobile.base64(blob);const r=await Native.call('export',{name,data});if(!r?.completed)throw Error('Export cancelled — no file was saved.');}
